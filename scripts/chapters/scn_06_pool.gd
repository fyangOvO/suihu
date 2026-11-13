extends "res://scripts/chapters/stage_base.gd"
## SCN-06 水潭：B8 倒影字幕 → B9 下山 → 章末結算 → 主菜單／重開。
## 水面倒影與岸邊虎屍剪影是本章最後的兩個視覺落點。

const WATER_Y := 900.0
const MOON_X := 960.0

var _ripples: Array[Polygon2D] = []
var _ripple_phases: Array[float] = []
var _tiger_parts: Array[Polygon2D] = []
var _reflection_human: Node2D
var _reflection_tiger: Node2D
var _reflection_flash: ColorRect
var _reflection_changed: bool = false

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
	_build_pool_reflection()
	if _cm().current_beat == "B9":
		_reveal_white_tiger_reflection()
		_play_ending()
	else:
		_say(STORY.lines("B8"), Callable(self, "_after_b8"))
		_schedule_reflection_reveal()

func _schedule_reflection_reveal() -> void:
	# B8 字幕先讓玩家看見「正常倒影」，再切換成白虎；不阻塞對話。
	await get_tree().create_timer(0.75).timeout
	if is_inside_tree() and not _reflection_changed and not _stage_over:
		_reveal_white_tiger_reflection()

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
	water.color = Color(0.055, 0.085, 0.115, 1)
	parent.add_child(water)
	var surface := ColorRect.new()
	surface.name = "WaterSurface"
	surface.position = Vector2(0, WATER_Y - 1)
	surface.size = Vector2(1920, 3)
	surface.color = Color(0.18, 0.27, 0.32, 0.55)
	parent.add_child(surface)
	var deep := ColorRect.new()
	deep.name = "WaterDeep"
	deep.position = Vector2(0, WATER_Y + 54)
	deep.size = Vector2(1920, 126)
	deep.color = Color(0.020, 0.035, 0.055, 0.55)
	parent.add_child(deep)

	# 月影：不排成一條整齊的漏斗，改成有橫向偏移的碎月，才像被水揉開。
	for i in range(9):
		var ry := 1.6 + float(i % 3) * 2.4
		var rx := 46.0 + float((i * 37) % 34)
		var x_off := sin(float(i) * 2.3) * 22.0
		var strip := _ellipse(Vector2(MOON_X + x_off, WATER_Y + 10.0 + float(i) * 11.0), rx, ry, Color(0.62, 0.76, 0.84, 0.12 + float(i % 3) * 0.02))
		strip.name = "MoonReflection%d" % i
		parent.add_child(strip)
		_ripples.append(strip)
		_ripple_phases.append(float(i) * 0.7)
	var moon_glow := _ellipse(Vector2(MOON_X, WATER_Y + 10), 220, 26, Color(0.48, 0.62, 0.70, 0.10))
	moon_glow.name = "MoonReflectionGlow"
	parent.add_child(moon_glow)

	_add_night_bank(parent)
	_build_tiger_corpse(parent)
	_add_reflection(parent)
	_build_pool_reflection()

