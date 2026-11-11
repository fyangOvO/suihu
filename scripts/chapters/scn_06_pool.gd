extends "res://scripts/chapters/stage_base.gd"
## SCN-06 水潭：B8 倒影字幕 → B9 下山 → 章末結算 → 主菜單／重開。
## 水面倒影與岸邊虎屍剪影是本章最後的兩個視覺落點。

const WATER_Y := 900.0
const MOON_X := 960.0

var _ripples: Array[Polygon2D] = []
var _ripple_phases: Array[float] = []
var _tiger_parts: Array[Polygon2D] = []

func scene_id() -> String:
	return "SCN-06"

func scene_title() -> String:
	return "水潭"

func first_beat() -> String:
	return "B8"

func background_color() -> Color:
	return Color(0.035, 0.05, 0.075)

func _on_stage_start() -> void:
	_build_water()
	if _cm().current_beat == "B9":
		_play_ending()
	else:
		_say(STORY.lines("B8"), Callable(self, "_after_b8"))

func _tick_stage(_delta: float) -> void:
	for i in range(_ripples.size()):
		if not is_instance_valid(_ripples[i]):
			continue
		_ripple_phases[i] += _delta * (0.7 + float(i) * 0.12)
		var s := 1.0 + sin(_ripple_phases[i]) * 0.18
		_ripples[i].scale.x = s
		_ripples[i].modulate.a = 0.10 + sin(_ripple_phases[i] * 1.4) * 0.04

func _build_water() -> void:
	var bg := get_node_or_null("Background")
	var parent: Node = bg if bg != null else self
	if parent.get_node_or_null("Water") != null:
		return

	var glow := _disc(Vector2(MOON_X, 220), 118.0, Color(0.42, 0.50, 0.56, 0.06))
	glow.name = "MoonGlow"
	parent.add_child(glow)
	var moon := _disc(Vector2(MOON_X, 220), 82.0, Color(0.88, 0.92, 0.96, 0.82))
	moon.name = "Moon"
	parent.add_child(moon)

	var water := ColorRect.new()
	water.name = "Water"
	water.position = Vector2(0, WATER_Y)
	water.size = Vector2(1920, 180)
	water.color = Color(0.045, 0.075, 0.105, 1)
	parent.add_child(water)

	# 月影：水面上一串壓扁的冷色橢圓，越遠越窄。
	for i in range(7):
		var ry := 3.0 + float(i) * 1.2
		var rx := 58.0 - float(i) * 4.0
		var strip := _ellipse(Vector2(MOON_X, WATER_Y + 14.0 + float(i) * 12.0), rx, ry, Color(0.62, 0.76, 0.84, 0.14))
		strip.name = "MoonReflection%d" % i
		parent.add_child(strip)
		_ripples.append(strip)
		_ripple_phases.append(float(i) * 0.7)

	_add_night_bank(parent)
	_build_tiger_corpse(parent)
	_add_reflection(parent)

