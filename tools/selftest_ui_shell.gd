extends SceneTree
## UI-01／UI-08 先行殼層自測：暫停、設置、死亡重開、章末結算與 Boss 條。

const SCN01 := "res://scenes/chapters/SCN_01_Inn.tscn"
const SCN02 := "res://scenes/chapters/SCN_02_Trail.tscn"
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
		var settings_panel := shell.get_node_or_null("ShellRoot/SettingsPanel") as Panel
		var settings_titles: int = 0
		if settings_panel != null:
			for child in settings_panel.get_children():
				if child is Label and (child as Label).text == "設置":
					settings_titles += 1
		_check("settings title appears once", settings_titles == 1)
		shell.show_pause()
		var pause_panel := shell.get_node_or_null("ShellRoot/PausePanel") as Panel
		_check("pause panel visible", pause_panel != null and pause_panel.visible)
		_check("pause page", shell.current_page() == "pause")
		_check("tree paused", paused)
		_check("pause panel paper", pause_panel != null and pause_panel.has_node("PaperGrain"))
		_check("pause panel nine-patch", pause_panel != null and pause_panel.has_node("NinePatchFrame"))
		_check("pause title rule", pause_panel != null and pause_panel.has_node("PauseRule"))
		for name in ["PauseResume", "PauseSettings", "PauseMenu", "PauseQuit"]:
			var btn := shell.get_node_or_null("ShellRoot/PausePanel/%s" % name) as Button
			_check("%s has icon" % name, btn != null and btn.has_node("MenuIcon"))
		var settings_page := shell.get_node_or_null("ShellRoot/SettingsPanel") as Panel
		_check("settings panel nine-patch", settings_page != null and settings_page.has_node("NinePatchFrame"))
		_check("settings section rule", settings_page != null and settings_page.has_node("SettingsRule") and settings_page.has_node("SettingsSection"))
		stage = 1
		frame = 0
	elif stage == 1:
		shell.show_death(true)
		var death_panel := shell.get_node_or_null("ShellRoot/DeathPanel") as Panel
		var checkpoint := shell.get_node_or_null("ShellRoot/DeathPanel/DeathCheckpoint") as Button
		_check("death panel visible", death_panel != null and death_panel.visible)
		_check("death page", shell.current_page() == "death")
		_check("death panel nine-patch", death_panel != null and death_panel.has_node("NinePatchFrame"))
		_check("death title rule", death_panel != null and death_panel.has_node("DeathRule"))
		_check("death checkpoint enabled", checkpoint != null and not checkpoint.disabled)
		_check("death buttons have icons", checkpoint != null and checkpoint.has_node("MenuIcon") and shell.get_node_or_null("ShellRoot/DeathPanel/DeathRetry").has_node("MenuIcon"))
		shell.show_summary({"碎銀": 3, "小虎爪": 2, "伥鬼的木牌": 1})
		var summary := shell.get_node_or_null("ShellRoot/SummaryPanel") as Panel
		var stats := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryStats") as Label
		_check("summary panel visible", summary != null and summary.visible)
		_check("summary panel nine-patch", summary != null and summary.has_node("NinePatchFrame"))
		_check("summary title rule is a line", summary != null and summary.get_node_or_null("SummaryRule") is ColorRect)
		_check("summary buttons have icons", summary != null and summary.get_node_or_null("SummaryNew").has_node("MenuIcon") and summary.get_node_or_null("SummaryMenu").has_node("MenuIcon"))
		_check("summary stats has B1-B9", stats != null and stats.text.find("B1 — B9") >= 0)
		var summary_hint := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryHint") as Label
		var summary_menu := shell.get_node_or_null("ShellRoot/SummaryPanel/SummaryMenu") as Button
		_check("summary hint clears menu", summary_hint != null and summary_menu != null and summary_menu.position.y + summary_menu.size.y + 16.0 <= summary_hint.position.y)
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
		var banner_panel: Panel = null
		var boss_hp: ProgressBar = null
		var tag: Label = null
		if hud != null:
			boss_panel = hud.get_node_or_null("BossPanel") as Panel
			p2_panel = hud.get_node_or_null("P2Panel") as Panel
			banner_panel = hud.get_node_or_null("BannerPanel") as Panel
			boss_hp = hud.get_node_or_null("BossHP") as ProgressBar
			tag = hud.get_node_or_null("BannerTag") as Label
		_check("boss bar visible", boss_panel != null and boss_panel.visible)
		_check("boss hides P2 panel", p2_panel != null and not p2_panel.visible)
		_check("boss and banner share x", boss_panel != null and banner_panel != null and is_equal_approx(boss_panel.position.x, banner_panel.position.x))
		_check("boss and banner share width", boss_panel != null and banner_panel != null and is_equal_approx(boss_panel.size.x, banner_panel.size.x))
		_check("boss HP inset 24 from panel", boss_panel != null and boss_hp != null and is_equal_approx(boss_hp.position.x - boss_panel.position.x, 24.0) and is_equal_approx(boss_hp.size.x, boss_panel.size.x - 48.0))
		var pips := 0
		for i in range(3):
			if hud != null and hud.get_node_or_null("BossPhasePip%d" % i) != null:
				pips += 1
		_check("boss has three phase pips", pips == 3)
		var boss_hp_text := hud.get_node_or_null("BossHPText") as Label
		_check("boss HP text inset 24 from right", boss_panel != null and boss_hp_text != null and is_equal_approx(boss_hp_text.position.x + boss_hp_text.size.x, boss_panel.position.x + boss_panel.size.x - 24.0))
		var pip_clear := true
		for i in range(3):
			var pip := hud.get_node_or_null("BossPhasePip%d" % i) as ColorRect
			if pip != null and boss_hp_text != null and pip.position.x + pip.size.x + 4.0 > boss_hp_text.position.x:
				pip_clear = false
		_check("boss phase pips clear HP text", pip_clear)
		_check("story banner has no tutorial tag", tag != null and not tag.visible)
		main.queue_free()
		var cm2 = root.get_node("ChapterManager")
		cm2.set_beat("B3")
		main = load(SCN02).instantiate()
		root.add_child(main)
		stage = 3
		frame = 0
	elif stage == 3 and frame >= 5:
		var hud2 = main.get_node_or_null("HUD")
		var p1_panel := hud2.get_node_or_null("P1Panel") as Panel if hud2 != null else null
		var p2_panel := hud2.get_node_or_null("P2Panel") as Panel if hud2 != null else null
		_check("P2 panel visible in normal fight", p2_panel != null and p2_panel.visible)
		_check("P1 and P2 share width", p1_panel != null and p2_panel != null and is_equal_approx(p1_panel.size.x, p2_panel.size.x))
		_check("P1 and P2 share height", p1_panel != null and p2_panel != null and is_equal_approx(p1_panel.size.y, p2_panel.size.y))
		_check("P1 and P2 share top edge", p1_panel != null and p2_panel != null and is_equal_approx(p1_panel.position.y, p2_panel.position.y))
		_check("P2 panel mirrors P1 inset", p2_panel != null and is_equal_approx(p2_panel.position.x + p2_panel.size.x, 1920.0 - 34.0))
		_check("P2 panel nine-patch", p2_panel != null and p2_panel.has_node("NinePatchFrame") and p2_panel.has_node("P2Rule"))
		if fails.is_empty():
			print("UI_SHELL_SELFTEST result=PASS")
		else:
			print("UI_SHELL_SELFTEST fails=", fails)
		quit(0)
		return true
	return false