func _build_pool_reflection() -> void:
	var bg := get_node_or_null("Background")
	var parent: Node = bg if bg != null else self
	if parent.get_node_or_null("PoolReflection") != null:
		return
	var root := Node2D.new()
	root.name = "PoolReflection"
	root.position = Vector2(600, 930)
	root.scale = Vector2(1.0, -0.90)
	root.modulate = Color(0.72, 0.80, 0.88, 1.0)
	parent.add_child(root)

	# 正常倒影：先只留一個潮濕、發暗的人形，等字幕推進再換成白虎。
	_reflection_human = Node2D.new()
	_reflection_human.name = "PlayerHumanReflection"
	root.add_child(_reflection_human)
	var head := _disc(Vector2(0, -88), 13, Color(0.10, 0.11, 0.10, 0.58))
	head.name = "HumanHead"
	_reflection_human.add_child(head)
	var torso := _poly(_reflection_human, "HumanTorso", [
		Vector2(-20, -74), Vector2(20, -74), Vector2(29, -8),
		Vector2(34, 4), Vector2(-34, 4), Vector2(-29, -8),
	], Color(0.10, 0.11, 0.10, 0.52))
	torso.name = "HumanTorso"
	var arm_l := Line2D.new()
	arm_l.name = "HumanArmL"
	arm_l.points = PackedVector2Array([Vector2(-18, -66), Vector2(-36, -34), Vector2(-28, -10)])
	arm_l.width = 4.0
	arm_l.default_color = Color(0.12, 0.13, 0.12, 0.48)
	_reflection_human.add_child(arm_l)
	var arm_r := Line2D.new()
	arm_r.name = "HumanArmR"
	arm_r.points = PackedVector2Array([Vector2(18, -66), Vector2(36, -34), Vector2(28, -10)])
	arm_r.width = 4.0
	arm_r.default_color = Color(0.12, 0.13, 0.12, 0.48)
	_reflection_human.add_child(arm_r)

	# 白虎倒影：先藏著；B8 字幕到一半時以水面閃光切換。
	_reflection_tiger = Node2D.new()
	_reflection_tiger.name = "PlayerWhiteTigerReflection"
	_reflection_tiger.visible = false
	root.add_child(_reflection_tiger)
	_poly(_reflection_tiger, "WhiteTigerBody", [
		Vector2(-96, -28), Vector2(-66, -56), Vector2(-18, -64),
		Vector2(38, -60), Vector2(78, -46), Vector2(94, -20),
		Vector2(86, 2), Vector2(30, 6), Vector2(-42, 4), Vector2(-88, -6),
	], Color(0.50, 0.55, 0.50, 0.40))
	_poly(_reflection_tiger, "WhiteTigerUnderbelly", [
		Vector2(-88, -8), Vector2(-40, 2), Vector2(36, 4), Vector2(88, -6),
		Vector2(82, 10), Vector2(26, 14), Vector2(-48, 12),
	], Color(0.18, 0.21, 0.19, 0.34))
	_poly(_reflection_tiger, "WhiteTigerHead", [
		Vector2(72, -54), Vector2(108, -62), Vector2(132, -44),
		Vector2(136, -22), Vector2(116, -4), Vector2(86, -10), Vector2(68, -28),
	], Color(0.54, 0.59, 0.53, 0.44))
	for ear_pos in [Vector2(78, -58), Vector2(108, -60)]:
		_poly(_reflection_tiger, "WhiteTigerEar%d" % int(ear_pos.x), [
			ear_pos, ear_pos + Vector2(10, -18), ear_pos + Vector2(20, -2),
		], Color(0.50, 0.55, 0.50, 0.44))
	_poly(_reflection_tiger, "WhiteTigerTail", [
		Vector2(-88, -8), Vector2(-128, 4), Vector2(-150, 20),
		Vector2(-142, 30), Vector2(-110, 18), Vector2(-88, 10),
	], Color(0.48, 0.53, 0.48, 0.38))
	# 直裰：不是給虎穿衣服，而是把「人形倒影披著的白袍」留在老虎肩上。
	_poly(_reflection_tiger, "WhiteRobe", [
		Vector2(-54, -58), Vector2(22, -64), Vector2(54, -38),
		Vector2(42, -4), Vector2(-30, 0), Vector2(-66, -22),
	], Color(0.24, 0.24, 0.20, 0.40))
	# 水面把白虎的背脊切出一條冷白邊，讓剪影不至於變成發亮的水斑。
	var white_rim := Line2D.new()
	white_rim.name = "WhiteTigerRim"
	white_rim.points = PackedVector2Array([
		Vector2(-88, -16), Vector2(-64, -48), Vector2(-18, -59),
		Vector2(38, -56), Vector2(78, -42), Vector2(96, -22), Vector2(94, -10),
	])
	white_rim.width = 2.0
	white_rim.default_color = Color(0.64, 0.72, 0.67, 0.44)
	_reflection_tiger.add_child(white_rim)
	var white_head_rim := Line2D.new()
	white_head_rim.name = "WhiteTigerHeadRim"
	white_head_rim.points = PackedVector2Array([
		Vector2(72, -54), Vector2(108, -62), Vector2(132, -44),
		Vector2(136, -22), Vector2(116, -4),
	])
	white_head_rim.width = 1.6
	white_head_rim.default_color = Color(0.66, 0.74, 0.69, 0.42)
	_reflection_tiger.add_child(white_head_rim)
	for i in range(3):
		var stripe := Line2D.new()
		stripe.name = "WhiteTigerStripe%d" % i
		stripe.points = PackedVector2Array([
			Vector2(-50.0 + i * 30.0, -54), Vector2(-38.0 + i * 30.0, -42),
			Vector2(-28.0 + i * 30.0, -34),
		])
		stripe.width = 2.0
		stripe.default_color = Color(0.10, 0.14, 0.13, 0.44)
		_reflection_tiger.add_child(stripe)
	for leg_x in [-64.0, -20.0, 30.0, 60.0]:
		_poly(_reflection_tiger, "WhiteTigerLeg%d" % int(leg_x), [
			Vector2(leg_x, -8), Vector2(leg_x + 8, 6), Vector2(leg_x + 16, 14),
			Vector2(leg_x + 14, 22), Vector2(leg_x + 2, 18), Vector2(leg_x - 4, 4),
		], Color(0.48, 0.53, 0.48, 0.38))
	# 舉爪：白虎倒影的右手抬到水面上緣，讓「不是武松」的輪廓更明確。
	_poly(_reflection_tiger, "WhiteTigerPaw", [
		Vector2(126, -28), Vector2(150, -50), Vector2(168, -34),
		Vector2(164, -12), Vector2(144, -4), Vector2(128, -12),
	], Color(0.58, 0.62, 0.56, 0.42))
	for claw_x in [150.0, 158.0, 166.0]:
		var claw := Line2D.new()
		claw.name = "WhiteTigerClaw%d" % int(claw_x)
		claw.points = PackedVector2Array([Vector2(claw_x, -20), Vector2(claw_x + 5, -31)])
		claw.width = 1.5
		claw.default_color = Color(0.18, 0.20, 0.18, 0.50)
		_reflection_tiger.add_child(claw)
	_poly(_reflection_tiger, "WhiteTigerNose", [
		Vector2(126, -22), Vector2(136, -24), Vector2(132, -14),
	], Color(0.14, 0.16, 0.14, 0.58))
	for fang_x in [124.0, 136.0]:
		_poly(_reflection_tiger, "WhiteTigerFang%d" % int(fang_x), [
			Vector2(fang_x, -8), Vector2(fang_x + 4, -9), Vector2(fang_x + 2, 2),
		], Color(0.72, 0.74, 0.66, 0.46))
	for stripe_x in [84.0, 104.0, 118.0]:
		var head_stripe := Line2D.new()
		head_stripe.name = "WhiteTigerHeadStripe%d" % int(stripe_x)
		head_stripe.points = PackedVector2Array([Vector2(stripe_x, -56), Vector2(stripe_x + 6, -36)])
		head_stripe.width = 2.0
		head_stripe.default_color = Color(0.10, 0.14, 0.13, 0.44)
		_reflection_tiger.add_child(head_stripe)
	var eye := Line2D.new()
	eye.name = "WhiteTigerEye"
	eye.points = PackedVector2Array([Vector2(100, -40), Vector2(112, -38)])
	eye.width = 2.5
	eye.default_color = Color(0.72, 0.58, 0.30, 0.52)
	_reflection_tiger.add_child(eye)

	# 人形／白虎腳下的水面波紋，讓倒影不是浮貼在黑水上。
	for i in range(3):
		var ripple := _ellipse(Vector2(600, 936.0 + float(i) * 17.0), 120.0 - float(i) * 24.0, 4.0, Color(0.42, 0.52, 0.50, 0.10))
		ripple.name = "PoolReflectionRipple%d" % i
		parent.add_child(ripple)
	_reflection_flash = ColorRect.new()
	_reflection_flash.name = "ReflectionFlash"
	_reflection_flash.position = Vector2(470, 896)
	_reflection_flash.size = Vector2(260, 7)
	_reflection_flash.color = Color(0.72, 0.82, 0.78, 0.0)
	_reflection_flash.visible = false
	parent.add_child(_reflection_flash)

