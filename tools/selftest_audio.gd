extends SceneTree
## S12／AUD-02 音頻自測：四總線、音量存檔與非法值回退、SFX 池、BGM 交叉淡入、
## 對話 ducking、Voice、缺素材容錯，以及 GameAudio 無管理器時的 no-op。
## 用法：godot --headless --path <game> --script res://tools/selftest_audio.gd

const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const AUDIO := preload("res://scripts/audio/game_audio.gd")
const MANAGER := preload("res://scripts/audio/audio_manager.gd")
const TEST_CFG := "user://selftest_audio.cfg"

var fails: Array = []
var manager: Node
var frame: int = 0
var stage: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.clear()
	manager = root.get_node_or_null("AudioManager")
	if manager == null:
		manager = MANAGER.new()
		manager.name = "AudioManager"
		root.add_child(manager)

func _finish() -> void:
	if manager != null and is_instance_valid(manager):
		manager.stop_sfx()
		manager.stop_bgm(0.0)
		manager.stop_voice()
		manager.queue_free()
	SETTINGS.clear()
	SETTINGS.reset_path()
	print("AUDIO_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", frame)
	quit(0 if fails.is_empty() else 1)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if stage > 0:
		return false
	stage = 1
	_run()
	_finish()
	return true

func _run() -> void:
	_check_buses()
	_check_defaults()
	_check_volume_api()
	_check_invalid_settings()
	_check_sfx_pool()
	_check_bgm()
	_check_ducking()
	_check_voice()
	_check_game_audio()

func _check_buses() -> void:
	for bus_name in ["Master", "BGM", "SFX", "Voice"]:
		_check("bus %s exists" % bus_name, manager.has_bus(bus_name))
	var bgm_index: int = AudioServer.get_bus_index("BGM")
	_check("BGM sends to Master", bgm_index >= 0 and AudioServer.get_bus_send(bgm_index) == "Master")
	_check("SFX sends to Master", AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == "Master")
	_check("Voice sends to Master", AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "Master")

func _check_defaults() -> void:
	var volumes: Dictionary = SETTINGS.load_volumes()
	_check("default master 0.8", is_equal_approx(float(volumes["master"]), 0.8))
	_check("default bgm 0.7", is_equal_approx(float(volumes["bgm"]), 0.7))
	_check("default sfx 0.8", is_equal_approx(float(volumes["sfx"]), 0.8))
	_check("default voice 0.9", is_equal_approx(float(volumes["voice"]), 0.9))
	_check("manager loads defaults", is_equal_approx(manager.get_volume("voice"), 0.9))
	_check("master bus not muted", not AudioServer.is_bus_mute(0))

func _check_volume_api() -> void:
	_check("clamp high to 1", manager.set_volume("master", 2.0)
		and is_equal_approx(manager.get_volume("master"), 1.0))
	_check("clamp low to 0", manager.set_volume("master", -1.0)
		and is_equal_approx(manager.get_volume("master"), 0.0))
	_check("zero volume mutes master", AudioServer.is_bus_mute(0))
	_check("unknown volume key rejected", not manager.set_volume("bogus", 0.5))
	manager.set_volume("master", 0.8)
	_check("master restored", not AudioServer.is_bus_mute(0)
		and is_equal_approx(manager.get_volume("master"), 0.8))
	_check("volume persisted", is_equal_approx(SETTINGS.load_volume("master"), 0.8))
	_check("audio section keeps display", SETTINGS.save_display_mode("fullscreen")
		and SETTINGS.load_display_mode() == "fullscreen"
		and is_equal_approx(SETTINGS.load_volume("master"), 0.8))
	SETTINGS.save_display_mode("windowed")

func _check_invalid_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(TEST_CFG)
	cfg.set_value("audio", "bgm", 5.0)
	cfg.set_value("audio", "voice", "loud")
	cfg.save(TEST_CFG)
	var loaded: Dictionary = SETTINGS.load_volumes()
	_check("out-of-range bgm falls back", is_equal_approx(float(loaded["bgm"]), 0.7))
	_check("non-numeric voice falls back", is_equal_approx(float(loaded["voice"]), 0.9))
	_check("valid keys survive bad neighbours", is_equal_approx(float(loaded["master"]), 0.8))

func _check_sfx_pool() -> void:
	_check("sfx pool size 8", manager.sfx_pool_size() == 8)
	_check("missing sfx returns false", not manager.play_sfx("sfx_does_not_exist"))
	_check("missing sfx stays silent", manager.active_sfx_count() == 0)
	manager.register_stream("sfx", "sfx_test_hit", _make_wav(0.4))
	_check("injected sfx plays", manager.play_sfx("sfx_test_hit", -6.0, 1.25))
	var playing: Array = _playing_sfx()
	_check("sfx uses SFX bus", playing.size() == 1 and (playing[0] as AudioStreamPlayer).bus == "SFX")
	if playing.size() == 1:
		var player := playing[0] as AudioStreamPlayer
		_check("sfx volume applied", is_equal_approx(player.volume_db, -6.0))
		_check("sfx pitch applied", is_equal_approx(player.pitch_scale, 1.25))
	for i in range(12):
		manager.play_sfx("sfx_test_hit")
	_check("sfx pool does not grow", _count_named("Sfx") == 8)
	_check("sfx concurrent capped at pool", manager.active_sfx_count() <= 8)
	manager.stop_sfx()
	_check("stop_sfx silences pool", manager.active_sfx_count() == 0)

