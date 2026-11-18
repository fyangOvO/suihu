extends "res://scripts/chapters/stage_base.gd"
## SCN-05 崗頂：B6 虎眼亮相 → B7 猛虎 Boss 三階段。
## HID-01：虎死後靠近虎屍 → 酒氣補滿＋黑霧吸入。
## HID-05：被絕命撲擊（BossDeathPounce）打死 → 虎說人話「你也是被放出來的」再回檢查點。

const CORPSE_RADIUS := 150.0
const CORPSE_WAIT_MAX := 5.0
const ABSORB_HOLD := 2.2
const HID05_LINE := "你也是被放出來的"
const HID05_HOLD := 2.4

var _corpse_wait: float = -1.0
var _wine_absorbed: bool = false
var _hid05_shown: bool = false
var _corpse_mist: CPUParticles2D

func scene_id() -> String:
	return "SCN-05"

func scene_title() -> String:
	return "崗頂"

func first_beat() -> String:
	return "B6"

func bgm_track() -> String:
	return "bgm_ridge"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return "res://scenes/Boss.tscn"

func opponent_display_name() -> String:
	return "景陽岡猛虎"

## OPT-03：Boss 戰比平常再拉遠 10%，留出虎撲的呼吸空間
func camera_zoom_mul() -> float:
	return 1.0 / 1.1

func _on_stage_start() -> void:
	if p2 != null:
		p2.set_physics_process(false)
	if _cm().current_beat == "B6":
		show_banner("霧裡，兩點青白先亮。", 2.6)
		await get_tree().create_timer(2.6).timeout
		_cm().mark_clear("B6")
		_cm().set_beat("B7")
	if p2 != null and not p2._death_done:
		p2.set_physics_process(true)
	show_banner("", 0.0)

func _tick_stage(delta: float) -> void:
	if p2 == null:
		return
	if p2.current_hp > 0 or not p2._death_done:
		return
	# 擊殺演出（BossDeathCine，3s）未結束前不開互動窗，避免提示壓在字幕上
	var cine = p2.get_node_or_null("BossDeathCine")
	if cine != null and cine.active:
		return
	if _corpse_wait < 0.0:
		_corpse_wait = 0.0
		_cm().mark_clear("B7")
		show_banner("虎屍未散，酒氣在動——靠近它。", 3.2)
		_spawn_corpse_mist()
	_corpse_wait += delta
	if not _wine_absorbed and p1 != null and _corpse_wait >= 0.35:
		if p1.global_position.distance_to(p2.global_position) <= CORPSE_RADIUS:
			_absorb_wine()
	if _wine_absorbed and _corpse_wait >= ABSORB_HOLD:
		_finish_to("B8", 0.0, "")
	elif not _wine_absorbed and _corpse_wait >= CORPSE_WAIT_MAX:
		_finish_to("B8", 0.0, "")

## 柔和圓點貼圖：CPUParticles2D 沒有貼圖時是硬方塊，暗景看不清
func _soft_dot() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex

## HID-01：虎屍位置持續冒黑霧，讓「靠近哪裡」看得見（Boss 本體已淡出）
func _spawn_corpse_mist() -> void:
	if p2 == null:
		return
	_corpse_mist = CPUParticles2D.new()
	_corpse_mist.name = "CorpseMist"
	_corpse_mist.position = p2.global_position + Vector2(0, -60)
	_corpse_mist.texture = _soft_dot()
	_corpse_mist.amount = 18
	_corpse_mist.lifetime = 1.6
	_corpse_mist.preprocess = 1.0
	_corpse_mist.direction = Vector2.UP
	_corpse_mist.spread = 75.0
	_corpse_mist.initial_velocity_min = 16.0
	_corpse_mist.initial_velocity_max = 40.0
	_corpse_mist.gravity = Vector2(0, -8)
	_corpse_mist.scale_amount_min = 1.0
	_corpse_mist.scale_amount_max = 2.4
	_corpse_mist.color = Color(0.40, 0.16, 0.52, 0.72)
	add_child(_corpse_mist)

## HID-01：酒氣瞬間補滿 + 黑霧由虎屍吸向玩家
func _absorb_wine() -> void:
	_wine_absorbed = true
	p1.wine_gauge = 100.0
	show_banner("酒氣入喉，筋骨如火。", 1.8)
	AUDIO.play_sfx("sfx_wine_full", -2.0)
	if _corpse_mist != null:
		_corpse_mist.emitting = false
	var mist := CPUParticles2D.new()
	mist.name = "WineMist"
	mist.position = p2.global_position
	mist.texture = _soft_dot()
	mist.amount = 28
	mist.lifetime = 0.95
	mist.one_shot = true
	mist.explosiveness = 0.55
	mist.direction = (p1.global_position - p2.global_position).normalized()
	mist.spread = 22.0
	mist.initial_velocity_min = 110.0
	mist.initial_velocity_max = 190.0
	mist.gravity = Vector2.ZERO
	mist.damping_min = 30.0
	mist.damping_max = 60.0
	mist.scale_amount_min = 0.5
	mist.scale_amount_max = 1.2
	mist.color = Color(0.34, 0.12, 0.46, 0.55)
	mist.emitting = true
	add_child(mist)

## HID-05：被絕命撲擊打死時，先讓虎說一句人話，再彈死亡面板
func _fail() -> void:
	if not _hid05_shown and p1 != null and p1.get("last_hit_state") == "BossDeathPounce":
		_hid05_shown = true
		_stage_over = true
		_result.visible = false
		if p2 != null:
			p2.set_physics_process(false)
		show_banner(HID05_LINE, HID05_HOLD)
		await get_tree().create_timer(HID05_HOLD).timeout
		if _shell != null:
			_shell.show_death(_cm().has_checkpoint())
		return
	super._fail()