func _reveal_white_tiger_reflection() -> void:
	if _reflection_changed:
		return
	_reflection_changed = true
	if _reflection_human != null:
		_reflection_human.visible = false
	if _reflection_tiger != null:
		_reflection_tiger.visible = true
	if _reflection_flash != null:
		_reflection_flash.visible = _cm().current_beat == "B8"
		if _reflection_flash.visible:
			_reflection_flash.color.a = 0.42
			var tw := create_tween()
			tw.tween_property(_reflection_flash, "color:a", 0.0, 0.35)
			tw.finished.connect(func() -> void: _reflection_flash.visible = false)

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
	# 血跡先鋪在石台上，虎身再壓上去；只露邊緣，不搶剪影。
	var blood := _ellipse(Vector2(1540, 708), 205, 20, Color(0.31, 0.075, 0.048, 0.44))
	blood.name = "TigerBlood"
	parent.add_child(blood)
	var blood_pool := _ellipse(Vector2(1608, 712), 54, 10, Color(0.38, 0.095, 0.058, 0.38))
	blood_pool.name = "TigerBloodPool"
	parent.add_child(blood_pool)
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
		var part_color := Color(0.125, 0.112, 0.092, 0.99)
		if item[0] == "TigerHead":
			part_color = Color(0.175, 0.155, 0.125, 0.99)
		elif item[0] == "TigerTail":
			part_color = Color(0.135, 0.120, 0.100, 0.99)
		var p := _poly(parent, item[0], item[1], part_color)
		p.position = Vector2(1450, 660)
		_tiger_parts.append(p)
	# 肋線：沿著側腹往脊背收，讓虎身有胸腔而不是一整塊黑板。
	for i in range(4):
		var rib := Line2D.new()
		rib.name = "TigerRib%d" % i
		rib.points = PackedVector2Array([
			Vector2(70 + i * 30, -12), Vector2(82 + i * 30, 8), Vector2(76 + i * 30, 32),
		])
		rib.width = 2.0
		rib.default_color = Color(0.43, 0.35, 0.26, 0.40)
		rib.position = Vector2(1450, 660)
		parent.add_child(rib)
	# 虎斑：只留幾道暗赭，遠看是剪影，近看能認出虎。
	for stripe in [Vector2(60, -24), Vector2(104, -32), Vector2(150, -28), Vector2(190, -24), Vector2(120, 34), Vector2(168, 30)]:
		var s := _poly(parent, "TigerStripe%d" % int(stripe.x), [
			stripe, stripe + Vector2(12, -8), stripe + Vector2(22, 2), stripe + Vector2(8, 7),
		], Color(0.40, 0.19, 0.090, 0.78))
		s.position = Vector2(1450, 660)
		_tiger_parts.append(s)
	# 月照在虎背上的冷邊，讓黑剪影不至於糊進夜色。
	var rim := Line2D.new()
	rim.name = "TigerRim"
	rim.points = PackedVector2Array([
		Vector2(2, -18), Vector2(90, -45), Vector2(176, -37),
		Vector2(224, -15), Vector2(246, 15),
	])
	rim.width = 4.0
	rim.default_color = Color(0.68, 0.70, 0.58, 0.82)
	rim.position = Vector2(1450, 660)
	parent.add_child(rim)
	# 頭頂另補一段月邊，讓虎頭從夜色裡先被讀出來。
	var head_rim := Line2D.new()
	head_rim.name = "TigerHeadRim"
	head_rim.points = PackedVector2Array([
		Vector2(218, -40), Vector2(252, -58), Vector2(286, -42),
		Vector2(294, -18), Vector2(276, -4),
	])
	head_rim.width = 3.0
	head_rim.default_color = Color(0.70, 0.72, 0.60, 0.78)
	head_rim.position = Vector2(1450, 660)
	parent.add_child(head_rim)

	# 脊線：從尾根一路接到肩胛，讓虎屍不再只是大塊暗影。
	var spine := Line2D.new()
	spine.name = "TigerSpine"
	spine.points = PackedVector2Array([
		Vector2(12, -18), Vector2(62, -31), Vector2(116, -38),
		Vector2(172, -31), Vector2(216, -12),
	])
	spine.width = 4.5
	spine.default_color = Color(0.64, 0.53, 0.37, 0.80)
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
	belly.default_color = Color(0.40, 0.35, 0.27, 0.46)
	belly.position = Vector2(1450, 660)
	parent.add_child(belly)
	var haunch := Line2D.new()
	haunch.name = "TigerHaunch"
	haunch.points = PackedVector2Array([Vector2(154, -6), Vector2(186, 16), Vector2(176, 42)])
	haunch.width = 2.0
	haunch.default_color = Color(0.37, 0.32, 0.25, 0.42)
	haunch.position = Vector2(1450, 660)
	parent.add_child(haunch)

	# 頭部：耳朵、閉眼與吻部；剪影靠這三個缺口讀成虎。
	for ear in [Vector2(236, -54), Vector2(278, -50)]:
		var ear_poly := _poly(parent, "TigerEar%d" % int(ear.x), [
			ear, ear + Vector2(14, -20), ear + Vector2(24, 2),
		], Color(0.18, 0.16, 0.128, 0.98))
		ear_poly.position = Vector2(1450, 660)
	var muzzle := _poly(parent, "TigerMuzzle", [
		Vector2(274, -10), Vector2(296, -8), Vector2(292, 4),
		Vector2(272, 6),
	], Color(0.25, 0.215, 0.17, 0.95))
	muzzle.position = Vector2(1450, 660)
	# 鼻頭、齒與鬚：只留三筆，但能把虎頭從石台暗影裡提出來。
	_poly(parent, "TigerNose", [
		Vector2(286, -8), Vector2(296, -6), Vector2(292, 0), Vector2(284, -1),
	], Color(0.075, 0.062, 0.050, 0.95)).position = Vector2(1450, 660)
	for tooth_x in [278.0, 288.0]:
		_poly(parent, "TigerFang%d" % int(tooth_x), [
			Vector2(tooth_x, 2), Vector2(tooth_x + 4, 3), Vector2(tooth_x + 2, 9),
		], Color(0.80, 0.76, 0.62, 0.66)).position = Vector2(1450, 660)
	for whisker in [Vector2(294, -5), Vector2(296, -2), Vector2(292, 1)]:
		var w := Line2D.new()
		w.name = "TigerWhisker%d" % int(whisker.y + 6)
		w.points = PackedVector2Array([whisker, whisker + Vector2(16, -3)])
		w.width = 1.0
		w.default_color = Color(0.56, 0.51, 0.39, 0.36)
		w.position = Vector2(1450, 660)
		parent.add_child(w)
	var eye := Line2D.new()
	eye.name = "TigerClosedEye"
	eye.points = PackedVector2Array([Vector2(258, -28), Vector2(270, -26)])
	eye.width = 2.0
	eye.default_color = Color(0.70, 0.64, 0.50, 0.50)
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
		], Color(0.235, 0.205, 0.168, 0.98))
		leg_poly.position = Vector2(1450, 660)
		var paw := _poly(parent, "TigerPaw%d" % int(leg.x), [
			leg + Vector2(12, 52), leg + Vector2(30, 55),
			leg + Vector2(32, 62), leg + Vector2(10, 60),
		], Color(0.39, 0.335, 0.26, 0.96))
		paw.position = Vector2(1450, 660)
		for toe in range(3):
			var toe_line := Line2D.new()
			toe_line.name = "TigerToe%d_%d" % [int(leg.x), toe]
			toe_line.points = PackedVector2Array([
				leg + Vector2(14 + toe * 5, 56), leg + Vector2(15 + toe * 5, 61),
			])
			toe_line.width = 1.0
			toe_line.default_color = Color(0.50, 0.43, 0.34, 0.46)
			toe_line.position = Vector2(1450, 660)
			parent.add_child(toe_line)
		var knee := Line2D.new()
		knee.name = "TigerKnee%d" % int(leg.x)
		knee.points = PackedVector2Array([leg + Vector2(8, 22), leg + Vector2(17, 34)])
		knee.width = 1.5
		knee.default_color = Color(0.38, 0.33, 0.26, 0.44)
		knee.position = Vector2(1450, 660)
		parent.add_child(knee)

	# 地面的接觸陰影，讓虎屍真的壓在石台上。
	var shadow := _ellipse(Vector2(1450, 704), 190, 18, Color(0, 0, 0, 0.42))
	shadow.name = "TigerShadow"
	parent.add_child(shadow)
	parent.move_child(shadow, 0)

