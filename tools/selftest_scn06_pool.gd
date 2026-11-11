extends SceneTree
## SCN-06 水潭倒影與虎屍剪影自測。

const SCN06 := "res://scenes/chapters/SCN_06_Pool.tscn"

var main: Node
var fails: Array[String] = []
var frame: int = 0

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
	cm.set_beat("B8")
	main = load(SCN06).instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if frame == 5:
		var bg := main.get_node_or_null("Background")
		_check("Background exists", bg != null)
		if bg == null:
			quit(0)
			return true
		_check("Water exists", bg.get_node_or_null("Water") != null)
		_check("Moon exists", bg.get_node_or_null("Moon") != null)
		_check("moon reflection exists", bg.get_node_or_null("MoonReflection0") != null)
		_check("wide moon reflection exists", bg.get_node_or_null("MoonReflectionWide") != null)
		_check("tiger body exists", bg.get_node_or_null("TigerBody") != null)
		_check("tiger head exists", bg.get_node_or_null("TigerHead") != null)
		_check("tiger tail exists", bg.get_node_or_null("TigerTail") != null)
		_check("tiger reflection exists", bg.get_node_or_null("TigerReflection") != null)
		_check("tiger reflection has body", bg.get_node_or_null("TigerReflection/RBody") != null)
		print("SCN06_POOL_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails)
		quit(0)
		return true
	return false
