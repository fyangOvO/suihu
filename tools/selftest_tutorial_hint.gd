extends SceneTree
## 教學提示觀感自測：BannerTag 只在教學時出現，Banner 與 Boss 條同寬同軸。
## 用法：godot --headless --path <game> --script res://tools/selftest_tutorial_hint.gd

const SCN02 := "res://scenes/chapters/SCN_02_Trail.tscn"

var main: Node
var frame: int = 0
var fails: Array[String] = []

func _check(label: String, ok: bool) -> void:
	if not ok:
		fails.append(label)
	print("CHECK ", label, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	var cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B3")
	main = load(SCN02).instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	var hud = main.get_node("HUD")
	var panel := hud.get_node("BannerPanel") as Panel
	var tag := hud.get_node("BannerTag") as Label
	var body := hud.get_node("Banner") as Label
	main.show_banner("J 輕擊 / K 重擊：木棍很長，貼身前先看起手。", 2.4, "教學")
	_check("tutorial tag visible", tag.visible)
	_check("tutorial tag reads 教學", tag.text == "教學")
	_check("tutorial tag inset 24", is_equal_approx(tag.position.x - panel.position.x, 24.0))
	_check("banner width matches boss panel", is_equal_approx(panel.size.x, 960.0))
	_check("tutorial body leaves tag room", is_equal_approx(body.position.x, 600.0))
	_check("tutorial body uses 28px", body.get_theme_font_size("font_size") == 28)
	main.show_banner("崗頂", 2.0, "")
	_check("story banner hides tag", not tag.visible)
	_check("story body re-centred", is_equal_approx(body.position.x, 500.0) and body.get_theme_font_size("font_size") == 30)
	print("TUTORIAL_HINT_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", frame)
	quit(0 if fails.is_empty() else 1)
	return true
