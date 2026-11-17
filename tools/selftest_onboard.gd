extends SceneTree
## TUT-02 首次啟動引導自測：死區存檔／套用到 InputMap、首啟頁三項設置、
## 確認後記憶不再重彈、壞設定回預設、二次啟動直接進主菜單。
## 用法：godot --headless --path <game> --script res://tools/selftest_onboard.gd

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const AUDIO := preload("res://scripts/audio/game_audio.gd")
const TEST_CFG := "user://selftest_onboard_settings.cfg"

var fails: Array = []
var checks: int = 0
var menu: Node
var stage: int = 0
var frame: int = 0

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.clear()
	_check_deadzone_logic()
	_check_first_run_flag()
	menu = _spawn_menu()

func _process(_delta: float) -> bool:
	frame += 1
	match stage:
		0:
			if frame >= 4:
				_check_first_launch_menu()
				_check_confirm()
				_free_menu()
				menu = _spawn_menu()
				stage = 1
				frame = 0
		1:
			if frame >= 4:
				_check_second_launch()
				_free_menu()
				_write_corrupt_settings()
				menu = _spawn_menu()
				stage = 2
				frame = 0
		2:
			if frame >= 4:
				_check_corrupt_settings()
				_finish()
				return true
	return false

# --- 死區：預設、保存、夹取、套用 InputMap、壞值回退 ---

func _check_deadzone_logic() -> void:
	_check("default deadzone 0.30", is_equal_approx(SETTINGS.load_deadzone(), 0.30))
	_check("save deadzone 0.50", SETTINGS.save_deadzone(0.5)
		and is_equal_approx(SETTINGS.load_deadzone(), 0.5))
	SETTINGS.save_deadzone(1.4)
	_check("deadzone clamps high to 1.0", is_equal_approx(SETTINGS.load_deadzone(), 1.0))
	SETTINGS.save_deadzone(-0.3)
	_check("deadzone clamps low to 0.0", is_equal_approx(SETTINGS.load_deadzone(), 0.0))
	_check("apply deadzone 0.55", is_equal_approx(SETTINGS.apply_deadzone(0.55), 0.55))
	_check("inputmap p1_left deadzone 0.55", is_equal_approx(InputMap.action_get_deadzone("p1_left"), 0.55))
	_check("inputmap p2_right deadzone 0.55", is_equal_approx(InputMap.action_get_deadzone("p2_right"), 0.55))
	_check("button action deadzone untouched", is_equal_approx(InputMap.action_get_deadzone("p1_light"), 0.5))
	var cfg := ConfigFile.new()
	cfg.set_value("input", "movement_deadzone", "abc")
	cfg.save(TEST_CFG)
	_check("bad text deadzone falls back", is_equal_approx(SETTINGS.load_deadzone(), 0.30))
	cfg.set_value("input", "movement_deadzone", 1.7)
	cfg.save(TEST_CFG)
	_check("out of range deadzone falls back", is_equal_approx(SETTINGS.load_deadzone(), 0.30))

# --- 首啟標記：預設未引導、寫入後為已引導 ---

func _check_first_run_flag() -> void:
	SETTINGS.clear()
	_check("fresh is first run", SETTINGS.is_first_run() and not SETTINGS.has_onboarded())
	_check("mark onboarded writes flag", SETTINGS.mark_onboarded() and SETTINGS.has_onboarded())
	_check("onboarded is not first run", not SETTINGS.is_first_run())
	SETTINGS.clear()

# --- 首次啟動：引導頁擋在主菜單前，三項顯示存檔預設 ---

func _check_first_launch_menu() -> void:
	menu = _spawn_menu()
	_check("first launch opens onboarding", menu.call("is_onboarding"))
	_check("onboarding panel visible", _onboard_panel() != null and _onboard_panel().visible)
	_check("main menu panel hidden", not menu.get_node("Panel").visible)
	_check("onboarding focuses display mode", _mode_btn().has_focus())
	_check("master defaults 80", int(_master().value) == 80)
	_check("deadzone defaults 30", int(_deadzone().value) == 30)
	_check("mode text windowed", _mode_btn().text.contains("視窗"))
	_check("focus mode -> master", _focus_next(_mode_btn()) == _master())
	_check("focus master -> deadzone", _focus_next(_master()) == _deadzone())
	_check("focus deadzone -> confirm", _focus_next(_deadzone()) == _confirm_btn())
	_check("focus confirm wraps to mode", _focus_next(_confirm_btn()) == _mode_btn())
	menu.call("_move_onboard_focus", 1)
	_check("pad down moves to master", _master().has_focus())
	_master().value = 35
	_check("master 35 saves volume", is_equal_approx(AUDIO.get_volume("master"), 0.35))
	_check("master value label follows", _value_label("OnboardMasterValue").text == "35")
	_deadzone().value = 45
	_check("deadzone 45 label follows", _value_label("OnboardDeadzoneValue").text == "45")
	_mode_btn().pressed.emit()
	_check("toggle display to fullscreen", _mode_btn().text.contains("全屏"))

