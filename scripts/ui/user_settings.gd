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

# --- 手柄死區（只作用在移動類比軸，按鍵動作維持 0.5 不變） ---

const INPUT_SECTION := "input"
const DEADZONE_KEY := "movement_deadzone"
const DEFAULT_DEADZONE := 0.30
const MOVEMENT_ACTIONS := [
	"p1_left", "p1_right", "p1_up", "p1_down",
	"p2_left", "p2_right", "p2_up", "p2_down",
]

# --- 首次啟動引導標記 ---

const META_SECTION := "meta"
const ONBOARD_KEY := "onboarded"

# --- 鏡頭效果（震屏／微推，OPT-01）：預設開 ---

const CAMERA_FX_KEY := "camera_fx"

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

# --- 手柄死區 ---

static func default_deadzone() -> float:
	return DEFAULT_DEADZONE

static func save_deadzone(value: float) -> bool:
	var cfg := _config()
	cfg.set_value(INPUT_SECTION, DEADZONE_KEY, clampf(value, 0.0, 1.0))
	cfg.set_value(INPUT_SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

## 讀死區；缺值、非數值、NaN／越界一律回預設 0.30，避免壞檔把搖桿鎖死。
static func load_deadzone() -> float:
	var cfg := _config()
	var raw = cfg.get_value(INPUT_SECTION, DEADZONE_KEY, DEFAULT_DEADZONE)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return DEFAULT_DEADZONE
	var value: float = float(raw)
	if is_nan(value) or is_inf(value) or value < 0.0 or value > 1.0:
		return DEFAULT_DEADZONE
	return value

## 把死區寫進 InputMap：只動移動動作，按鍵動作（輕／重／擋…）維持工程預設。
static func apply_deadzone(value: float = -1.0) -> float:
	var target: float = value if value >= 0.0 else load_deadzone()
	target = clampf(target, 0.0, 1.0)
	for action in MOVEMENT_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, target)
	return target

# --- 鏡頭效果（震屏／微推）：預設開；缺值、非布林一律回預設 ---

static func default_camera_fx() -> bool:
	return true

static func save_camera_fx(enabled: bool) -> bool:
	var cfg := _config()
	cfg.set_value(SECTION, CAMERA_FX_KEY, bool(enabled))
	cfg.set_value(SECTION, "updated_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK

static func load_camera_fx() -> bool:
	var cfg := _config()
	var raw = cfg.get_value(SECTION, CAMERA_FX_KEY, true)
	if typeof(raw) != TYPE_BOOL:
		return default_camera_fx()
	return bool(raw)

# --- 首次啟動引導 ---

static func has_onboarded() -> bool:
	var cfg := _config()
	return bool(cfg.get_value(META_SECTION, ONBOARD_KEY, false))

static func is_first_run() -> bool:
	return not has_onboarded()

static func mark_onboarded() -> bool:
	var cfg := _config()
	cfg.set_value(META_SECTION, ONBOARD_KEY, true)
	cfg.set_value(META_SECTION, "onboarded_at", Time.get_unix_time_from_system())
	return cfg.save(_path) == OK
