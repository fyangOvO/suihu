extends RefCounted
## 本地玩家設置：單一 ConfigFile，目前只保存顯示模式。
## 所有路徑可切到測試檔，避免污染真正的 user://settings.cfg。

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "display"
const KEY := "mode"
const MODES := ["windowed", "fullscreen"]

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

static func save_display_mode(mode: String) -> bool:
	if mode not in MODES:
		return false
	var cfg := ConfigFile.new()
	var err: int = cfg.load(_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		cfg = ConfigFile.new()
	cfg.set_value(SECTION, KEY, mode)
	cfg.set_value(SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

static func load_display_mode() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return "windowed"
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