func _build_tiger_corpse(parent: Node) -> void:
	# 右岸石台：把虎屍抬高到對話框之上，剪影才看得見。
	var ledge := _poly(parent, "CorpseLedge", [
		Vector2(1350, 700), Vector2(1760, 700), Vector2(1800, 760),
		Vector2(1320, 760),
	], Color(0.095, 0.105, 0.098, 0.98))
	ledge.name = "CorpseLedge"
	var ledge_edge := Line2D.new()
	ledge_edge.name = "CorpseLedgeEdge"
	ledge_edge.points = PackedVector2Array([Vector2(1352, 701), Vector2(1762, 701)])
	ledge_edge.width = 2.0
	ledge_edge.default_color = Color(0.34, 0.38, 0.34, 0.45)
	parent.add_child(ledge_edge)
	var body: Array = [
		Vector2(0, -20), Vector2(92, -48), Vector2(178, -40),
		Vector2(226, -18), Vector2(248, 16), Vector2(218, 44),
		Vector2(142, 56), Vector2(62, 48), Vector2(8, 22),
	]
	var head: Array = [
		Vector2(218, -40), Vector2(252, -58), Vector2(286, -42),
		Vector2(294, -18), Vector2(272, 6), Vector2(238, 4), Vector2(214, -14),
	]
	var tail: Array = [
		Vector2(0, 6), Vector2(-46, 22), Vector2(-82, 48),
		Vector2(-78, 58), Vector2(-38, 40), Vector2(4, 20),
	]
	var parts: Array = [
		["TigerBody", body], ["TigerHead", head], ["TigerTail", tail],
	]
	for item in parts:
		var p := _poly(parent, item[0], item[1], Color(0.10, 0.095, 0.082, 0.98))
		p.position = Vector2(1450, 660)
		_tiger_parts.append(p)
	# 虎斑：只留幾道暗赭，遠看是剪影，近看能認出虎。
	for stripe in [Vector2(60, -24), Vector2(104, -32), Vector2(150, -28), Vector2(190, -24)]:
		var s := _poly(parent, "TigerStripe%d" % int(stripe.x), [
			stripe, stripe + Vector2(10, -8), stripe + Vector2(18, 2), stripe + Vector2(6, 6),
		], Color(0.24, 0.13, 0.075, 0.55))
		s.position = Vector2(1450, 660)
		_tiger_parts.append(s)
	# 月照在虎背上的冷邊，讓黑剪影不至於糊進夜色。
	var rim := Line2D.new()
	rim.name = "TigerRim"
	rim.points = PackedVector2Array([
		Vector2(2, -18), Vector2(90, -45), Vector2(176, -37),
		Vector2(224, -15), Vector2(246, 15),
	])
	rim.width = 3.5
	rim.default_color = Color(0.50, 0.52, 0.45, 0.68)
	rim.position = Vector2(1450, 660)
	parent.add_child(rim)

	# 脊線：從尾根一路接到肩胛，讓虎屍不再只是大塊暗影。
	var spine := Line2D.new()
	spine.name = "TigerSpine"
	spine.points = PackedVector2Array([
		Vector2(12, -18), Vector2(62, -31), Vector2(116, -38),
		Vector2(172, -31), Vector2(216, -12),
	])
	spine.width = 4.0
	spine.default_color = Color(0.46, 0.40, 0.30, 0.64)
	spine.position = Vector2(1450, 660)
	parent.add_child(spine)

	# 腹線與胯部：把軀幹和四肢分開，避免腿和身體糊成一團。
	var belly := Line2D.new()
	belly.name = "TigerBelly"
	belly.points = PackedVector2Array([
		Vector2(18, 22), Vector2(72, 38), Vector2(132, 44),
		Vector2(190, 34), Vector2(226, 12),
	])
	belly.width = 2.0
	belly.default_color = Color(0.30, 0.26, 0.20, 0.42)
	belly.position = Vector2(1450, 660)
	parent.add_child(belly)
	var haunch := Line2D.new()
	haunch.name = "TigerHaunch"
	haunch.points = PackedVector2Array([Vector2(154, -6), Vector2(186, 16), Vector2(176, 42)])
	haunch.width = 2.0
	haunch.default_color = Color(0.28, 0.25, 0.19, 0.38)
	haunch.position = Vector2(1450, 660)
	parent.add_child(haunch)

	# 頭部：耳朵、閉眼與吻部；剪影靠這三個缺口讀成虎。
	for ear in [Vector2(236, -54), Vector2(278, -50)]:
		var ear_poly := _poly(parent, "TigerEar%d" % int(ear.x), [
			ear, ear + Vector2(14, -20), ear + Vector2(24, 2),
		], Color(0.11, 0.10, 0.085, 0.98))
		ear_poly.position = Vector2(1450, 660)
	var muzzle := _poly(parent, "TigerMuzzle", [
		Vector2(274, -10), Vector2(296, -8), Vector2(292, 4),
		Vector2(272, 6),
	], Color(0.14, 0.12, 0.095, 0.95))
	muzzle.position = Vector2(1450, 660)
	var eye := Line2D.new()
	eye.name = "TigerClosedEye"
	eye.points = PackedVector2Array([Vector2(258, -28), Vector2(270, -26)])
	eye.width = 2.0
	eye.default_color = Color(0.62, 0.56, 0.44, 0.42)
	eye.position = Vector2(1450, 660)
	parent.add_child(eye)

	# 四肢：重畫成四條有膝節的腿，腳掌用略亮的小塊收尾。
	var legs := [
		Vector2(42, 36), Vector2(108, 44), Vector2(166, 38), Vector2(202, 30),
	]
	for leg in legs:
		var leg_poly := _poly(parent, "TigerLeg%d" % int(leg.x), [
			leg, leg + Vector2(9, 30), leg + Vector2(18, 43),
			leg + Vector2(30, 46), leg + Vector2(28, 54),
			leg + Vector2(12, 52), leg + Vector2(4, 36),
		], Color(0.13, 0.115, 0.095, 0.98))
		leg_poly.position = Vector2(1450, 660)
		var paw := _poly(parent, "TigerPaw%d" % int(leg.x), [
			leg + Vector2(12, 52), leg + Vector2(30, 55),
			leg + Vector2(32, 62), leg + Vector2(10, 60),
		], Color(0.22, 0.19, 0.15, 0.96))
		paw.position = Vector2(1450, 660)
		var knee := Line2D.new()
		knee.name = "TigerKnee%d" % int(leg.x)
		knee.points = PackedVector2Array([leg + Vector2(8, 22), leg + Vector2(17, 34)])
		knee.width = 1.5
		knee.default_color = Color(0.30, 0.26, 0.20, 0.40)
		knee.position = Vector2(1450, 660)
		parent.add_child(knee)

	# 地面的接觸陰影，讓虎屍真的壓在石台上。
	var shadow := _ellipse(Vector2(1450, 704), 190, 18, Color(0, 0, 0, 0.42))
	shadow.name = "TigerShadow"
	parent.add_child(shadow)
	parent.move_child(shadow, 0)