func _check_bgm() -> void:
	manager.register_stream("bgm", "bgm_test_a", _make_wav(0.5))
	manager.register_stream("bgm", "bgm_test_b", _make_wav(0.5))
	_check("missing bgm returns false", not manager.play_bgm("bgm_missing", 0.0))
	_check("bgm a plays", manager.play_bgm("bgm_test_a", 0.0))
	_check("current bgm a", manager.current_bgm() == "bgm_test_a" and manager.is_bgm_playing())
	var live := _playing_bgm()
	_check("bgm on BGM bus", live != null and live.bus == "BGM")
	_check("same bgm does not restart", manager.play_bgm("bgm_test_a", 0.0))
	_check("bgm switch accepted", manager.play_bgm("bgm_test_b", 0.5))
	_check("bgm name updates at once", manager.current_bgm() == "bgm_test_b")
	manager.advance_fades(0.6)
	var gains: Array = []
	for i in range(manager.bgm_player_count()):
		gains.append(manager.bgm_gain(i))
	_check("bgm fade reaches full", gains.has(1.0) or float(gains.max()) > 0.99)
	_check("bgm old track faded out", float(gains.min()) < 0.01)
	_check("bgm still playing after switch", manager.is_bgm_playing())
	manager.stop_bgm(0.0)
	_check("stop_bgm clears track", manager.current_bgm() == "" and not manager.is_bgm_playing())

func _check_ducking() -> void:
	manager.set_volume("bgm", 0.7)
	var base_db: float = manager.bus_volume_db("BGM")
	manager.duck_for_dialogue(true)
	_check("duck flag set", manager.is_ducked())
	_check("duck lowers bgm 6db", is_equal_approx(manager.bus_volume_db("BGM"), base_db - 6.0))
	_check("duck leaves sfx bus", is_equal_approx(manager.bus_volume_db("SFX"), linear_to_db(0.8)))
	manager.duck_for_dialogue(false)
	_check("unduck restores bgm", not manager.is_ducked()
		and is_equal_approx(manager.bus_volume_db("BGM"), base_db))

func _check_voice() -> void:
	manager.register_stream("voice", "voice_test", _make_wav(0.5))
	_check("voice plays", manager.play_voice("voice_test") and manager.is_voice_playing())
	var voice := manager.get_node_or_null("Voice") as AudioStreamPlayer
	_check("voice on Voice bus", voice != null and voice.bus == "Voice")
	manager.stop_voice()
	_check("voice stops", not manager.is_voice_playing())

func _check_game_audio() -> void:
	_check("GameAudio sees manager", AUDIO.has_manager())
	_check("GameAudio set volume", AUDIO.set_volume("sfx", 0.45)
		and is_equal_approx(AUDIO.get_volume("sfx"), 0.45))
	_check("GameAudio plays sfx", AUDIO.play_sfx("sfx_test_hit"))
	_check("GameAudio stops bgm", not AUDIO.play_bgm("bgm_missing", 0.0))
	AUDIO.duck_dialogue(true)
	_check("GameAudio duck reaches manager", manager.is_ducked())
	AUDIO.duck_dialogue(false)
	root.remove_child(manager)
	_check("GameAudio no-op without manager", not AUDIO.play_sfx("sfx_test_hit")
		and not AUDIO.play_bgm("bgm_test_a") and not AUDIO.has_manager())
	AUDIO.duck_dialogue(true)
	AUDIO.stop_bgm(0.0)
	_check("GameAudio falls back to settings", AUDIO.set_volume("voice", 0.33)
		and is_equal_approx(SETTINGS.load_volume("voice"), 0.33))

func _playing_sfx() -> Array:
	var out: Array = []
	for child in manager.get_children():
		if child is AudioStreamPlayer and child.bus == "SFX" and (child as AudioStreamPlayer).playing:
			out.append(child)
	return out

func _count_named(prefix: String) -> int:
	var n: int = 0
	for child in manager.get_children():
		if String(child.name).begins_with(prefix):
			n += 1
	return n

func _bgm_players() -> Array:
	var out: Array = []
	for child in manager.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).bus == "BGM":
			out.append(child)
	return out

func _playing_bgm() -> AudioStreamPlayer:
	for child in _bgm_players():
		var player := child as AudioStreamPlayer
		if player.stream != null and player.playing:
			return player
	return null

func _make_wav(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	var rate: int = 8000
	var samples: int = int(rate * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
