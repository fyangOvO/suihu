extends SceneTree
## S11 END-01 自測：章末結算 → 結局名單 → 跳過／自動滾完 → 回主菜單信號。
## 用法：godot --headless --path <game> --script res://tools/selftest_end_credits.gd

const GAME_SHELL := preload("res://scripts/ui/game_shell.gd")

var shell: CanvasLayer
var fails: Array = []
var frame: int = 0
var stage: int = 0
var menu_count: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _on_menu_requested() -> void:
	menu_count += 1

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	shell = GAME_SHELL.new()
	root.add_child(shell)
	shell.menu_requested.connect(_on_menu_requested)

func _finish() -> void:
	print("END_CREDITS_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", frame)
	quit(0 if fails.is_empty() else 1)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	if stage == 0:
		stage = 1
		shell.show_summary({"碎銀": 3, "小虎爪": 2, "伥鬼的木牌": 1})
		_check("summary shown", shell.current_page() == "summary")
		var summary_menu := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryMenu") as Button
		_check("summary has menu button", summary_menu != null)
		summary_menu.pressed.emit()
		_check("summary menu enters credits", shell.current_page() == "credits")
		var credits := shell.get_node_or_null("ShellRoot/CreditsPage") as Control
		var body := shell.get_node_or_null("ShellRoot/CreditsPage/CreditsClip/CreditsBody") as Control
		var skip := shell.get_node_or_null("ShellRoot/CreditsPage/CreditsSkip") as Button
		_check("credits page visible", credits != null and credits.visible)
		_check("credits body has content", body != null and body.size.y > 600.0)
		_check("credits skip has focus", skip != null and skip.has_focus())
		var before: float = body.position.y if body != null else 0.0
		shell.call("_process", 0.5)
		_check("credits scrolls upward", body != null and body.position.y < before)
		_check("credits stays until duration", shell.current_page() == "credits")
		shell.call("_on_credits_skip")
		_check("skip returns menu signal", menu_count == 1 and not shell.is_open())
		return false
	if stage == 1 and frame >= 6:
		stage = 2
		menu_count = 0
		shell.show_credits(0.2)
		_check("credits can restart standalone", shell.current_page() == "credits")
		shell.call("_process", 0.3)
		_check("credits auto-finishes", menu_count == 1 and not shell.is_open())
		_finish()
		return true
	return false
