extends RefCounted
## 本地玩家設置：單一 ConfigFile，保存顯示模式與四項音量。
## 所有路徑可切到測試檔，避免污染真正的 user://settings.cfg。

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "display"
const KEY := "mode"
const MODES := ["windowed", "fullscreen"]

const AUDIO_SECTION := "audio"
const VOLUME_KEYS := ["master", "bgm", "sfx", "voice"]
const VOLUME_DEFAULTS := {
	"master": 0.8,
	"bgm": 0.7,
	"sfx": 0.8,
	"voice": 0.9,
}

static var _path: String = DEFAULT_PATH

static func set_path_for_test(path: String) -> void:
	_path = path

static func reset_path() -> void:
	_path = DEFAULT_PATH

static func current_path() -> String:
	return _path

static func clear() -> void:
	for path in [_path, _path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## 讀入現有設定；檔案不存在或損壞時回傳空 ConfigFile，由呼叫端補預設。
static func _config() -> ConfigFile:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		return ConfigFile.new()
	return cfg

static func save_display_mode(mode: String) -> bool:
	if mode not in MODES:
		return false
	var cfg := _config()
	cfg.set_value(SECTION, KEY, mode)
	cfg.set_value(SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

static func load_display_mode() -> String:
	var cfg := _config()
	var mode: String = String(cfg.get_value(SECTION, KEY, "windowed"))
	if mode not in MODES:
		return "windowed"
	return mode

static func current_display_mode() -> String:
	return "fullscreen" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "windowed"

static func apply_display_mode(mode: String = "") -> String:
	var target: String = mode if mode in MODES else load_display_mode()
	var window_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if target == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(window_mode)
	return target

# --- 音量（0–1，非法值一律回預設） ---

static func default_volume(kind: String) -> float:
	return float(VOLUME_DEFAULTS.get(kind, 0.8))

static func save_volume(kind: String, value: float) -> bool:
	if kind not in VOLUME_KEYS:
		return false
	var cfg := _config()
	cfg.set_value(AUDIO_SECTION, kind, clampf(value, 0.0, 1.0))
	cfg.set_value(AUDIO_SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

static func save_volumes(values: Dictionary) -> bool:
	var cfg := _config()
	var touched: bool = false
	for kind in VOLUME_KEYS:
		if not values.has(kind):
			continue
		var raw = values[kind]
		if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			continue
		cfg.set_value(AUDIO_SECTION, kind, clampf(float(raw), 0.0, 1.0))
		touched = true
	if not touched:
		return false
	cfg.set_value(AUDIO_SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

static func load_volume(kind: String) -> float:
	if kind not in VOLUME_KEYS:
		return default_volume(kind)
	return _read_volume(_config(), kind)

static func load_volumes() -> Dictionary:
	var cfg := _config()
	var out: Dictionary = {}
	for kind in VOLUME_KEYS:
		out[kind] = _read_volume(cfg, kind)
	return out

static func _read_volume(cfg: ConfigFile, kind: String) -> float:
	var fallback: float = default_volume(kind)
	var raw = cfg.get_value(AUDIO_SECTION, kind, fallback)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return fallback
	var value: float = float(raw)
	if is_nan(value) or is_inf(value) or value < 0.0 or value > 1.0:
		return fallback
	return value
