extends Node
## S12／AUD-02 音頻管理（autoload）：Master／BGM／SFX／Voice 四總線、SFX 池、
## BGM 交叉淡入淡出、對話 ducking −6dB。
##
## 外包音檔尚未交付：`res://assets/audio/` 不存在時所有播放請求都安全回傳 false，
## 不建立錯誤、不中斷遊戲；調用點可以先寫，素材到位後只補檔案即可。
## 未經匯入的 wav 會以 `AudioStreamWAV.load_from_file()` 執行時回退讀取。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")

const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const BUS_VOICE := "Voice"
const BUSES := [BUS_BGM, BUS_SFX, BUS_VOICE]

const AUDIO_ROOT := "res://assets/audio/"
const SFX_DIR := AUDIO_ROOT + "sfx/"
const BGM_DIR := AUDIO_ROOT + "bgm/"
const VOICE_DIR := AUDIO_ROOT + "voice/"
const EXTENSIONS := [".wav", ".ogg", ".mp3"]

const SFX_POOL_SIZE := 8
const SILENT_DB := -80.0
const DEFAULT_DUCK_DB := -6.0

var _volumes: Dictionary = SETTINGS.VOLUME_DEFAULTS.duplicate()
var _duck_db: float = 0.0
var _bus_ready: bool = false

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_gain: PackedFloat32Array = PackedFloat32Array()
var _bgm_target: PackedFloat32Array = PackedFloat32Array()
var _bgm_speed: PackedFloat32Array = PackedFloat32Array()
var _bgm_index: int = 0
var _bgm_name: String = ""
var _bgm_playing: bool = false
var _voice_player: AudioStreamPlayer

var _registry: Dictionary = {}      # "kind:name" -> AudioStream（測試／佔位注入）
var _streams: Dictionary = {}       # path -> AudioStream 或 null（缺檔只查一次）
var _missing: Dictionary = {}       # "kind:name" -> true

func _ready() -> void:
	_ensure_buses()
	_volumes = SETTINGS.load_volumes()
	_build_players()
	_apply_bus_volumes()

func _process(delta: float) -> void:
	advance_fades(delta)

# --- 總線與音量 ---

## Master／BGM／SFX／Voice 不存在時才建立，全部送到 Master。
func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_MASTER) < 0:
		AudioServer.set_bus_name(0, BUS_MASTER)
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	_bus_ready = true

func has_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0

func bus_volume_db(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(idx) if idx >= 0 else SILENT_DB

## 音量以 0–1 線性值保存；寫入總線時轉 dB，0 直接靜音。
func set_volume(kind: String, value: float) -> bool:
	if kind not in SETTINGS.VOLUME_KEYS:
		return false
	_volumes[kind] = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	SETTINGS.save_volume(kind, float(_volumes[kind]))
	return true

func get_volume(kind: String) -> float:
	if kind not in SETTINGS.VOLUME_KEYS:
		return 0.0
	return float(_volumes.get(kind, SETTINGS.VOLUME_DEFAULTS.get(kind, 0.8)))

func load_volumes() -> void:
	_volumes = SETTINGS.load_volumes()
	_apply_bus_volumes()

func _apply_bus_volumes() -> void:
	_apply_bus(BUS_MASTER, get_volume("master"))
	_apply_bus(BUS_BGM, get_volume("bgm"), _duck_db)
	_apply_bus(BUS_SFX, get_volume("sfx"))
	_apply_bus(BUS_VOICE, get_volume("voice"))

func _apply_bus(bus_name: String, linear: float, offset_db: float = 0.0) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v: float = clampf(linear, 0.0, 1.0)
	if v <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, SILENT_DB)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(v) + offset_db)

## 對話開始時把 BGM 壓低 −6dB，結束還原；不影響 SFX／Voice。
func duck_for_dialogue(on: bool, db: float = DEFAULT_DUCK_DB) -> void:
	_duck_db = db if on else 0.0
	_apply_bus_volumes()

func is_ducked() -> bool:
	return not is_zero_approx(_duck_db)

# --- 播放器 ---

func _build_players() -> void:
	if _sfx_players.is_empty():
		for i in range(SFX_POOL_SIZE):
			var sfx := AudioStreamPlayer.new()
			sfx.name = "Sfx%d" % i
			sfx.bus = BUS_SFX
			add_child(sfx)
			_sfx_players.append(sfx)
	if _bgm_players.is_empty():
		for i in range(2):
			var bgm := AudioStreamPlayer.new()
			bgm.name = "Bgm%d" % i
			bgm.bus = BUS_BGM
			add_child(bgm)
			_bgm_players.append(bgm)
		_bgm_gain.resize(_bgm_players.size())
		_bgm_target.resize(_bgm_players.size())
		_bgm_speed.resize(_bgm_players.size())
	if _voice_player == null:
		_voice_player = AudioStreamPlayer.new()
		_voice_player.name = "Voice"
		_voice_player.bus = BUS_VOICE
		add_child(_voice_player)

# --- 素材查找 ---

## 測試或臨時佔位音可先注入串流，優先於檔案查找。
func register_stream(kind: String, stream_name: String, stream: AudioStream) -> void:
	_registry[kind + ":" + stream_name] = stream

func has_stream(kind: String, stream_name: String) -> bool:
	return _resolve(kind, stream_name) != null

