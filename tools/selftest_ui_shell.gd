extends SceneTree
## UI-01／UI-08 先行殼層自測：暫停、設置、死亡重開、章末結算與 Boss 條。

const SCN01 := "res://scenes/chapters/SCN_01_Inn.tscn"
const SCN05 := "res://scenes/chapters/SCN_05_Ridge.tscn"

var main: Node
var shell: CanvasLayer
var fails: Array[String] = []
var frame: int = 0
var stage: int = 0

func _check(label: String, ok: bool) -> void:
	if not ok:
		fails.append(label)
	print("CHECK ", label, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B1")
	main = load(SCN01).instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if stage == 0:
		shell = main.get_node_or_null("GameShell")
		_check("GameShell exists", shell != null)
		if shell == null:
			quit(0)
			return true
		_check("GameShell layer 30", shell.layer == 30)
		shell.show_pause()
		var pause_panel := shell.get_node_or_null("ShellRoot/PausePanel") as Panel
		_check("pause panel visible", pause_panel != null and pause_panel.visible)
		_check("pause page", shell.current_page() == "pause")
		_check("tree paused", paused)
		_check("pause panel paper", pause_panel != null and pause_panel.has_node("PaperGrain"))
		stage = 1
		frame = 0
	elif stage == 1:
		shell.show_death(true)
		var death_panel := shell.get_node_or_null("ShellRoot/DeathPanel") as Panel
		var checkpoint := shell.get_node_or_null("ShellRoot/DeathPanel/DeathCheckpoint") as Button
		_check("death panel visible", death_panel != null and death_panel.visible)
		_check("death page", shell.current_page() == "death")
		_check("death checkpoint enabled", checkpoint != null and not checkpoint.disabled)
		shell.show_summary({"碎銀": 3, "小虎爪": 2, "伥鬼的木牌": 1})
		var summary := shell.get_node_or_null("ShellRoot/SummaryPanel") as Panel
		var stats := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryStats") as Label
		_check("summary panel visible", summary != null and summary.visible)
		_check("summary stats has B1-B9", stats != null and stats.text.find("B1 — B9") >= 0)
		shell._on_resume()
		_check("resume unpauses", not paused and not shell.is_open())
		main.queue_free()
		main = load(SCN05).instantiate()
		root.add_child(main)
		stage = 2
		frame = 0
	elif stage == 2 and frame >= 5:
		var hud = main.get_node_or_null("HUD")
		_check("boss bar exists", hud != null and hud.get_node_or_null("BossPanel") != null)
		_check("boss bar HP exists", hud != null and hud.get_node_or_null("BossHP") != null)
		var boss_panel: Panel = null
		var p2_panel: Panel = null
		if hud != null:
			boss_panel = hud.get_node_or_null("BossPanel") as Panel
			p2_panel = hud.get_node_or_null("P2Panel") as Panel
		_check("boss bar visible", boss_panel != null and boss_panel.visible)
		_check("boss hides P2 panel", p2_panel != null and not p2_panel.visible)
		if fails.is_empty():
			print("UI_SHELL_SELFTEST result=PASS")
		else:
			print("UI_SHELL_SELFTEST fails=", fails)
		quit(0)
		return true
	return false
