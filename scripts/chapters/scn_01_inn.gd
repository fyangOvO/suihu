extends "res://scripts/chapters/stage_base.gd"
## SCN-01 酒肆：B1 三段對話 → 落座 → 三碗下肚 → 燈滅 → 店家尾影 → B2。
## 布景全部程序化（桌、碗、油燈、店家剪影），人物喝酒复用 Drink 四帧。

const ACTION_DATA := preload("res://data/action_frame_data.gd")
const DARK_OUT := Color(0.27, 0.26, 0.24)

var _inn_back: Node2D
var _inn_front: Node2D
var _visual: Sprite2D
var _drink_spec: Dictionary
var _drink_action: String = ""
var _bowls: Array = []
var _lamp_light: PointLight2D
var _lamp_glow: Sprite2D
var _lamp_flame: Polygon2D
var _canvas_mod: CanvasModulate
var _tail_root: Node2D
var _phase: String = ""
var _phase_t: float = 0.0
var _drink_round: int = 0
var _tail_shown: bool = false

func scene_id() -> String:
	return "SCN-01"

func scene_title() -> String:
	return "酒肆"

func first_beat() -> String:
	return "B1"

func background_color() -> Color:
	return Color(0.10, 0.078, 0.062)

func _on_stage_start() -> void:
	if _inn_front == null:
		_build_inn_set()
	if p1 != null:
		p1.z_index = 1
		p1.face_direction = 1.0
		var vis := p1.get_node_or_null("Visual") as Sprite2D
		if vis != null:
			vis.scale.x = absf(vis.scale.x)
	show_banner("景陽岡下，酒肆。", 2.0)
	_say(STORY.lines("B1"), Callable(self, "_after_b1"))

func _after_b1() -> void:
	_begin_inn_cutscene()

# --- 演出狀態機 ---
func _begin_inn_cutscene() -> void:
	_phase = "sit"
	_phase_t = 0.0
	_drink_round = 0
	_tail_shown = false
	if p1 != null:
		p1.set_physics_process(false)
	_seat_p1()

func _seat_p1() -> void:
	_visual = null
	if p1 != null:
		_visual = p1.get_node_or_null("Visual") as Sprite2D
	_drink_spec = ACTION_DATA.spec("Drink")
	if _visual == null:
		_phase = "drink"
		return
	var tw := create_tween()
	tw.tween_property(_visual, "position", Vector2(0.0, -108.0), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tick_stage(delta: float) -> void:
	if _phase == "" or _phase == "done":
		return
	_phase_t += delta
	match _phase:
		"sit":
			if _phase_t >= 0.45:
				if _visual != null:
					_start_drink(0)
				else:
					_begin_lamp_out()
		"drink":
			if _visual != null:
				_visual.play_action(_drink_action, _drink_spec, delta)
			if _phase_t >= 0.82:
				_end_drink()
		"lamp":
			if not _tail_shown and _phase_t >= 0.55:
				_reveal_tail()
			if _phase_t >= 2.15:
				_phase = "done"
				_finish_to("B2", 0.7, "")

func _start_drink(round_index: int) -> void:
	_drink_round = round_index
	_drink_action = "InnDrink%d" % (round_index + 1)
	_phase = "drink"
	_phase_t = 0.0
	if _visual != null:
		_visual.play_action(_drink_action, _drink_spec, 0.0)

func _end_drink() -> void:
	if _drink_round < _bowls.size():
		var bowl: Node2D = _bowls[_drink_round]
		var tw := create_tween()
		tw.tween_property(bowl, "modulate:a", 0.0, 0.25)
	_drink_round += 1
	if _drink_round >= 3:
		_begin_lamp_out()
	else:
		_start_drink(_drink_round)

func _begin_lamp_out() -> void:
	_phase = "lamp"
	_phase_t = 0.0
	show_banner("燈滅了。店家的影子，多了一條尾巴。", 2.2)
	if _lamp_light != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_lamp_light, "energy", 0.0, 0.55)
		if _lamp_glow != null:
			tw.tween_property(_lamp_glow, "modulate:a", 0.0, 0.55)
		if _lamp_flame != null:
			tw.tween_property(_lamp_flame, "modulate:a", 0.0, 0.35)
		if _canvas_mod != null:
			tw.tween_property(_canvas_mod, "color", DARK_OUT, 0.55)