func _add_night_bank(parent: Node) -> void:
	# 水岸與稀疏星點：把純黑的上半畫面分出「岸」與「夜」。
	var left_bank := _poly(parent, "BankLeft", [
		Vector2(0, 820), Vector2(250, 820), Vector2(310, 900), Vector2(0, 900),
	], Color(0.070, 0.078, 0.072, 0.95))
	var right_bank := _poly(parent, "BankRight", [
		Vector2(1620, 820), Vector2(1920, 820), Vector2(1920, 900), Vector2(1560, 900),
	], Color(0.070, 0.078, 0.072, 0.95))
	for p in [left_bank, right_bank]:
		(p as Polygon2D).z_index = 0
	for item in [Vector2(160, 860), Vector2(212, 848), Vector2(1740, 850), Vector2(1810, 868)]:
		var reed := _poly(parent, "Reed%d" % int(item.x), [
			Vector2(item.x, 880), Vector2(item.x + 2, 760), Vector2(item.x + 5, 880),
		], Color(0.10, 0.14, 0.11, 0.55))
		reed.z_index = 0
	for star in [Vector2(340, 100), Vector2(520, 70), Vector2(1220, 90),
			Vector2(1450, 50), Vector2(1680, 120), Vector2(1810, 70)]:
		var dot := _disc(star, 1.4, Color(0.72, 0.78, 0.82, 0.22))
		parent.add_child(dot)

func _add_reflection(parent: Node) -> void:
	# 虎屍在水面的倒影：把 y 以水線鏡像，降低 alpha 並稍微壓扁。
	var mirror := Node2D.new()
	mirror.name = "TigerReflection"
	mirror.position = Vector2(1450, 960)
	mirror.scale = Vector2(1.0, -0.30)
	parent.add_child(mirror)
	var body: Array = [
		Vector2(0, -20), Vector2(92, -48), Vector2(178, -40),
		Vector2(226, -18), Vector2(248, 16), Vector2(218, 44),
		Vector2(142, 56), Vector2(62, 48), Vector2(8, 22),
	]
	var head: Array = [
		Vector2(218, -40), Vector2(252, -58), Vector2(286, -42),
		Vector2(294, -18), Vector2(272, 6), Vector2(238, 4), Vector2(214, -14),
	]
	var tail: Array = [
		Vector2(0, 6), Vector2(-46, 22), Vector2(-82, 48),
		Vector2(-78, 58), Vector2(-38, 40), Vector2(4, 20),
	]
	for item in [["RBody", body], ["RHead", head], ["RTail", tail]]:
		_poly(mirror, item[0], item[1], Color(0.24, 0.23, 0.20, 0.30))
	# 月影的倒影用同一套水面波紋，不再重複生成。
	var moon_band := _ellipse(Vector2(MOON_X, 1018), 150, 12, Color(0.62, 0.76, 0.84, 0.12))
	moon_band.name = "MoonReflectionWide"
	parent.add_child(moon_band)

func _disc(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(48):
		var a: float = TAU * float(i) / 48.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	p.color = color
	return p

func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> Polygon2D:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(32):
		var a: float = TAU * float(i) / 32.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p

func _poly(parent: Node, node_name: String, points: Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = node_name
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)
	return p

func _after_b8() -> void:
	_cm().mark_clear("B8")
	_cm().set_beat("B9")
	_play_ending()

func _play_ending() -> void:
	_say(STORY.lines("B9"), Callable(self, "_after_b9"))

func _after_b9() -> void:
	_cm().mark_clear("B9")
	_stage_over = true
	if _shell != null:
		# 留一拍空鏡：讓玩家看見水面倒影與岸上的虎屍，再進結算。
		await get_tree().create_timer(1.4).timeout
		_shell.show_summary(_cm().loot_counts)
