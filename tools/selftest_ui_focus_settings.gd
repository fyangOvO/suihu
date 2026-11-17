extends SceneTree
## S10 先行自測：殼層焦點鏈、取消鍵回退、主菜單焦點，以及顯示設置持久化。
## 用法：godot --headless --path <game> --script res://tools/selftest_ui_focus_settings.gd

const SCN01 := "res://scenes/chapters/SCN_01_Inn.tscn"
const MAIN_MENU := "res://scenes/MainMenu.tscn"
const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const TEST_CFG := "user://selftest_settings.cfg"
const TEST_SAVE := "user://selftest_focus_checkpoint.json"

var fails: Array = []
var main: Node
var shell: CanvasLayer
var cm
var frame: int = 0
var stage: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _next_of(btn: Button) -> Button:
	return _focus_next(btn) as Button

func _focus_next(ctrl: Control) -> Control:
	if ctrl == null or ctrl.focus_next.is_empty():
		return null
	return ctrl.get_node_or_null(ctrl.focus_next) as Control

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.clear()
	# 主菜單自 V0.3.32 起首次啟動會先彈引導頁；本套只測常規焦點，先標記已引導。
	SETTINGS.mark_onboarded()
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.set_beat("B1")
	main = load(SCN01).instantiate()
	root.add_child(main)

