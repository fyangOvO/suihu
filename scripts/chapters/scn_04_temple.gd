extends "res://scripts/chapters/stage_base.gd"
## SCN-04 山神廟：B4 山神問路，存檔後上山。
## 庙內道具全部程序化搭建；燭火與山神像的眨眼是一次性彩蛋。

const STONE := Color(0.105, 0.110, 0.125)
const STONE_DARK := Color(0.055, 0.060, 0.072)
const CLOTH := Color(0.28, 0.055, 0.050)
const CANDLE := Color(0.68, 0.50, 0.24)
const FLAME := Color(0.98, 0.66, 0.28)
const GOLD := Color(0.66, 0.50, 0.26)

var _idol_eyes: Array[ColorRect] = []
var _blink_count: int = 0
var _burning: bool = false

func scene_id() -> String:
	return "SCN-04"

func scene_title() -> String:
	return "山神廟"

func first_beat() -> String:
	return "B4"

func background_color() -> Color:
	return Color(0.055, 0.06, 0.075)

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

func _tick_stage(_delta: float) -> void:
	if not _burning:
		return
	for eye in _idol_eyes:
		if is_instance_valid(eye):
			eye.modulate.a = 0.82 + sin(Time.get_ticks_msec() * 0.004) * 0.12

func _build_temple() -> void:
	var bg := get_node_or_null("Background")
	if bg == null or bg.get_node_or_null("TempleProps") != null:
		return
	var props := Node2D.new()
	props.name = "TempleProps"
	bg.add_child(props)

	# 地面與牆：中央留出一條進門的路。
	_rect(props, "Floor", 0, 870, 1920, 210, STONE_DARK)
	_rect(props, "BackWall", 0, 0, 1920, 900, Color(0.045, 0.050, 0.062, 0.92))
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
	for x in [390, 516, 642]:
		_poly(props, "Incense%d" % x, [
			Vector2(x, 626), Vector2(x + 2, 540), Vector2(x + 4, 626),
		], Color(0.30, 0.26, 0.20, 0.55))

	# 兩支燭：燭身＋焰＋暖光斑。
	for x in [360, 760]:
		_rect(props, "Candle%d" % x, x, 560, 18, 92, CANDLE)
		_poly(props, "Flame%d" % x, [
			Vector2(x + 9, 524), Vector2(x + 17, 548), Vector2(x + 9, 562), Vector2(x + 1, 548),
		], FLAME)
		_poly(props, "CandleGlow%d" % x, _ellipse_points(Vector2(x + 9, 548), 84, 58), Color(1, 0.55, 0.22, 0.10))
	_burning = true

	# 山神像：坐在供桌後方；眼睛是兩塊金片，眨眼彩蛋會把它們壓成一線。
	_poly(props, "IdolBody", [
		Vector2(560, 470), Vector2(860, 470), Vector2(940, 680), Vector2(470, 680),
	], Color(0.075, 0.080, 0.090))
	_poly(props, "IdolRobe", [
		Vector2(580, 500), Vector2(840, 500), Vector2(900, 660), Vector2(520, 660),
	], Color(0.12, 0.10, 0.085))
	_poly(props, "IdolFace", [
		Vector2(610, 360), Vector2(810, 360), Vector2(830, 474), Vector2(590, 474),
	], Color(0.16, 0.145, 0.115))
	_poly(props, "IdolBeard", [
		Vector2(650, 456), Vector2(770, 456), Vector2(740, 560), Vector2(680, 560),
	], Color(0.075, 0.065, 0.055))
	for x in [668, 752]:
		var eye := ColorRect.new()
		eye.name = "IdolEye%s" % ("L" if x < 700 else "R")
		eye.position = Vector2(x, 412)
		eye.size = Vector2(22, 8)
		eye.color = GOLD
		props.add_child(eye)
		_idol_eyes.append(eye)
	# 山神頭上的殘金冠與兩側垂帶。
	_poly(props, "IdolCrown", [
		Vector2(624, 352), Vector2(796, 352), Vector2(780, 382), Vector2(640, 382),
	], Color(0.28, 0.22, 0.12))
	for x in [548, 852]:
		_rect(props, "TempleBanner%d" % x, x, 260, 18, 300, CLOTH)

func _blink_once() -> void:
	if _blink_count > 0:
		return
	_blink_count += 1
	for eye in _idol_eyes:
		if not is_instance_valid(eye):
			continue
		var tw := create_tween()
		tw.tween_property(eye, "scale:y", 0.10, 0.10)
		tw.tween_property(eye, "scale:y", 1.0, 0.16)

func _rect(parent: Node2D, node_name: String, x: float, y: float, w: float, h: float, color: Color) -> void:
	_poly(parent, node_name, [Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], color)

func _poly(parent: Node2D, node_name: String, points: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)

func _ellipse_points(center: Vector2, rx: float, ry: float) -> Array:
	var pts: Array = []
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
