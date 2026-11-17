extends SceneTree
## OPT-01 打擊感自測（無頭可跑）：命中停頓幀數映射、停頓只凍結邏輯、鏡頭 trauma／微推衰減、設置開關持久化。
## 用法：godot --headless --path <game> --script res://tools/selftest_feel.gd
## PASS 退出 0；FAIL 退出 1。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const CAMERA_FX := preload("res://scripts/camera_fx.gd")
const FIGHTER_SCRIPT := preload("res://scripts/rigged_fighter.gd")
const SLOW_MO := preload("res://scripts/slow_mo.gd")
const TEST_CFG := "user://selftest_feel.cfg"

var fails: Array = []
var a: CharacterBody2D
var b: CharacterBody2D
var cam: Camera2D
var cam_fx
var n: int = 0

var hit_seen: bool = false
var hit_frames: int = 0
var frozen_a: int = -1
var frozen_b: int = -1
var stop_waited: int = 0
var resumed: bool = false
var dealt: bool = false

# OPT-02 第二階段
var phase2: bool = false
var parry_n: int = 0
var combo_started: bool = false
var combo_pressed: bool = false
var combo_release_n: int = 0
var saw_light2: bool = false
var tech_started: bool = false
var tech_pressed: bool = false
var tech_release_n: int = 0
var tech_checked: bool = false
var fail_tech_checked: bool = false
var hp_before_tech: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _finish() -> void:
	SETTINGS.clear()
	SETTINGS.reset_path()
	print("FEEL_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails,
		" frames=", n, " hitstop=", hit_frames)
	quit(0 if fails.is_empty() else 1)

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	# 1) 幀數映射：輕 4／重 8／覺醒 12，單下 ≥100 傷害視同重招
	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	a = packed.instantiate()
	b = packed.instantiate()
	_check("light hitstop 4", a.hitstop_frames_for("Light1", 65) == 4)
	_check("heavy hitstop 8", a.hitstop_frames_for("Heavy", 130) == 8)
	_check("super hitstop 12", a.hitstop_frames_for("Super", 300) == 12)
	_check("light-slot big damage counts heavy", a.hitstop_frames_for("Light1", 120) == 8)
	_check("enemy tail sweep stays light", a.hitstop_frames_for("TigerTail", 70) == 4)

	# 1b) OPT-02 窗口常數：攻擊緩衝 6／方向 18／架招白閃 5／受身無敵 6
	_check("attack buffer 6 frames", FIGHTER_SCRIPT.ATTACK_BUFFER_FRAMES == 6)
	_check("direction buffer 18 frames", FIGHTER_SCRIPT.DIR_BUFFER_FRAMES == 18)
	_check("command buffer 18 frames", FIGHTER_SCRIPT.CMD_BUFFER_FRAMES == 18)
	_check("parry flash 5 frames", FIGHTER_SCRIPT.PARRY_FLASH_FRAMES == 5)
	_check("tech invuln 6 frames", FIGHTER_SCRIPT.TECH_INVULN_FRAMES == 6)

	# 2) 鏡頭層：kick 後有位移與 2% 微推，0.8s／0.1s 各自回到基準
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.clear()
	_check("camera fx defaults on", SETTINGS.load_camera_fx())
	_check("camera fx saves off", SETTINGS.save_camera_fx(false) and not SETTINGS.load_camera_fx())
	_check("camera fx saves on", SETTINGS.save_camera_fx(true) and SETTINGS.load_camera_fx())
	var cfg := ConfigFile.new()
	cfg.set_value("display", "camera_fx", "yes")
	cfg.save(TEST_CFG)
	_check("camera fx bad type falls back on", SETTINGS.load_camera_fx())

	# 2b) 打擊特效開關（架招白閃／慢放）：預設開、可寫關、壞型別回預設
	_check("parry fx defaults on", SETTINGS.load_parry_fx())
	_check("parry fx saves off", SETTINGS.save_parry_fx(false) and not SETTINGS.load_parry_fx())
	_check("parry fx saves on", SETTINGS.save_parry_fx(true) and SETTINGS.load_parry_fx())
	cfg.set_value("display", "parry_fx", 7)
	cfg.save(TEST_CFG)
	_check("parry fx bad type falls back on", SETTINGS.load_parry_fx())
	SETTINGS.save_parry_fx(true)

	cam = Camera2D.new()
	cam.position = Vector2(960, 540)
	root.add_child(cam)
	cam_fx = CAMERA_FX.new(cam)
	cam_fx.force_enabled = true
	_check("camera fx starts clean", cam.offset == Vector2.ZERO and cam.zoom == Vector2.ONE)
	cam_fx.kick(8)
	cam_fx.tick(0.0)
	_check("camera fx kicks offset", cam.offset.length() > 0.5)
	_check("camera fx pushes zoom 2% + overscan 1.5%", cam.zoom.x > 1.034 and cam.zoom.x <= 1.036)
	_check("camera fx overscan covers shake", absf(cam.offset.x) <= 12.0 and absf(cam.offset.y) <= 9.0
		and cam.zoom.x >= 1.015)
	var trauma_after_one: float = cam_fx.trauma()
	cam_fx.tick(0.4)
	_check("camera fx trauma decays", cam_fx.trauma() < trauma_after_one)
	cam_fx.tick(1.0)
	_check("camera fx settles to base", cam_fx.trauma() == 0.0 and cam.offset == Vector2.ZERO
		and cam.zoom == Vector2.ONE)
	cam_fx.kick(12)
	cam_fx.tick(0.016)
	_check("heavy kick stronger", cam_fx.trauma() > trauma_after_one)
	cam_fx.force_enabled = false
	SETTINGS.save_camera_fx(false)
	cam_fx._on = false
	cam_fx.tick(0.016)
	_check("camera fx toggle off resets", cam.offset == Vector2.ZERO and cam.zoom == Vector2.ONE)
	SETTINGS.save_camera_fx(true)

	# 3) 真實命中：A 出 Light1 打中 B，雙方同時停頓、停頓期間 _frame 不推進，停完再續
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.position = Vector2(400.0, 850.0)
	b.position = Vector2(482.0, 850.0)
	a.face_direction = 1.0
	b.face_direction = -1.0
	b._ai_cd = 9999.0
	a.hit_landed.connect(_on_landed)
	physics_frame.connect(_on_physics)

