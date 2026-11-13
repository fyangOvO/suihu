extends "res://scripts/chapters/stage_base.gd"
## SCN-04 山神廟：B4 山神問路，存檔後上山。
## 庙內道具全部程序化搭建；燭火與山神像的眨眼是一次性彩蛋。

const STONE := Color(0.13, 0.115, 0.095)
const STONE_DARK := Color(0.075, 0.062, 0.052)
const CLOTH := Color(0.38, 0.075, 0.065)
const CANDLE := Color(0.88, 0.66, 0.30)
const FLAME := Color(1.0, 0.46, 0.06)
const GOLD := Color(0.66, 0.50, 0.26)

var _idol_eyes: Array[ColorRect] = []
var _eye_glows: Array[Sprite2D] = []
var _blink_spark: Sprite2D
var _flames: Array[Polygon2D] = []
var _candle_glows: Array[Sprite2D] = []
var _blink_count: int = 0
var _blink_active: bool = false
var _blink_t: float = 0.0
var _burning: bool = false

func scene_id() -> String:
	return "SCN-04"

func scene_title() -> String:
	return "山神廟"

func first_beat() -> String:
	return "B4"

func background_color() -> Color:
	return Color(0.085, 0.072, 0.065)

func _on_stage_start() -> void:
	_build_temple()
	show_banner("山神廟。燭火壓得很低。", 2.0)
	_say(STORY.lines("B4"), Callable(self, "_after_b4"))

func _after_b4() -> void:
	_blink_once()
	_cm().mark_clear("B4")
	var ok: bool = _cm().save_checkpoint("B4", p1.current_hp)
	if ok:
		show_banner("已於山神廟存檔。", 1.8)
	else:
		show_banner("存檔失敗：%s" % _cm().last_checkpoint_error, 2.2)
	await get_tree().create_timer(1.8).timeout
	_cm().goto_beat("B5")

func _tick_stage(delta: float) -> void:
	_update_flicker()
	_update_blink(delta)
	if not _burning:
		return
	for eye in _idol_eyes:
		if is_instance_valid(eye):
			eye.modulate.a = 0.82 + sin(Time.get_ticks_msec() * 0.004) * 0.12

func _update_flicker() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_flames.size()):
		var flame := _flames[i]
		if not is_instance_valid(flame):
			continue
		flame.modulate.a = 0.90 + sin(t * 8.7 + i * 1.9) * 0.07 + sin(t * 19.0 + i * 0.7) * 0.03
	for i in range(_candle_glows.size()):
		var glow := _candle_glows[i]
		if not is_instance_valid(glow):
			continue
		var base_alpha: float = float(glow.get_meta("base_alpha", 0.0))
		glow.modulate.a = base_alpha * (0.92 + sin(t * 6.1 + i * 2.3) * 0.06)

func _update_blink(delta: float) -> void:
	if not _blink_active:
		return
	_blink_t += delta
	var open_amount := 1.0
	if _blink_t <= 0.10:
		open_amount = 1.0 - 0.90 * (_blink_t / 0.10)
	elif _blink_t <= 0.26:
		open_amount = 0.10 + 0.90 * ((_blink_t - 0.10) / 0.16)
	else:
		_blink_active = false
		open_amount = 1.0
	for eye in _idol_eyes:
		if is_instance_valid(eye):
			eye.scale.y = open_amount
	for glow in _eye_glows:
		if is_instance_valid(glow):
			var base_alpha: float = float(glow.get_meta("base_alpha", 0.0))
			glow.modulate.a = base_alpha * (0.38 + 0.62 * open_amount)
	if is_instance_valid(_blink_spark):
		if _blink_active:
			_blink_spark.modulate.a = sin(clampf(_blink_t / 0.26, 0.0, 1.0) * PI) * 0.30
		else:
			_blink_spark.modulate.a = 0.0