func _dir_for(kind: String) -> String:
	match kind:
		"bgm":
			return BGM_DIR
		"voice":
			return VOICE_DIR
		_:
			return SFX_DIR

func _resolve(kind: String, stream_name: String) -> AudioStream:
	if stream_name == "":
		return null
	var key: String = kind + ":" + stream_name
	if _registry.has(key):
		return _registry[key] as AudioStream
	if _missing.has(key):
		return null
	var dir: String = _dir_for(kind)
	var path: String = ""
	for ext in EXTENSIONS:
		var candidate: String = dir + stream_name + ext
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			path = candidate
			break
	if path == "":
		_missing[key] = true
		return null
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		_missing[key] = true
	return stream

func _load_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and path.get_extension().to_lower() == "wav":
		# 尚未匯入的 wav：執行時直接讀檔，免等編輯器重建 .import
		if FileAccess.file_exists(path):
			stream = AudioStreamWAV.load_from_file(path)
	_streams[path] = stream
	return stream

# --- SFX ---

func play_sfx(stream_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var stream: AudioStream = _resolve("sfx", stream_name)
	if stream == null:
		return false
	var player: AudioStreamPlayer = _pick_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.05, pitch)
	player.play()
	return true

func _pick_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	return player

func active_sfx_count() -> int:
	var n: int = 0
	for player in _sfx_players:
		if player.playing:
			n += 1
	return n

func sfx_pool_size() -> int:
	return _sfx_players.size()

func stop_sfx() -> void:
	for player in _sfx_players:
		player.stop()

# --- BGM ---

## 切換 BGM；同名且正在播時不重啟。fade <= 0 立即切換。
func play_bgm(track: String, fade: float = 0.8) -> bool:
	if track == "":
		stop_bgm(fade)
		return false
	var stream: AudioStream = _resolve("bgm", track)
	if stream == null:
		return false
	if track == _bgm_name and _bgm_playing and _bgm_players[_bgm_index].playing:
		return true
	_prepare_loop(stream)
	if fade <= 0.0:
		for i in range(_bgm_players.size()):
			_bgm_players[i].stop()
			_bgm_gain[i] = 0.0
			_bgm_target[i] = 0.0
		_bgm_index = (_bgm_index + 1) % _bgm_players.size()
		_bgm_gain[_bgm_index] = 1.0
		_bgm_target[_bgm_index] = 1.0
		_bgm_players[_bgm_index].stream = stream
		_apply_bgm_gain(_bgm_index)
		_bgm_players[_bgm_index].play()
	else:
		var old_index: int = _bgm_index
		_bgm_target[old_index] = 0.0
		_bgm_speed[old_index] = 1.0 / fade
		var next: int = (old_index + 1) % _bgm_players.size()
		_bgm_players[next].stream = stream
		_bgm_gain[next] = 0.0
		_bgm_target[next] = 1.0
		_bgm_speed[next] = 1.0 / fade
		_apply_bgm_gain(next)
		_bgm_players[next].play()
		_bgm_index = next
	_bgm_name = track
	_bgm_playing = true
	return true

func stop_bgm(fade: float = 0.6) -> void:
	_bgm_name = ""
	_bgm_playing = false
	for i in range(_bgm_players.size()):
		if fade <= 0.0:
			_bgm_players[i].stop()
			_bgm_gain[i] = 0.0
			_bgm_target[i] = 0.0
			_apply_bgm_gain(i)
		else:
			_bgm_target[i] = 0.0
			_bgm_speed[i] = 1.0 / fade

func current_bgm() -> String:
	return _bgm_name

func is_bgm_playing() -> bool:
	for player in _bgm_players:
		if player.playing:
			return true
	return false

func bgm_gain(index: int) -> float:
	return float(_bgm_gain[index]) if index >= 0 and index < _bgm_gain.size() else 0.0

func bgm_player_count() -> int:
	return _bgm_players.size()

## 手動推進淡入淡出；`_process` 與自測共用，避免依賴真實幀率。
func advance_fades(delta: float) -> void:
	for i in range(_bgm_players.size()):
		var gain: float = float(_bgm_gain[i])
		var target: float = float(_bgm_target[i])
		if is_equal_approx(gain, target):
			continue
		gain = move_toward(gain, target, float(_bgm_speed[i]) * delta)
		_bgm_gain[i] = gain
		_apply_bgm_gain(i)
		if gain <= 0.0 and target <= 0.0:
			_bgm_players[i].stop()

func _apply_bgm_gain(index: int) -> void:
	var gain: float = clampf(float(_bgm_gain[index]), 0.0, 1.0)
	_bgm_players[index].volume_db = linear_to_db(gain) if gain > 0.001 else SILENT_DB

func _prepare_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var frames: int = int(wav.get_length() * float(wav.mix_rate))
			wav.loop_end = frames if frames > 0 else 0

# --- Voice ---

func play_voice(stream_name: String, volume_db: float = 0.0) -> bool:
	var stream: AudioStream = _resolve("voice", stream_name)
	if stream == null or _voice_player == null:
		return false
	_voice_player.stream = stream
	_voice_player.volume_db = volume_db
	_voice_player.play()
	return true

func stop_voice() -> void:
	if _voice_player != null:
		_voice_player.stop()

func is_voice_playing() -> bool:
	return _voice_player != null and _voice_player.playing