func _reveal_tail() -> void:
	_tail_shown = true
	if _tail_root == null:
		return
	_tail_root.visible = true
	_tail_root.modulate.a = 1.0
	_tail_root.scale = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(_tail_root, "scale", Vector2(1.0, 1.0), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(_tail_root, "modulate:a", 0.0, 0.25)

# --- 布景：全部程序化剪影 ---
func _build_inn_set() -> void:
	_inn_back = Node2D.new()
	_inn_back.name = "InnBack"
	_inn_back.z_index = -1
	add_child(_inn_back)

	_add_rect(_inn_back, "InnWall", 0, 0, 1920, 900, Color(0.10, 0.078, 0.062))
	_add_rect(_inn_back, "InnWallTop", 0, 0, 1920, 250, Color(0.075, 0.056, 0.044))
	_add_rect(_inn_back, "InnFloor", 0, 870, 1920, 210, Color(0.15, 0.11, 0.082))
	# 梁柱
	for x in [250, 880, 1810]:
		_add_rect(_inn_back, "Beam%d" % x, x, 0, 24, 900, Color(0.16, 0.11, 0.078))
	_add_rect(_inn_back, "BeamTop", 0, 92, 1920, 18, Color(0.19, 0.13, 0.09))
	# 窗外冷光
	_add_rect(_inn_back, "Window", 1490, 150, 300, 390, Color(0.12, 0.15, 0.18))
	for i in range(1, 4):
		_add_rect(_inn_back, "WindowV%d" % i, 1490 + i * 75, 150, 6, 390, Color(0.06, 0.075, 0.09))
	for i in range(1, 3):
		_add_rect(_inn_back, "WindowH%d" % i, 1490, 150 + i * 130, 300, 6, Color(0.06, 0.075, 0.09))
	# 店內後牆的暗架
	_add_rect(_inn_back, "Shelf", 300, 360, 420, 10, Color(0.19, 0.13, 0.09))
	_add_rect(_inn_back, "Shelf2", 300, 520, 420, 10, Color(0.17, 0.12, 0.085))

	_inn_front = Node2D.new()
	_inn_front.name = "InnFront"
	_inn_front.z_index = 5
	add_child(_inn_front)

	# 前桌：桌面蓋住武松下盤，形成「落座」
	_add_poly(_inn_front, "InnTable", [
		Vector2(380, 748), Vector2(940, 748), Vector2(975, 790), Vector2(350, 790),
	], Color(0.21, 0.145, 0.095))
	_add_rect(_inn_front, "TableEdge", 355, 787, 620, 12, Color(0.30, 0.21, 0.14))
	_add_rect(_inn_front, "TableLegL", 405, 799, 26, 101, Color(0.13, 0.095, 0.07))
	_add_rect(_inn_front, "TableLegR", 895, 799, 26, 101, Color(0.13, 0.095, 0.07))

	# 三只酒碗：碗身加高、碗沿提亮，酒面留一點暖色反光，960×540 才讀得出三碗
	_bowls.clear()
	for i in range(3):
		_bowls.append(_make_bowl(i, 420.0 + i * 86.0, 748.0))

	# 酒壺
	_add_poly(_inn_front, "WineJug", [
		Vector2(760, 704), Vector2(790, 698), Vector2(800, 724), Vector2(798, 758),
		Vector2(758, 758), Vector2(754, 726),
	], Color(0.17, 0.145, 0.12))
	_add_rect(_inn_front, "JugNeck", 776, 680, 14, 22, Color(0.20, 0.17, 0.14))

	# 後方油燈：燈芯 + 光暈 + 2D 點光
	_lamp_flame = _add_poly(_inn_front, "LampFlame", [
		Vector2(1120, 208), Vector2(1127, 232), Vector2(1120, 252), Vector2(1113, 232),
	], Color(0.95, 0.62, 0.25))
	var cord := Line2D.new()
	cord.name = "LampCord"
	cord.points = PackedVector2Array([Vector2(1120, 0), Vector2(1120, 220)])
	cord.width = 5.0
	cord.default_color = Color(0.10, 0.08, 0.065)
	_inn_front.add_child(cord)
	_add_poly(_inn_front, "LampBody", [
		Vector2(1088, 220), Vector2(1152, 220), Vector2(1138, 263), Vector2(1102, 263),
	], Color(0.22, 0.16, 0.10))

	var glow_tex := _make_radial_texture()
	_lamp_glow = Sprite2D.new()
	_lamp_glow.name = "LampGlow"
	_lamp_glow.texture = glow_tex
	_lamp_glow.position = Vector2(1120, 236)
	_lamp_glow.scale = Vector2(3.0, 3.0)
	_lamp_glow.modulate = Color(1.0, 0.72, 0.38, 0.40)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lamp_glow.material = mat
	_inn_front.add_child(_lamp_glow)

	_lamp_light = PointLight2D.new()
	_lamp_light.name = "LampLight"
	_lamp_light.texture = glow_tex
	_lamp_light.position = Vector2(1120, 236)
	_lamp_light.color = Color(1.0, 0.66, 0.34)
	_lamp_light.energy = 1.25
	_lamp_light.texture_scale = 2.2
	_inn_front.add_child(_lamp_light)

	# 店家剪影：尾影先加入，後畫身體，尾巴才從影後伸出來
	_tail_root = Node2D.new()
	_tail_root.name = "TailRoot"
	_tail_root.position = Vector2(1418, 794)
	_tail_root.visible = false
	var tail_points := PackedVector2Array([
		Vector2(0, 0), Vector2(52, 4), Vector2(104, -6), Vector2(150, -42),
		Vector2(176, -94), Vector2(166, -144), Vector2(144, -176),
	])
	var tail := Line2D.new()
	tail.name = "TailLine"
	tail.points = tail_points
	tail.width = 44.0
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(0.35, 0.82))
	taper.add_point(Vector2(0.70, 0.45))
	taper.add_point(Vector2(1.0, 0.10))
	tail.width_curve = taper
	tail.default_color = Color(0.21, 0.18, 0.145, 1.0)
	tail.joint_mode = Line2D.LINE_JOINT_ROUND
	_tail_root.add_child(tail)
	var tail_rim := Line2D.new()
	tail_rim.name = "TailRim"
	tail_rim.points = PackedVector2Array([
		Vector2(0, -18), Vector2(52, -13), Vector2(104, -23), Vector2(150, -59),
		Vector2(176, -111), Vector2(166, -161), Vector2(144, -193),
	])
	tail_rim.width = 6.0
	var rim_taper := Curve.new()
	rim_taper.add_point(Vector2(0.0, 1.0))
	rim_taper.add_point(Vector2(0.45, 0.75))
	rim_taper.add_point(Vector2(1.0, 0.10))
	tail_rim.width_curve = rim_taper
	tail_rim.default_color = Color(0.62, 0.50, 0.35, 0.45)
	tail_rim.joint_mode = Line2D.LINE_JOINT_ROUND
	_tail_root.add_child(tail_rim)
	_inn_front.add_child(_tail_root)

	_add_rect(_inn_front, "ShopkeeperNeck", 1346, 642, 28, 46, Color(0.130, 0.110, 0.090))
	_add_poly(_inn_front, "ShopkeeperShadow", [
		Vector2(1288, 682), Vector2(1318, 650), Vector2(1352, 642), Vector2(1388, 650),
		Vector2(1416, 682), Vector2(1445, 868), Vector2(1268, 868),
	], Color(0.140, 0.120, 0.095))
	var head := _add_poly(_inn_front, "ShopkeeperHead", [
		Vector2(1332, 596), Vector2(1360, 584), Vector2(1388, 596), Vector2(1396, 626),
		Vector2(1382, 652), Vector2(1338, 652), Vector2(1324, 626),
	], Color(0.130, 0.110, 0.090))
	head.z_index = 0
	_add_poly(_inn_front, "ShopkeeperTopknot", [
		Vector2(1352, 584), Vector2(1362, 570), Vector2(1372, 584),
	], Color(0.130, 0.110, 0.090))
	var shop_rim := Line2D.new()
	shop_rim.name = "ShopkeeperRim"
	shop_rim.points = PackedVector2Array([
		Vector2(1324, 626), Vector2(1332, 596), Vector2(1360, 584),
		Vector2(1388, 596), Vector2(1396, 626), Vector2(1382, 652),
		Vector2(1416, 682), Vector2(1445, 868),
	])
	shop_rim.width = 3.0
	shop_rim.default_color = Color(0.46, 0.38, 0.29, 0.30)
	shop_rim.joint_mode = Line2D.LINE_JOINT_ROUND
	_inn_front.add_child(shop_rim)

	_canvas_mod = CanvasModulate.new()
	_canvas_mod.name = "InnCanvasModulate"
	_canvas_mod.color = Color.WHITE
	add_child(_canvas_mod)

