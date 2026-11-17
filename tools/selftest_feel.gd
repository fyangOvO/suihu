extends SceneTree
## OPT-01 打擊感自測（無頭可跑）：命中停頓幀數映射、停頓只凍結邏輯、鏡頭 trauma／微推衰減、設置開關持久化。
## 用法：godot --headless --path <game> --script res://tools/selftest_feel.gd
## PASS 退出 0；FAIL 退出 1。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const CAMERA_FX := preload("res://scripts/camera_fx.gd")
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
	if n >= 70:
		_check("hit landed at all", dealt)
		_check("player attack still damages", b.current_hp < b.max_hp)
		_finish()
