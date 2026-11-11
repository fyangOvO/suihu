extends SceneTree
## SCN-03 亂林三層霧自測：節點、紋理、視差位移與林影。

const SCN03 := "res://scenes/chapters/SCN_03_Forest.tscn"

var main: Node
var fails: Array[String] = []
var frame: int = 0
var start_x: float = 0.0
var checked_move: bool = false

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
	cm.set_beat("B5")
	main = load(SCN03).instantiate()
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
		for layer_name in ["FogFar", "FogMid", "FogNear"]:
			var layer := bg.get_node_or_null(layer_name) as TextureRect
			_check("%s exists" % layer_name, layer != null)
			if layer != null:
				_check("%s has texture" % layer_name, layer.texture != null)
				_check("%s alpha in range" % layer_name, layer.modulate.a > 0.15 and layer.modulate.a < 0.55)
		_check("forest trunk exists", bg.get_node_or_null("Trunk92") != null)
		_check("forest crown exists", bg.get_node_or_null("Crown0") != null)
		var banner := main.get_node_or_null("HUD/Banner") as Label
		_check("banner text", banner != null and banner.text.find("霧裡") >= 0)
		start_x = (bg.get_node("FogNear") as TextureRect).position.x
	if frame >= 10 and not checked_move:
		checked_move = true
		var bg := main.get_node_or_null("Background")
		var near := bg.get_node_or_null("FogNear") as TextureRect
		_check("FogNear parallax moved", near != null and near.position.x < start_x)
		print("SCN03_FOREST_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails)
		quit(0)
		return true
	return false