# --- 確認：寫入三項＋標記，回到常規主菜單 ---

func _check_confirm() -> void:
	_confirm_btn().pressed.emit()
	_check("confirm closes onboarding", not menu.call("is_onboarding"))
	_check("onboarding panel hidden", not _onboard_panel().visible)
	_check("main menu panel back", menu.get_node("Panel").visible)
	_check("confirm marks onboarded", SETTINGS.has_onboarded())
	_check("confirm saves fullscreen", SETTINGS.load_display_mode() == "fullscreen")
	_check("confirm saves master 0.35", is_equal_approx(SETTINGS.load_volume("master"), 0.35))
	_check("confirm saves deadzone 0.45", is_equal_approx(SETTINGS.load_deadzone(), 0.45))
	_check("confirm applies deadzone to inputmap", is_equal_approx(InputMap.action_get_deadzone("p1_left"), 0.45))
	_check("main menu focus returns to new", menu.get_node("Panel/VBox/BtnNew").has_focus())

# --- 二次啟動：不重彈引導，沿用上次設定 ---

func _check_second_launch() -> void:
	_check("second launch skips onboarding", not menu.call("is_onboarding"))
	_check("second launch onboarding hidden", not _onboard_panel().visible)
	_check("second launch focuses new", menu.get_node("Panel/VBox/BtnNew").has_focus())
	_check("second launch keeps master 0.35", int(_master().value) == 35)
	_check("second launch keeps deadzone 45", int(_deadzone().value) == 45)
	_check("second launch keeps fullscreen", _mode_btn().text.contains("全屏"))

# --- 壞設定：回預設並重新引導一次 ---

func _write_corrupt_settings() -> void:
	var f: FileAccess = FileAccess.open(TEST_CFG, FileAccess.WRITE)
	if f != null:
		f.store_string("{{{ not a config")
		f.close()

func _check_corrupt_settings() -> void:
	_check("corrupt settings reopens onboarding", menu.call("is_onboarding"))
	_check("corrupt settings master default 0.80", is_equal_approx(SETTINGS.load_volume("master"), 0.8))
	_check("corrupt settings deadzone default 30", int(_deadzone().value) == 30)
	_check("corrupt settings mode windowed", _mode_btn().text.contains("視窗"))

# --- 工具 ---

func _spawn_menu() -> Node:
	var node: Node = load(MAIN_MENU).instantiate()
	root.add_child(node)
	return node

func _free_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.free()
	menu = null

func _onboard_panel() -> Panel:
	return menu.get_node_or_null("OnboardPanel") as Panel

func _mode_btn() -> Button:
	return menu.get_node_or_null("OnboardPanel/OnboardMode") as Button

func _master() -> HSlider:
	return menu.get_node_or_null("OnboardPanel/OnboardMaster") as HSlider

func _deadzone() -> HSlider:
	return menu.get_node_or_null("OnboardPanel/OnboardDeadzone") as HSlider

func _confirm_btn() -> Button:
	return menu.get_node_or_null("OnboardPanel/OnboardConfirm") as Button

func _value_label(node_name: String) -> Label:
	return menu.get_node_or_null("OnboardPanel/%s" % node_name) as Label

func _focus_next(ctrl: Control) -> Control:
	if ctrl == null or ctrl.focus_next.is_empty():
		return null
	return ctrl.get_node_or_null(ctrl.focus_next) as Control

func _finish() -> void:
	_free_menu()
	SETTINGS.clear()
	SETTINGS.reset_path()
	print("ONBOARD_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " checks=", checks)
	quit(0 if fails.is_empty() else 1)
