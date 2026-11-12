extends "res://scripts/chapters/stage_base.gd"
## SCN-03 亂林：B5 吊睛小虎精英戰。
## 三層霧（遠／中／近）＋林影，全部程序化生成，直接掛在背景下，保證在角色之前、HUD 之後。

const FOREST_INK := Color(0.035, 0.050, 0.043, 0.88)
const FOREST_INK_2 := Color(0.050, 0.072, 0.060, 0.78)

const FOG_TRAVEL := 600.0

var _fog_layers: Array[TextureRect] = []
var _fog_speeds: Array[float] = []

func scene_id() -> String:
	return "SCN-03"

func scene_title() -> String:
	return "亂林"

func first_beat() -> String:
	return "B5"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return "res://scenes/Tiger.tscn"

func opponent_display_name() -> String:
	return "吊睛小虎"

func _on_stage_start() -> void:
	_build_fog()
	show_banner("霧裡，低吼。", 2.0)

func _tick_stage(_delta: float) -> void:
	for i in range(_fog_layers.size()):
		var layer := _fog_layers[i]
		if not is_instance_valid(layer):
			continue
		layer.position.x -= _fog_speeds[i] * _delta
		if layer.position.x <= -FOG_TRAVEL:
			layer.position.x = 0.0
	if p2 != null and p2.current_hp <= 0 and p2._death_done:
		_finish_to("B6", 2.0, "小虎倒了，霧散了。")

func _build_fog() -> void:
	var bg := get_node_or_null("Background")
	if bg == null:
		return
	if bg.get_node_or_null("FogFar") != null:
		return

	# 林影：先壓暗背景，再用邊緣樹幹與頂部枝冠把「山道」變成「亂林」。
	if bg is CanvasItem:
		(bg as CanvasItem).modulate = Color(0.68, 0.74, 0.68, 1.0)

	# 遠霧先掛在背景後方，讓樹幹真正遮住它；中／近霧再依序蓋到林影上。
	_add_fog_layer(bg, "FogFar", 0.0055, 18.0, 108.0, 260.0, Color(0.54, 0.66, 0.70, 0.46), -80.0)
	_add_trunks(bg)
	_add_canopy(bg)
	_add_fog_layer(bg, "FogMid", 0.010, 46.0, 390.0, 230.0, Color(0.62, 0.70, 0.64, 0.38), -260.0)
	_add_fog_layer(bg, "FogNear", 0.018, 92.0, 720.0, 200.0, Color(0.78, 0.84, 0.76, 0.32), -470.0)

func _add_fog_layer(parent: Node, node_name: String, frequency: float, speed: float, y: float, height: float, tint: Color, start_x: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(speed * 13.0 + frequency * 1000.0)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var img := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	for py in range(128):
		var envelope: float = 1.0 - abs(float(py) / 127.0 * 2.0 - 1.0)
		envelope = clampf(envelope * 1.5, 0.0, 1.0)
		for px in range(512):
			var n := noise.get_noise_2d(px, py)
			var a := clampf((n + 0.55) * 0.9, 0.0, 1.0)
			img.set_pixel(px, py, Color(tint.r, tint.g, tint.b, a * envelope * 0.90))
	var tex := ImageTexture.create_from_image(img)

	var layer := TextureRect.new()
	layer.name = node_name
	layer.position = Vector2(start_x, y)
	layer.size = Vector2(2600, height)
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.modulate = Color(1.0, 1.0, 1.0, tint.a)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	_fog_layers.append(layer)
	_fog_speeds.append(speed)

func _add_trunks(parent: Node) -> void:
	for item in [
		Vector2(92, 0), Vector2(210, 0), Vector2(1710, 0), Vector2(1830, 0),
		Vector2(360, 0), Vector2(1560, 0),
	]:
		var tree := Node2D.new()
		tree.name = "Tree%d" % int(item.x)
		tree.position = item
		parent.add_child(tree)

		# 主幹：下粗上細，保留樹皮折線；不再是等寬黑柱。
		_add_poly(tree, "Trunk%d" % int(item.x), [
			Vector2(-18, 900), Vector2(18, 900), Vector2(13, 620),
			Vector2(10, 420), Vector2(6, 210), Vector2(-5, 210),
			Vector2(-9, 420), Vector2(-13, 620),
		], FOREST_INK)
		# 根部：向兩側抓地。
		_add_poly(tree, "Root%dL" % int(item.x), [
			Vector2(-14, 900), Vector2(-58, 900), Vector2(-38, 850), Vector2(-10, 820),
		], FOREST_INK)
		_add_poly(tree, "Root%dR" % int(item.x), [
			Vector2(14, 900), Vector2(56, 900), Vector2(34, 852), Vector2(9, 824),
		], FOREST_INK)
		# 側枝：左右各一枝，帶粗細變化；枝端接樹冠。
		_add_branch(tree, "Branch%dL" % int(item.x), Vector2(0, 570), Vector2(-108, 438), 15.0, 3.0)
		_add_branch(tree, "Branch%dR" % int(item.x), Vector2(0, 468), Vector2(112, 330), 12.0, 2.5)
		_add_branch(tree, "Branch%dL2" % int(item.x), Vector2(-6, 390), Vector2(-62, 286), 8.0, 2.0)
		_add_branch(tree, "Branch%dR2" % int(item.x), Vector2(4, 310), Vector2(58, 218), 7.0, 1.8)

func _add_branch(parent: Node2D, node_name: String, from: Vector2, to: Vector2, width_from: float, width_to: float) -> void:
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	_add_poly(parent, node_name, [
		from + perp * width_from * 0.5,
		to + perp * width_to * 0.5,
		to - perp * width_to * 0.5,
		from - perp * width_from * 0.5,
	], FOREST_INK)

func _add_canopy(parent: Node) -> void:
	# 樹冠改成多團葉簇，避免頂部變成一整排黑色長塊。
	for item in [
		Vector2(0, 0), Vector2(280, 0), Vector2(570, 0),
		Vector2(1390, 0), Vector2(1670, 0), Vector2(1910, 0),
	]:
		var base_x: float = item.x
		for j in range(4):
			var offset := Vector2(float(j - 1) * 48.0 + 18.0, 46.0 + float(j % 2) * 42.0 + 12.0)
			var radius := 32.0 + float((j + int(base_x)) % 3) * 8.0
			var node_name: String = ("Crown%d" % int(base_x)) if j == 0 else ("Crown%dLeaf%d" % [int(base_x), j])
			_add_leaf(parent, node_name, Vector2(base_x, 0) + offset, radius)

func _add_leaf(parent: Node, node_name: String, center: Vector2, radius: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var r := radius * (0.76 + 0.24 * float((i * 7 + 3) % 5) / 4.0)
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.62))
	_add_poly(parent, node_name, pts, FOREST_INK_2)

func _add_poly(parent: Node, node_name: String, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)
