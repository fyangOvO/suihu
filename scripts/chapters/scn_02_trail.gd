extends "res://scripts/chapters/stage_base.gd"
## SCN-02 山道：B2 旁白 → B3 老虎伥鬼实体教学战。
## 敌人死亡后写 B3 完成并进入 B4；教程提示只负责教学，不再用计时器自动推进。

const CORPSE_GHOST_SCENE := "res://scenes/CorpseGhost.tscn"
const CORPSE_VISUAL_SCALE := 0.68
const CORPSE_VISUAL_Y := -198.0

var _tutorial_step: int = 0
var _tutorial_t: float = 0.0
var _enemy_down: bool = false
var _ghost_presence: Node2D
var _tutorial_focus: Node2D
var _focus_hidden: bool = false
var _focus_tween: Tween

func scene_id() -> String:
	return "SCN-02"

func scene_title() -> String:
	return "山道"

func first_beat() -> String:
	return "B2"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return CORPSE_GHOST_SCENE

func opponent_display_name() -> String:
	return "老虎伥鬼"

func _on_stage_start() -> void:
	if p2 != null:
		p2.position.x = 1120.0
		p2.set_physics_process(false)
		_fit_ghost_visual()
		_ensure_ghost_presence()
	if _cm().current_beat == "B2":
		_say(STORY.lines("B2"), Callable(self, "_after_b2"))
	else:
		_start_fight()

func _after_b2() -> void:
	_cm().mark_clear("B2")
	_cm().set_beat("B3")
	_start_fight()

func _start_fight() -> void:
	_tutorial_step = 0
	_tutorial_t = 0.0
	_enemy_down = false
	_focus_hidden = false
	if p2 != null:
		p2.set_physics_process(true)
		_fit_ghost_visual()
		_ensure_ghost_presence()
		_show_tutorial_focus()
		_play_ghost_arrival()
	show_banner("山道：霧裡有人影擋路。", 2.0)

func _tick_stage(delta: float) -> void:
	_tutorial_t += delta
	# 只要伥鬼青煙散完，這場就結束；不依賴教程計時
	if not _enemy_down and p2 != null and p2.current_hp <= 0 and p2._death_done:
		_enemy_down = true
		_hide_tutorial_focus()
		_cm().mark_clear("B3")
		_finish_to("B4", 1.6, "山道通了。")
		return
	if _enemy_down:
		return
	if _tutorial_step == 0 and _tutorial_t >= 2.2:
		_tutorial_step = 1
		show_banner("J 輕擊 / K 重擊：木棍很長，貼身前先看起手。", 2.4, "教學")
	elif _tutorial_step == 1 and _tutorial_t >= 5.2:
		_tutorial_step = 2
		show_banner("L 站防；它會站著擋，不會蹲防。", 2.4, "教學")
	elif _tutorial_step == 2 and _tutorial_t >= 8.2:
		_tutorial_step = 3
		show_banner("它揮棍前搖長，看準收招再打。", 2.4, "教學")
	if not _focus_hidden and _tutorial_t >= 10.8:
		_hide_tutorial_focus()

func _fit_ghost_visual() -> void:
	if p2 == null:
		return
	var vis := p2.get_node_or_null("Visual") as Sprite2D
	if vis == null:
		return
	var face_sign: float = signf(vis.scale.x)
	if face_sign == 0.0:
		face_sign = 1.0
	vis.scale = Vector2(CORPSE_VISUAL_SCALE * face_sign, CORPSE_VISUAL_SCALE)
	vis.position.y = CORPSE_VISUAL_Y