func _build_temple() -> void:
	var bg := get_node_or_null("Background")
	if bg == null or bg.get_node_or_null("TempleProps") != null:
		return
	var props := Node2D.new()
	props.name = "TempleProps"
	bg.add_child(props)

	# 地面與牆：中央留出一條進門的路。
	_rect(props, "Floor", 0, 870, 1920, 210, STONE_DARK)
	_rect(props, "BackWall", 0, 0, 1920, 900, Color(0.080, 0.065, 0.055, 0.92))
	for x in [120, 1780]:
		_poly(props, "Pillar%d" % x, [
			Vector2(x - 34, 0), Vector2(x + 34, 0),
			Vector2(x + 30, 870), Vector2(x - 30, 870),
		], STONE)
	# 廟門：中央偏左，讓玩家像剛從外頭進來。
	_poly(props, "Door", [
		Vector2(620, 180), Vector2(1080, 180), Vector2(1098, 870), Vector2(602, 870),
	], Color(0.028, 0.032, 0.040, 0.95))
	_poly(props, "DoorLight", [
		Vector2(690, 260), Vector2(1010, 260), Vector2(1000, 870), Vector2(700, 870),
	], Color(0.10, 0.09, 0.075, 0.52))

	# 供桌與香爐。
	_rect(props, "Altar", 300, 650, 520, 34, STONE)
	_rect(props, "AltarEdge", 286, 642, 548, 10, Color(0.17, 0.17, 0.18))
	_rect(props, "AltarCloth", 330, 682, 460, 88, CLOTH)
	# 香爐：壓在供桌中段，三炷香從爐口插出，讓桌面不是一塊空紅布。
	_poly(props, "Censer", [
		Vector2(392, 606), Vector2(640, 606), Vector2(624, 644), Vector2(408, 644),
	], Color(0.145, 0.115, 0.080))
	_poly(props, "CenserRim", [
		Vector2(386, 602), Vector2(646, 602), Vector2(640, 610), Vector2(392, 610),
	], Color(0.34, 0.25, 0.14))
	_poly(props, "CenserFootL", [
		Vector2(438, 642), Vector2(456, 642), Vector2(452, 656), Vector2(440, 656),
	], Color(0.105, 0.085, 0.065))
	_poly(props, "CenserFootR", [
		Vector2(576, 642), Vector2(594, 642), Vector2(590, 656), Vector2(578, 656),
	], Color(0.105, 0.085, 0.065))
	for x in [390, 516, 642]:
		_poly(props, "Incense%d" % x, [
			Vector2(x, 626), Vector2(x + 2, 540), Vector2(x + 4, 626),
		], Color(0.30, 0.26, 0.20, 0.55))
		var smoke := Line2D.new()
		smoke.name = "IncenseSmoke%d" % x
		smoke.points = PackedVector2Array([
			Vector2(x + 3, 540), Vector2(x - 8, 500), Vector2(x + 12, 464),
			Vector2(x - 4, 424),
		])
		smoke.width = 1.5
		smoke.default_color = Color(0.55, 0.48, 0.38, 0.22)
		props.add_child(smoke)

	# 兩支燭：燭身＋焰＋暖光斑。右側燭移到山神像外，避免被神像遮住。
	for x in [360, 980]:
		_rect(props, "Candle%d" % x, x, 560, 18, 92, CANDLE)
		var flame: Polygon2D = _poly(props, "Flame%d" % x, [
			Vector2(x + 9, 524), Vector2(x + 17, 548), Vector2(x + 9, 562), Vector2(x + 1, 548),
		], FLAME)
		_flames.append(flame)
		_poly(props, "FlameCore%d" % x, [
			Vector2(x + 9, 532), Vector2(x + 14, 548), Vector2(x + 9, 556), Vector2(x + 4, 548),
		], Color(1.0, 0.88, 0.55, 0.95))
		var glow := _add_glow(props, "FlameGlow%d" % x, Vector2(x + 9, 542), 54, 38, Color(1, 0.62, 0.20, 0.68))
		var halo := _add_glow(props, "CandleGlow%d" % x, Vector2(x + 9, 548), 150, 104, Color(1, 0.50, 0.16, 0.70))
		var wide := _add_glow(props, "CandleHalo%d" % x, Vector2(x + 9, 548), 300, 210, Color(1, 0.38, 0.12, 0.28))
		var pool := _add_glow(props, "CandlePool%d" % x, Vector2(x + 9, 650), 280, 110, Color(1, 0.33, 0.10, 0.26))
		for light in [glow, halo, wide, pool]:
			light.set_meta("base_alpha", light.modulate.a)
			_candle_glows.append(light)
	_burning = true

	# 供桌的暖光：把整塊祭台從背景裡拉出來，也让山神像的輪廓有光。
	_add_glow(props, "AltarLight", Vector2(510, 690), 420, 240, Color(1.0, 0.54, 0.20, 0.58))
	_add_glow(props, "AltarFrontLight", Vector2(510, 730), 360, 150, Color(1.0, 0.36, 0.10, 0.26))
	_add_glow(props, "FloorLight", Vector2(520, 820), 640, 240, Color(1.0, 0.45, 0.16, 0.20))
	_add_glow(props, "TempleWash", Vector2(700, 560), 900, 600, Color(1.0, 0.42, 0.14, 0.11))
	_add_glow(props, "IdolHalo", Vector2(700, 470), 470, 320, Color(1.0, 0.52, 0.20, 0.32))
	_add_glow(props, "CenserGlow", Vector2(516, 612), 150, 72, Color(1.0, 0.58, 0.22, 0.24))
	for x in [390, 516, 642]:
		_add_glow(props, "IncenseGlow%d" % x, Vector2(x, 600), 60, 48, Color(1.0, 0.48, 0.16, 0.16))
	_glow_poly(props, "AltarGoldEdge", [
		Vector2(286, 642), Vector2(834, 642), Vector2(830, 648), Vector2(290, 648),
	], Color(0.92, 0.64, 0.28, 0.32))

	# 山神像：坐在供桌後方；眼睛是兩塊金片，眨眼彩蛋會把它們壓成一線。
	_poly(props, "IdolBody", [
		Vector2(560, 470), Vector2(860, 470), Vector2(940, 680), Vector2(470, 680),
	], Color(0.10, 0.09, 0.075))
	_poly(props, "IdolRobe", [
		Vector2(580, 500), Vector2(840, 500), Vector2(900, 660), Vector2(520, 660),
	], Color(0.15, 0.12, 0.095))
	_poly(props, "IdolFace", [
		Vector2(610, 360), Vector2(810, 360), Vector2(830, 474), Vector2(590, 474),
	], Color(0.19, 0.17, 0.135))
	_poly(props, "IdolBrowL", [
		Vector2(640, 392), Vector2(690, 396), Vector2(688, 404), Vector2(644, 400),
	], Color(0.075, 0.062, 0.050))
	_poly(props, "IdolBrowR", [
		Vector2(730, 396), Vector2(780, 392), Vector2(776, 400), Vector2(732, 404),
	], Color(0.075, 0.062, 0.050))
	_poly(props, "IdolNose", [
		Vector2(692, 404), Vector2(718, 404), Vector2(724, 454), Vector2(686, 454),
	], Color(0.175, 0.155, 0.123))
	_poly(props, "IdolNoseShadow", [
		Vector2(692, 424), Vector2(702, 424), Vector2(702, 458), Vector2(688, 454),
	], Color(0.105, 0.088, 0.070))
	_poly(props, "IdolCheekL", [
		Vector2(612, 426), Vector2(662, 434), Vector2(658, 466), Vector2(616, 462),
	], Color(0.178, 0.157, 0.124, 0.65))
	_poly(props, "IdolCheekR", [
		Vector2(758, 434), Vector2(808, 426), Vector2(804, 462), Vector2(762, 466),
	], Color(0.170, 0.150, 0.118, 0.55))
	_poly(props, "IdolMouth", [
		Vector2(686, 462), Vector2(734, 462), Vector2(728, 470), Vector2(692, 470),
	], Color(0.080, 0.065, 0.052))
	_poly(props, "IdolForeheadMark", [
		Vector2(704, 382), Vector2(714, 368), Vector2(726, 382), Vector2(716, 396),
	], Color(0.43, 0.33, 0.16, 0.72))
	_poly(props, "IdolBeard", [
		Vector2(650, 456), Vector2(770, 456), Vector2(740, 560), Vector2(680, 560),
	], Color(0.075, 0.065, 0.055))
	for x in [668, 752]:
		var socket_name := "IdolSocket%s" % ("L" if x < 700 else "R")
		_rect(props, socket_name, x - 5, 406, 32, 20, Color(0.045, 0.038, 0.032))
		var eye := ColorRect.new()
		eye.name = "IdolEye%s" % ("L" if x < 700 else "R")
		eye.position = Vector2(x, 412)
		eye.size = Vector2(22, 8)
		eye.pivot_offset = Vector2(11, 4)
		eye.color = GOLD
		props.add_child(eye)
		_idol_eyes.append(eye)
		var eye_glow := _add_glow(props, "IdolEyeGlow%s" % ("L" if x < 700 else "R"), Vector2(x + 11, 416), 38, 22, Color(1.0, 0.58, 0.18, 0.32))
		eye_glow.set_meta("base_alpha", eye_glow.modulate.a)
		_eye_glows.append(eye_glow)
	# 山神頭上的殘金冠與兩側垂帶。
	_poly(props, "IdolCrown", [
		Vector2(624, 352), Vector2(796, 352), Vector2(780, 382), Vector2(640, 382),
	], Color(0.28, 0.22, 0.12))
	for x in [548, 852]:
		_rect(props, "TempleBanner%d" % x, x, 260, 18, 300, CLOTH)
	# 山神臉上的暖光，只到額頭與鼻樑，不把整張臉照平。
	_add_glow(props, "IdolFaceWarm", Vector2(710, 432), 230, 132, Color(1.0, 0.60, 0.24, 0.35))
	_add_glow(props, "IdolWarm", Vector2(710, 420), 180, 96, Color(1.0, 0.64, 0.28, 0.75))
	_glow_poly(props, "IdolRimL", [
		Vector2(608, 372), Vector2(618, 372), Vector2(600, 476), Vector2(588, 476),
	], Color(1.0, 0.62, 0.24, 0.26))
	_glow_poly(props, "IdolRimR", [
		Vector2(802, 372), Vector2(812, 372), Vector2(832, 476), Vector2(820, 476),
	], Color(1.0, 0.56, 0.20, 0.18))
	_glow_poly(props, "IdolCrownEdge", [
		Vector2(624, 352), Vector2(796, 352), Vector2(794, 358), Vector2(626, 358),
	], Color(0.95, 0.68, 0.30, 0.28))
	_blink_spark = _add_glow(props, "BlinkSpark", Vector2(710, 416), 210, 18, Color(1.0, 0.72, 0.28, 0.0))

func _blink_once() -> void:
	if _blink_count > 0:
		return
	_blink_count += 1
	_blink_active = true
	_blink_t = 0.0
	for eye in _idol_eyes:
		if is_instance_valid(eye):
			eye.scale.y = 1.0

func _rect(parent: Node2D, node_name: String, x: float, y: float, w: float, h: float, color: Color) -> void:
	_poly(parent, node_name, [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], color)

func _poly(parent: Node2D, node_name: String, points: Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)
	return p

func _glow_poly(parent: Node2D, node_name: String, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)

func _add_glow(parent: Node2D, node_name: String, center: Vector2, rx: float, ry: float, color: Color) -> Sprite2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.46, Color(1, 1, 1, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var spr := Sprite2D.new()
	spr.name = node_name
	spr.texture = tex
	spr.position = center
	spr.scale = Vector2(rx / 64.0, ry / 64.0)
	spr.modulate = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	parent.add_child(spr)
	return spr

func _ellipse_points(center: Vector2, rx: float, ry: float) -> Array:
	var pts: Array = []
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