func _add_night_bank(parent: Node) -> void:
	# 遠岸：只留一條低低的嶺線，讓黑空不是純空，也不遮住月亮。
	var ridge := _poly(parent, "FarRidge", [
		Vector2(0, 766), Vector2(260, 744), Vector2(520, 774), Vector2(780, 752),
		Vector2(1040, 782), Vector2(1300, 754), Vector2(1580, 784),
		Vector2(1920, 768), Vector2(1920, 820), Vector2(0, 820),
	], Color(0.026, 0.036, 0.044, 0.92))
	ridge.z_index = 0
	var ridge_edge := Line2D.new()
	ridge_edge.name = "FarRidgeEdge"
	ridge_edge.points = PackedVector2Array([
		Vector2(0, 766), Vector2(260, 744), Vector2(520, 774), Vector2(780, 752),
		Vector2(1040, 782), Vector2(1300, 754), Vector2(1580, 784), Vector2(1920, 768),
	])
	ridge_edge.width = 2.0
	ridge_edge.default_color = Color(0.18, 0.22, 0.25, 0.18)
	parent.add_child(ridge_edge)
	# 水線薄霧：把岸與水接起來，倒影上緣不會是一條硬切線。
	var mist := _ellipse(Vector2(960, 898), 560, 14, Color(0.38, 0.48, 0.52, 0.055))
	mist.name = "PoolMist"
	parent.add_child(mist)
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
	mirror.scale = Vector2(1.0, -0.52)
	mirror.modulate = Color(0.86, 0.90, 0.95, 1.0)
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
		var r_color := Color(0.50, 0.46, 0.38, 0.66)
		if item[0] == "RHead":
			r_color = Color(0.54, 0.49, 0.40, 0.68)
		_poly(mirror, item[0], item[1], r_color)
	# 倒影也要有腿與頭部缺口，否則水下只是一條灰帶。
	for leg in [Vector2(42, 36), Vector2(108, 44), Vector2(166, 38), Vector2(202, 30)]:
		_poly(mirror, "RLeg%d" % int(leg.x), [
			leg, leg + Vector2(9, 30), leg + Vector2(18, 43),
			leg + Vector2(30, 46), leg + Vector2(28, 54),
			leg + Vector2(12, 52), leg + Vector2(4, 36),
		], Color(0.40, 0.37, 0.30, 0.50))
		_poly(mirror, "RPaw%d" % int(leg.x), [
			leg + Vector2(12, 52), leg + Vector2(30, 55),
			leg + Vector2(32, 62), leg + Vector2(10, 60),
		], Color(0.50, 0.45, 0.35, 0.44))
	_poly(mirror, "RMuzzle", [
		Vector2(274, -10), Vector2(296, -8), Vector2(292, 4),
		Vector2(272, 6),
	], Color(0.44, 0.40, 0.31, 0.48))
	# 倒影裡保留一段冷色脊線，讓水面那層不是一塊均勻暗影。
	var mirror_spine := Line2D.new()
	mirror_spine.name = "RSpine"
	mirror_spine.points = PackedVector2Array([
		Vector2(12, -18), Vector2(62, -31), Vector2(116, -38),
		Vector2(172, -31), Vector2(216, -12),
	])
	mirror_spine.width = 2.5
	mirror_spine.default_color = Color(0.58, 0.58, 0.50, 0.58)
	mirror_spine.position = Vector2(0, 0)
	mirror.add_child(mirror_spine)
	var mirror_head_rim := Line2D.new()
	mirror_head_rim.name = "RHeadRim"
	mirror_head_rim.points = PackedVector2Array([
		Vector2(218, -40), Vector2(252, -58), Vector2(286, -42),
		Vector2(294, -18), Vector2(276, -4),
	])
	mirror_head_rim.width = 2.0
	mirror_head_rim.default_color = Color(0.60, 0.60, 0.52, 0.58)
	mirror_head_rim.position = Vector2(0, 0)
	mirror.add_child(mirror_head_rim)
	for i in range(3):
		var mirror_stripe := Line2D.new()
		mirror_stripe.name = "RStripe%d" % i
		mirror_stripe.points = PackedVector2Array([
			Vector2(72 + i * 34, -28), Vector2(84 + i * 34, -10), Vector2(80 + i * 34, 14),
		])
		mirror_stripe.width = 2.0
		mirror_stripe.default_color = Color(0.20, 0.24, 0.21, 0.34)
		mirror.add_child(mirror_stripe)
	# 倒影被水面切開的幾道波紋；越靠下越淡。
	for i in range(4):
		var band := _ellipse(Vector2(1450, 934.0 + float(i) * 16.0), 130.0 - float(i) * 18.0, 5.0, Color(0.44, 0.52, 0.50, 0.14))
		band.name = "TigerReflectionRipple%d" % i
		parent.add_child(band)
	# 月影的倒影用同一套水面波紋，不再重複生成。
	var moon_band := _ellipse(Vector2(MOON_X, 1018), 180, 14, Color(0.62, 0.76, 0.84, 0.16))
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
	_reveal_white_tiger_reflection()
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