func _ensure_ghost_presence() -> void:
	if p2 == null:
		return
	if _ghost_presence != null and is_instance_valid(_ghost_presence):
		return
	_ghost_presence = Node2D.new()
	_ghost_presence.name = "GhostPresence"
	_ghost_presence.z_index = -1
	p2.add_child(_ghost_presence)

	var foot_shadow := Polygon2D.new()
	foot_shadow.name = "GhostFootShadow"
	foot_shadow.polygon = _ellipse_points(62.0, 13.0, 20)
	foot_shadow.color = Color(0.012, 0.020, 0.018, 0.62)
	_ghost_presence.add_child(foot_shadow)

	var tex := _make_ghost_glow_texture()
	var fog := Sprite2D.new()
	fog.name = "GhostFogLow"
	fog.texture = tex
	fog.position = Vector2(0, -36)
	fog.scale = Vector2(3.35, 1.35)
	fog.modulate = Color(0.50, 0.70, 0.63, 0.28)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fog.material = add_mat
	fog.z_index = 0
	_ghost_presence.add_child(fog)

	var fog_high := Sprite2D.new()
	fog_high.name = "GhostFogHigh"
	fog_high.texture = tex
	fog_high.position = Vector2(0, -142)
	fog_high.scale = Vector2(2.2, 1.6)
	fog_high.modulate = Color(0.46, 0.64, 0.58, 0.15)
	fog_high.material = add_mat
	fog_high.z_index = 0
	_ghost_presence.add_child(fog_high)

	var wisp_l := Line2D.new()
	wisp_l.name = "GhostWispL"
	wisp_l.points = PackedVector2Array([
		Vector2(-28, -16), Vector2(-42, -78), Vector2(-34, -132), Vector2(-18, -176),
	])
	wisp_l.width = 2.0
	wisp_l.default_color = Color(0.50, 0.66, 0.58, 0.18)
	wisp_l.joint_mode = Line2D.LINE_JOINT_ROUND
	wisp_l.z_index = 0
	_ghost_presence.add_child(wisp_l)
	var wisp_r := Line2D.new()
	wisp_r.name = "GhostWispR"
	wisp_r.points = PackedVector2Array([
		Vector2(30, -20), Vector2(44, -90), Vector2(36, -142), Vector2(20, -186),
	])
	wisp_r.width = 2.0
	wisp_r.default_color = Color(0.50, 0.66, 0.58, 0.18)
	wisp_r.joint_mode = Line2D.LINE_JOINT_ROUND
	wisp_r.z_index = 0
	_ghost_presence.add_child(wisp_r)

	var burst := Sprite2D.new()
	burst.name = "GhostArrival"
	burst.texture = tex
	burst.position = Vector2(0, -76)
	burst.scale = Vector2(0.8, 0.8)
	burst.modulate = Color(0.56, 0.76, 0.68, 0.0)
	burst.material = add_mat
	_ghost_presence.add_child(burst)

func _show_tutorial_focus() -> void:
	if p2 == null:
		return
	if _tutorial_focus == null or not is_instance_valid(_tutorial_focus):
		_tutorial_focus = Node2D.new()
		_tutorial_focus.name = "TutorialFocus"
		_tutorial_focus.position = Vector2(0, -120)
		p2.add_child(_tutorial_focus)
		var frame := Color(0.86, 0.72, 0.46, 0.72)
		_add_focus_bracket(_tutorial_focus, "FocusTL", PackedVector2Array([
			Vector2(-36, -126), Vector2(-64, -126), Vector2(-64, -98),
		]), frame)
		_add_focus_bracket(_tutorial_focus, "FocusTR", PackedVector2Array([
			Vector2(36, -126), Vector2(64, -126), Vector2(64, -98),
		]), frame)
		_add_focus_bracket(_tutorial_focus, "FocusBL", PackedVector2Array([
			Vector2(-36, 126), Vector2(-64, 126), Vector2(-64, 98),
		]), frame)
		_add_focus_bracket(_tutorial_focus, "FocusBR", PackedVector2Array([
			Vector2(36, 126), Vector2(64, 126), Vector2(64, 98),
		]), frame)
		var tick := Polygon2D.new()
		tick.name = "FocusDiamond"
		tick.polygon = PackedVector2Array([
			Vector2(0, -146), Vector2(8, -134), Vector2(0, -122), Vector2(-8, -134),
		])
		tick.color = Color(0.92, 0.76, 0.46, 0.75)
		_tutorial_focus.add_child(tick)
	_focus_hidden = false
	_tutorial_focus.visible = true
	_tutorial_focus.modulate.a = 0.68
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_loops()
	_focus_tween.tween_property(_tutorial_focus, "modulate:a", 0.46, 0.85) \
		.set_trans(Tween.TRANS_SINE)
	_focus_tween.tween_property(_tutorial_focus, "modulate:a", 0.68, 0.85) \
		.set_trans(Tween.TRANS_SINE)

func _hide_tutorial_focus() -> void:
	_focus_hidden = true
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	if _tutorial_focus != null and is_instance_valid(_tutorial_focus):
		_tutorial_focus.visible = false

func _play_ghost_arrival() -> void:
	if _ghost_presence == null or not is_instance_valid(_ghost_presence):
		return
	_ghost_presence.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ghost_presence, "modulate:a", 1.0, 0.45)
	var burst := _ghost_presence.get_node_or_null("GhostArrival") as Sprite2D
	if burst != null:
		burst.modulate.a = 0.34
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(burst, "scale", Vector2(3.4, 3.4), 0.75) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.tween_property(burst, "modulate:a", 0.0, 0.75)

func _add_focus_bracket(parent: Node2D, node_name: String, points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = 3.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)

func _ellipse_points(rx: float, ry: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _make_ghost_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.62, 0.82, 0.72, 0.65),
		Color(0.34, 0.55, 0.48, 0.28),
		Color(0.18, 0.32, 0.28, 0.0),
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
