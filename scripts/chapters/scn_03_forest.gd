extends "res://scripts/chapters/stage_base.gd"
## SCN-03 亂林：B5 吊睛小虎精英戰。
## 三層霧（遠／中／近）＋林影，全部程序化生成，直接掛在背景下，保證在角色之前、HUD 之後。

const FOREST_INK := Color(0.035, 0.050, 0.043, 0.92)
const FOREST_INK_2 := Color(0.050, 0.072, 0.060, 0.76)
const FOREST_FAR := Color(0.075, 0.098, 0.082, 0.70)
const FOREST_RIM := Color(0.19, 0.25, 0.20, 0.24)

const FOG_TRAVEL := 600.0
const FOG_TEXTURE_W := 768
const FOG_TEXTURE_H := 160

var _fog_layers: Array[TextureRect] = []
var _fog_speeds: Array[float] = []
var _fog_base_y: Array[float] = []
var _elapsed := 0.0

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
	_elapsed += _delta
	for i in range(_fog_layers.size()):
		var layer := _fog_layers[i]
		if not is_instance_valid(layer):
			continue
		layer.position.x -= _fog_speeds[i] * _delta
		if layer.position.x <= -FOG_TRAVEL:
			layer.position.x = 0.0
		# 極慢的上下浮動，避免三條霧帶像固定橫幅。
		layer.position.y = _fog_base_y[i] + sin(_elapsed * (0.32 + float(i) * 0.12) + float(i) * 1.7) * 3.0
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
		(bg as CanvasItem).modulate = Color(0.66, 0.72, 0.66, 1.0)

	# 遠霧先掛在背景後方，讓樹幹真正遮住它；中／近霧再依序蓋到林影上。
	_add_fog_layer(bg, "FogFar", 0.0065, 18.0, 90.0, 258.0, Color(0.54, 0.66, 0.70, 0.40), -80.0)
	_add_trunks(bg)
	_add_canopy(bg)
	_add_fog_layer(bg, "FogMid", 0.0110, 46.0, 338.0, 274.0, Color(0.62, 0.70, 0.64, 0.34), -260.0)
	_add_fog_layer(bg, "FogNear", 0.0190, 92.0, 688.0, 226.0, Color(0.78, 0.84, 0.76, 0.29), -470.0)
	_add_ground_wisps(bg)

func _add_fog_layer(parent: Node, node_name: String, frequency: float, speed: float, y: float, height: float, tint: Color, start_x: float) -> void:
	var tex := _make_fog_texture(frequency, tint, int(speed * 13.0 + frequency * 1000.0))

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
	_fog_base_y.append(y)