func _finish() -> void:
	SETTINGS.clear()
	SETTINGS.reset_path()
	cm.clear_checkpoint()
	print("UI_FOCUS_SETTINGS_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", frame)
	quit(0 if fails.is_empty() else 1)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if stage == 0:
		shell = main.get_node_or_null("GameShell")
		_check("GameShell exists", shell != null)
		if shell == null:
			_finish()
			return true
		_check("ui_pause action exists", InputMap.has_action("ui_pause"))
		shell.show_pause()
		var resume := shell.get_node_or_null("ShellRoot/PausePanel/PauseResume") as Button
		var settings_btn := shell.get_node_or_null("ShellRoot/PausePanel/PauseSettings") as Button
		var quit := shell.get_node_or_null("ShellRoot/PausePanel/PauseQuit") as Button
		_check("pause initial focus on resume", resume != null and resume.has_focus())
		_check("pause resume -> settings", _next_of(resume) == settings_btn)
		_check("pause quit wraps to resume", _next_of(quit) == resume)
		settings_btn.pressed.emit()
		_check("settings page after button", shell.current_page() == "settings")
		var mode := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsMode") as Button
		var camfx := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsCameraFx") as Button
		var master := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsMaster") as HSlider
		var bgm := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsBgm") as HSlider
		var sfx := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsSfx") as HSlider
		var voice := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsVoice") as HSlider
		var back := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsBack") as Button
		var deadzone := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsDeadzone") as HSlider
		_check("settings four volume sliders", master != null and bgm != null and sfx != null and voice != null)
		_check("settings deadzone slider", deadzone != null)
		_check("settings initial focus on mode", mode != null and mode.has_focus())
		_check("settings camera fx toggle exists", camfx != null)
		_check("settings mode -> camera fx", _focus_next(mode) == camfx)
		_check("settings camera fx -> master", _focus_next(camfx) == master)
		_check("settings master -> bgm", _focus_next(master) == bgm)
		_check("settings bgm -> sfx", _focus_next(bgm) == sfx)
		_check("settings sfx -> voice", _focus_next(sfx) == voice)
		_check("settings voice -> deadzone", _focus_next(voice) == deadzone)
		_check("settings deadzone defaults 30", deadzone != null and int(deadzone.value) == 30)
		_check("settings deadzone -> back", _focus_next(deadzone) == back)
		_check("settings back -> mode", _focus_next(back) == mode)
		_check("settings camera fx defaults on", camfx != null and camfx.text.begins_with("鏡頭效果：開"))
		if camfx != null:
			camfx.pressed.emit()
			_check("camera fx toggle saves off",
				not SETTINGS.load_camera_fx() and camfx.text.begins_with("鏡頭效果：關"))
			camfx.pressed.emit()
			_check("camera fx toggle saves on",
				SETTINGS.load_camera_fx() and camfx.text.begins_with("鏡頭效果：開"))
		_check("volume defaults shown", master != null and int(master.value) == 80
			and bgm != null and int(bgm.value) == 70
			and sfx != null and int(sfx.value) == 80
			and voice != null and int(voice.value) == 90)
		if master != null:
			master.value = 35
			var master_value := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsMasterValue") as Label
			_check("volume slider saves", is_equal_approx(SETTINGS.load_volume("master"), 0.35))
			_check("volume label follows", master_value != null and master_value.text == "35")
			master.value = 80
			_check("volume slider restores", is_equal_approx(SETTINGS.load_volume("master"), 0.8))
		_check("cancel from settings returns pause", shell.handle_cancel()
			and shell.current_page() == "pause" and settings_btn.has_focus())
		_check("cancel from pause resumes", shell.handle_cancel()
			and not shell.is_open() and not paused)
		var pause_event := InputEventAction.new()
		pause_event.action = "ui_pause"
		pause_event.pressed = true
		main.call("_unhandled_input", pause_event)
		_check("ui_pause opens pause via stage", shell.current_page() == "pause")
		shell.handle_cancel()
		_check("ui_pause pause closes", not shell.is_open() and not paused)
		shell.show_death(false)
		var retry := shell.get_node_or_null("ShellRoot/DeathPanel/DeathRetry") as Button
		var checkpoint := shell.get_node_or_null("ShellRoot/DeathPanel/DeathCheckpoint") as Button
		var death_menu := shell.get_node_or_null("ShellRoot/DeathPanel/DeathMenu") as Button
		_check("death no-save initial focus", retry != null and retry.has_focus())
		_check("death no-save disables checkpoint", checkpoint != null and checkpoint.disabled)
		_check("death no-save skips checkpoint", _next_of(retry) == death_menu)
		shell.show_death(true)
		_check("death with-save enables checkpoint", checkpoint != null and not checkpoint.disabled)
		_check("death with-save retry -> checkpoint", _next_of(retry) == checkpoint)
		_check("death with-save checkpoint -> menu", _next_of(checkpoint) == death_menu)
		_check("death menu wraps to retry", _next_of(death_menu) == retry)
		shell.show_summary({"碎銀": 3, "小虎爪": 2, "伥鬼的木牌": 1})
		var summary_new := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryNew") as Button
		var summary_menu := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryMenu") as Button
		_check("summary initial focus on new", summary_new != null and summary_new.has_focus())
		_check("summary new -> menu", _next_of(summary_new) == summary_menu)
		_check("summary menu -> new", _next_of(summary_menu) == summary_new)
		shell._on_resume()
		stage = 1
		frame = 0
		return false
	if stage == 1:
		main.queue_free()
		main = load(MAIN_MENU).instantiate()
		root.add_child(main)
		stage = 2
		frame = 0
		return false
	if stage == 2 and frame >= 5:
		stage = 3
		var new_btn := main.get_node_or_null("Panel/VBox/BtnNew") as Button
		var continue_btn := main.get_node_or_null("Panel/VBox/BtnContinue") as Button
		var quit_btn := main.get_node_or_null("Panel/VBox/BtnQuit") as Button
		_check("main menu initial focus on new", new_btn != null and new_btn.has_focus())
		_check("main menu continue disabled without save", continue_btn != null and continue_btn.disabled)
		var menu = main
		menu.call("_move_focus", 1)
		_check("main menu skips disabled continue", quit_btn != null and quit_btn.has_focus())
		menu.call("_move_focus", 1)
		_check("main menu wraps to new", new_btn != null and new_btn.has_focus())
		menu.call("_move_focus", -1)
		_check("main menu wraps back to quit", quit_btn != null and quit_btn.has_focus())
		_check("display mode defaults windowed", SETTINGS.load_display_mode() == "windowed")
		_check("display mode save fullscreen", SETTINGS.save_display_mode("fullscreen")
			and SETTINGS.load_display_mode() == "fullscreen")
		_check("display mode save windowed", SETTINGS.save_display_mode("windowed")
			and SETTINGS.load_display_mode() == "windowed")
		var cfg := ConfigFile.new()
		if cfg.load(TEST_CFG) == OK:
			cfg.set_value("display", "mode", "bogus")
			cfg.save(TEST_CFG)
		_check("invalid settings fall back to windowed", SETTINGS.load_display_mode() == "windowed")
		_check("save repairs invalid settings", SETTINGS.save_display_mode("fullscreen")
			and SETTINGS.load_display_mode() == "fullscreen")
		_check("settings test path isolated", SETTINGS.current_path() == TEST_CFG)
		_finish()
		return true
	return false
