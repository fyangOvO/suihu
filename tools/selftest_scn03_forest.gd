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
		_check("forest trunk exists", bg.get_node_or_null("Tree92/Trunk92") != null and bg.get_node_or_null("Tree92/Branch92L") != null)
		_check("forest fork branches exist", bg.get_node_or_null("Tree92/Branch92R") != null and bg.get_node_or_null("Tree92/Branch92LA") != null)
		_check("forest branch leaves exist", bg.get_node_or_null("Tree92/Branch92LAALeaf") != null)
		_check("forest crown exists", bg.get_node_or_null("Crown0") != null)
		_check("ground mist wisps exist", bg.get_node_or_null("Mist90") != null and bg.get_node_or_null("Mist1370") != null)
		_check("moon glow exists", bg.get_node_or_null("MoonGlowWide") != null and bg.get_node_or_null("MoonGlowCore") != null)
		_check("moon shafts exist", bg.get_node_or_null("MoonShaftVolume") != null and bg.get_node_or_null("MoonShaftA") != null and bg.get_node_or_null("MoonShaftB") != null and bg.get_node_or_null("MoonShaftC") != null and bg.get_node_or_null("MoonShaftD") != null)
		var shaft_a := bg.get_node_or_null("MoonShaftA")
		var shaft_tex: Sprite2D = null
		if shaft_a != null:
			shaft_tex = shaft_a.get_node_or_null("MoonShaftASprite") as Sprite2D
		_check("moon shafts are additive", shaft_tex != null and shaft_tex.material is CanvasItemMaterial and (shaft_tex.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		var far := bg.get_node_or_null("FogFar") as TextureRect
		var mid := bg.get_node_or_null("FogMid") as TextureRect
		var near_layer := bg.get_node_or_null("FogNear") as TextureRect
		var trunk := bg.get_node_or_null("Tree92") as Node2D
		_check("moon shafts behind trunks", shaft_a != null and trunk != null and shaft_a.get_index() < trunk.get_index())
		_check("FogFar is behind trunks", far != null and trunk != null and far.get_index() < trunk.get_index())
		_check("FogNear is in front of trunks", near_layer != null and trunk != null and near_layer.get_index() > trunk.get_index())
		_check("fog bands stack high to low", far != null and mid != null and near_layer != null and far.position.y < mid.position.y and mid.position.y < near_layer.position.y)
		_check("fog speeds increase by depth", main._fog_speeds.size() == 3 and main._fog_speeds[0] < main._fog_speeds[1] and main._fog_speeds[1] < main._fog_speeds[2])
		_check("fog layers use distinct textures", far != null and mid != null and near_layer != null and far.texture != mid.texture and mid.texture != near_layer.texture)
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