func _make_fog_texture(frequency: float, tint: Color, seed: int) -> ImageTexture:
	var base := FastNoiseLite.new()
	base.seed = seed
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX
	base.frequency = frequency
	base.fractal_octaves = 4

	var detail := FastNoiseLite.new()
	detail.seed = seed + 417
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = frequency * 3.1
	detail.fractal_octaves = 2

	var img := Image.create(FOG_TEXTURE_W, FOG_TEXTURE_H, false, Image.FORMAT_RGBA8)
	for py in range(FOG_TEXTURE_H):
		var t := float(py) / float(FOG_TEXTURE_H - 1)
		var envelope := sin(PI * t)
		envelope = pow(envelope, 1.28)
		for px in range(FOG_TEXTURE_W):
			var n := base.get_noise_2d(float(px), float(py))
			var d := detail.get_noise_2d(float(px), float(py))
			var v := clampf((n + 0.55) * 0.86 + d * 0.34, 0.0, 1.0)
			# 手動 smoothstep：把整片灰霧打出可穿的洞，不讓上下緣變成硬邊。
			var a := clampf((v - 0.12) / 0.68, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			a *= envelope
			img.set_pixel(px, py, Color(tint.r, tint.g, tint.b, a))

	return ImageTexture.create_from_image(img)

func _add_ground_wisps(parent: Node) -> void:
	# 近霧之外再放幾團貼地霧，打斷整條水平帶。
	for item in [
		Vector3(90.0, 786.0, 0.20), Vector3(720.0, 812.0, 0.16),
		Vector3(1370.0, 792.0, 0.18), Vector3(1680.0, 824.0, 0.14),
	]:
		_add_ground_wisp(parent, "Mist%d" % int(item.x), Vector2(item.x, item.y), Vector2(560, 150), item.z)

func _add_ground_wisp(parent: Node, node_name: String, pos: Vector2, size: Vector2, alpha: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.74, 0.80, 0.74, 1.0))
	grad.set_color(1, Color(0.74, 0.80, 0.74, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 96
	tex.height = 48
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	var wisp := TextureRect.new()
	wisp.name = node_name
	wisp.position = pos
	wisp.size = size
	wisp.texture = tex
	wisp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wisp.stretch_mode = TextureRect.STRETCH_SCALE
	wisp.modulate = Color(1.0, 1.0, 1.0, alpha)
	wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wisp)

func _add_trunks(parent: Node) -> void:
	# 近景／中景／遠景分開，讓左右邊緣不是一整排同寬黑柱。
	var specs := [
		{"x": 92.0, "scale": 1.00, "ink": FOREST_INK, "seed": 0},
		{"x": 210.0, "scale": 0.82, "ink": FOREST_INK, "seed": 1},
		{"x": 360.0, "scale": 0.72, "ink": FOREST_FAR, "seed": 2},
		{"x": 1560.0, "scale": 0.72, "ink": FOREST_FAR, "seed": 3},
		{"x": 1710.0, "scale": 0.86, "ink": FOREST_INK, "seed": 4},
		{"x": 1830.0, "scale": 1.00, "ink": FOREST_INK, "seed": 5},
	]
	for spec in specs:
		var x: float = spec["x"]
		var s: float = spec["scale"]
		var ink: Color = spec["ink"]
		var seed: int = spec["seed"]
		var tree := Node2D.new()
		tree.name = "Tree%d" % int(x)
		tree.position = Vector2(x, 900.0)
		tree.scale = Vector2(s, s)
		parent.add_child(tree)

		_add_tree_body(tree, int(x), ink, seed)
		_add_tree_roots(tree, int(x), ink, seed)
		_add_tree_limbs(tree, int(x), ink, seed)

func _add_tree_body(tree: Node2D, id: int, ink: Color, seed: int) -> void:
	var lean := float((seed * 17) % 9 - 4) * 0.8
	_add_poly(tree, "Trunk%d" % id, [
		Vector2(-20, 0), Vector2(20, 0), Vector2(16, -180), Vector2(13, -350),
		Vector2(9 + lean, -510), Vector2(5 + lean, -620), Vector2(-7 + lean, -620),
		Vector2(-10, -510), Vector2(-14, -350), Vector2(-17, -180),
	], ink)

	# 單側樹皮亮邊，讓黑幹和更黑的夜色分開。
	var rim := Line2D.new()
	rim.name = "Rim%d" % id
	rim.width = 4.0
	rim.default_color = FOREST_RIM
	rim.points = PackedVector2Array([
		Vector2(-19, -2), Vector2(-16, -180), Vector2(-13, -350),
		Vector2(-7 + lean, -510), Vector2(-4 + lean, -614),
	])
	rim.antialiased = false
	tree.add_child(rim)

func _add_tree_roots(tree: Node2D, id: int, ink: Color, seed: int) -> void:
	_add_poly(tree, "Root%dL" % id, [
		Vector2(-16, 0), Vector2(-72, 0), Vector2(-44, -24), Vector2(-12, -14),
	], ink)
	_add_poly(tree, "Root%dR" % id, [
		Vector2(16, 0), Vector2(68, 0), Vector2(40, -20), Vector2(11, -12),
	], ink)
	var root_offset := -18.0 + float(seed % 3) * 7.0
	_add_poly(tree, "Root%dBack" % id, [
		Vector2(-2, -8), Vector2(root_offset, 0), Vector2(root_offset + 22, 0), Vector2(13, -16),
	], ink)

func _add_tree_limbs(tree: Node2D, id: int, ink: Color, seed: int) -> void:
	# 主幹在 y=-430 附近分叉：左、右兩枝 + 中央主梢，各自再生二級枝。
	var left_spread := 0.58 + float(seed % 3) * 0.05
	var right_spread := 0.52 + float((seed + 1) % 3) * 0.05
	_grow_branch(tree, "Branch%dL" % id, Vector2(-2, -420), -PI * 0.5 - left_spread, 244.0, 23.0, 2, ink, seed)
	_grow_branch(tree, "Branch%dR" % id, Vector2(3, -448), -PI * 0.5 + right_spread, 262.0, 25.0, 2, ink, seed + 9)
	_grow_branch(tree, "Leader%d" % id, Vector2(1, -500), -PI * 0.5 + 0.05, 330.0, 17.0, 2, ink, seed + 21)

func _grow_branch(parent: Node2D, branch_name: String, from: Vector2, angle: float, length: float, width: float, depth: int, ink: Color, seed: int) -> void:
	var to := from + Vector2(cos(angle), sin(angle)) * length
	var bend := sin(float(seed) * 0.9 + length * 0.02) * width * 0.30
	_add_limb(parent, branch_name, from, to, width, maxf(2.5, width * 0.42), bend, ink)

	if depth <= 0:
		_add_tree_leaf(parent, branch_name + "Leaf", to, 20.0 + float(seed % 4) * 3.0, ink)
		return

	var mid := from.lerp(to, 0.54)
	_grow_branch(parent, branch_name + "A", mid, angle - 0.34, length * 0.62, width * 0.52, depth - 1, ink, seed + 3)
	_grow_branch(parent, branch_name + "B", mid, angle + 0.31, length * 0.58, width * 0.50, depth - 1, ink, seed + 7)

func _add_limb(parent: Node2D, node_name: String, from: Vector2, to: Vector2, width_from: float, width_to: float, bend: float, ink: Color) -> void:
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var mid := from.lerp(to, 0.52) + perp * bend
	var width_mid := (width_from + width_to) * 0.42
	_add_poly(parent, node_name, [
		from + perp * width_from * 0.5,
		mid + perp * width_mid * 0.5,
		to + perp * width_to * 0.5,
		to - perp * width_to * 0.5,
		mid - perp * width_mid * 0.5,
		from - perp * width_from * 0.5,
	], ink)

func _add_tree_leaf(parent: Node2D, node_name: String, center: Vector2, radius: float, ink: Color) -> void:
	var leaf_ink := Color(FOREST_INK_2.r, FOREST_INK_2.g, FOREST_INK_2.b, ink.a * 0.84)
	_add_leaf(parent, node_name, center, radius, leaf_ink)

func _add_canopy(parent: Node) -> void:
	# 頂部仍是幾團葉簇，保留 Crown0 的既有節點名；中段樹冠交給 side branches。
	for item in [Vector2(0, 0), Vector2(300, 0), Vector2(1620, 0), Vector2(1920, 0)]:
		var base_x: float = item.x
		for j in range(3):
			var offset := Vector2(float(j - 1) * 46.0 + 12.0, 26.0 + float(j % 2) * 32.0)
			var radius := 26.0 + float((j + int(base_x)) % 3) * 7.0
			var node_name: String = ("Crown%d" % int(base_x)) if j == 0 else ("Crown%dLeaf%d" % [int(base_x), j])
			_add_leaf(parent, node_name, Vector2(base_x, 0) + offset, radius, FOREST_INK_2)

func _add_leaf(parent: Node, node_name: String, center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var r := radius * (0.76 + 0.24 * float((i * 7 + 3) % 5) / 4.0)
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.62))
	_add_poly(parent, node_name, pts, color)

func _add_poly(parent: Node, node_name: String, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)