func _make_bowl(index: int, x: float, y: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Bowl%d" % (index + 1)
	root.position = Vector2(x, y)
	_inn_front.add_child(root)
	var body := Polygon2D.new()
	body.name = "BowlBody"
	body.polygon = PackedVector2Array([
		Vector2(-30, 0), Vector2(30, 0), Vector2(21, 24), Vector2(-21, 24),
	])
	body.color = Color(0.115, 0.095, 0.075)
	root.add_child(body)
	var belly := Polygon2D.new()
	belly.name = "BowlBelly"
	belly.polygon = PackedVector2Array([
		Vector2(-23, 5), Vector2(23, 5), Vector2(17, 21), Vector2(-17, 21),
	])
	belly.color = Color(0.175, 0.145, 0.110)
	root.add_child(belly)
	var rim := Polygon2D.new()
	rim.name = "BowlRim"
	rim.polygon = PackedVector2Array([
		Vector2(-33, -4), Vector2(33, -4), Vector2(27, 6), Vector2(-27, 6),
	])
	rim.color = Color(0.62, 0.55, 0.42)
	root.add_child(rim)
	var wine := Polygon2D.new()
	wine.name = "BowlWine"
	wine.polygon = PackedVector2Array([
		Vector2(-25, -1), Vector2(25, -1), Vector2(20, 4), Vector2(-20, 4),
	])
	wine.color = Color(0.46, 0.245, 0.085)
	root.add_child(wine)
	var glint := Polygon2D.new()
	glint.name = "BowlWineGlint"
	glint.polygon = PackedVector2Array([
		Vector2(-17, -1), Vector2(-6, -2), Vector2(2, 0), Vector2(-9, 1),
	])
	glint.color = Color(1.0, 0.73, 0.38, 0.55)
	root.add_child(glint)
	return root

func _add_rect(parent: Node2D, node_name: String, x: float, y: float, w: float, h: float, color: Color) -> Polygon2D:
	return _add_poly(parent, node_name, [
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
	], color)

func _add_poly(parent: Node2D, node_name: String, points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	parent.add_child(poly)
	return poly

func _make_radial_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1, 0.88, 0.62, 0.95), Color(1, 0.62, 0.25, 0.45), Color(1, 0.40, 0.12, 0.0),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