func _on_landed(frames: int, _dmg: int, _at: Vector2) -> void:
	if hit_seen:
		return
	hit_seen = true
	hit_frames = frames
	frozen_a = a._frame
	frozen_b = b._frame
	_check("hitstop fires with 4 frames", frames == 4)
	_check("attacker stopped", a.hitstop_frames() == frames)
	_check("victim stopped", b.hitstop_frames() == frames)
	_check("victim took damage", b.current_hp < b.max_hp)
	dealt = true

func _on_parry() -> void:
	parry_n += 1

func _on_physics() -> void:
	n += 1
	if n == 2:
		a.change_state("Light1")
	if hit_seen and not resumed:
		stop_waited += 1
		if stop_waited == 1:
			_check("attacker frame frozen during stop", a._frame == frozen_a)
			_check("victim frame frozen during stop", b._frame == frozen_b)
		if stop_waited == 3:
			_check("still frozen on third frozen frame", a._frame == frozen_a)
		if stop_waited >= 8 and a._frame > frozen_a:
			resumed = true
			_check("logic resumes after stop", true)

	# ---------- OPT-02：架招白閃／慢放、攻擊緩衝、受身無敵 ----------
	if n == 70 and not phase2:
		phase2 = true
		_check("hit landed at all", dealt)
		_check("player attack still damages", b.current_hp < b.max_hp)
		# 收掉第一階段的對手，避免後面的招式又打中
		b.position = Vector2(1880.0, 850.0)
		b.change_state("Idle")
		a.change_state("Idle")
		# 架招：進 Counter 應發信號、白閃啟動
		SETTINGS.save_parry_fx(true)
		a.parry_success.connect(_on_parry)
		a.change_state("Counter")
		_check("parry signal on counter", parry_n == 1)
		_check("parry flash starts white", a._flash_mat != null
			and float(a._flash_mat.get_shader_parameter("flash")) > 0.0)
		# 慢放：開關打開時壓倍率、reset 還原、關閉時不觸發
		SLOW_MO.force_enabled = true
		_check("slow mo triggers 0.4x", SLOW_MO.trigger() and is_equal_approx(Engine.time_scale, 0.4))
		_check("slow mo duration 150ms", SLOW_MO.remaining_ms() >= 120 and SLOW_MO.remaining_ms() <= 160)
		SLOW_MO.reset()
		_check("slow mo resets to 1.0", is_equal_approx(Engine.time_scale, 1.0))
		SETTINGS.save_parry_fx(false)
		_check("slow mo respects off switch", not SLOW_MO.trigger() and is_equal_approx(Engine.time_scale, 1.0))
		SETTINGS.save_parry_fx(true)
		# 緩衝衰減：6 → 5，且消耗後歸零
		a.change_state("Idle")
		a._atk_buf_light = 6
		a._tick_buffers()
		_check("attack buffer decays", a.attack_buffer_left("light") == 5)
		a._consume_light()
		_check("attack buffer consumed", a.attack_buffer_left("light") == 0)
		a.change_state("Light1")
		combo_started = true

	# 真實緩衝：Light1 第 3 幀按輕（早於第 8 幀取消窗口），應在第 8 幀自動接 Light2
	if combo_started and not combo_pressed and a._state == "Light1" and a._frame == 3:
		Input.action_press("p1_light")
		combo_pressed = true
		combo_release_n = n + 1
	if combo_pressed and n == combo_release_n:
		Input.action_release("p1_light")
	if a._state == "Light2":
		saw_light2 = true
	if combo_pressed and n == 96:
		_check("early light press buffered into Light2", saw_light2)

	# 受身：倒地按跳 → WakeUp＋6 幀無敵；無敵期間挨打不掉血
	if n == 100:
		a.change_state("Knockdown")
		hp_before_tech = a.current_hp
		tech_started = true
	if tech_started and not tech_pressed and a._state == "Knockdown" and a._frame == 2:
		Input.action_press("p1_jump")
		tech_pressed = true
		tech_release_n = n + 1
	if tech_pressed and n == tech_release_n:
		Input.action_release("p1_jump")
	if tech_pressed and not tech_checked and a._state == "WakeUp":
		tech_checked = true
		_check("knockdown jump techs to WakeUp", true)
		_check("tech grants 6 invuln", a.tech_invuln_frames() == 6)
		a.take_damage(100, -1.0)
		_check("tech invuln ignores damage", a.current_hp == hp_before_tech)
	# 失敗可追打：不按跳的倒地照常吃傷害
	if n == 115:
		a.change_state("Knockdown")
		hp_before_tech = a.current_hp
	if n == 118 and not fail_tech_checked:
		fail_tech_checked = true
		a.take_damage(100, -1.0)
		_check("no tech still punishable", a.current_hp == hp_before_tech - 100)
	if n >= 130:
		_check("tech invuln expired", a.tech_invuln_frames() == 0)
		SLOW_MO.force_enabled = false
		_finish()
