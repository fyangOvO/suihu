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
	if btn == null or btn.focus_next.is_empty():
		return null
	return btn.get_node_or_null(btn.focus_next) as Button

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.clear()
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
		var back := shell.get_node_or_null("ShellRoot/SettingsPanel/SettingsBack") as Button
		_check("settings initial focus on mode", mode != null and mode.has_focus())
		_check("settings mode -> back", _next_of(mode) == back)
		_check("settings back -> mode", _next_of(back) == mode)
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
