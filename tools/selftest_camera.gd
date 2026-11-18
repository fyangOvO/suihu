extends SceneTree
## OPT-03 相機自測（無頭可跑）：平視預看 ±120、邊界 clamp、Boss 拉遠、水潭固定機位、階段微推。
## 用法：godot --headless --path <game> --script res://tools/selftest_camera.gd
## PASS 退出 0；FAIL 退出 1。

const CAMERA_FX := preload("res://scripts/camera_fx.gd")
const STAGE_BASE := preload("res://scripts/chapters/stage_base.gd")

var fails: Array = []
var cam: Camera2D
var follow: Node2D
var fx
var n: int = 0

class DummyFollow extends Node2D:
	var face_direction: float = 1.0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _ticks(count: int, delta: float) -> void:
	for i in range(count):
		fx.tick(delta)
		n += 1

func _initialize() -> void:
	root.size = Vector2i(1, 1)

	follow = DummyFollow.new()
	follow.position = Vector2(960, 820)
	root.add_child(follow)

	cam = Camera2D.new()
	cam.position = Vector2(960, 540)
	cam.zoom = Vector2(1.15, 1.15)
	root.add_child(cam)
	fx = CAMERA_FX.new(cam, follow)
	fx.force_enabled = true

	_check("base zoom kept", is_equal_approx(cam.zoom.x, 1.15))
	_check("base position kept", cam.position.is_equal_approx(Vector2(960, 540)))

	# 1) 站在中線：位置項為 0；朝向另補 20px 提前量
	follow.position = Vector2(960, 820)
	follow.face_direction = 0.0
	_ticks(20, 1.0 / 60.0)
	_check("center look is zero", absf(fx.look_offset()) < 1.0)
	_check("center camera stays home", absf(cam.position.x - 960.0) < 1.0)
	follow.face_direction = 1.0
	_ticks(30, 1.0 / 60.0)
	_check("facing bias leads 20px", absf(fx.look_offset() - 20.0) < 1.0)

	# 2) 玩家跑到最右：預看夾在 +120，機位跟著走但不露背景右邊
	follow.position = Vector2(1800, 820)
	follow.face_direction = 1.0
	_ticks(40, 1.0 / 60.0)
	_check("right look hits +120", absf(fx.look_offset() - 120.0) < 1.0)
	_check("camera follows right", cam.position.x > 1075.0)
	var view_w: float = 1920.0 / cam.zoom.x
	_check("right edge stays inside world", cam.position.x + view_w * 0.5 <= 1920.5)

	# 3) 玩家跑到最左：對稱
	follow.position = Vector2(120, 820)
	follow.face_direction = -1.0
	_ticks(40, 1.0 / 60.0)
	_check("left look hits -120", absf(fx.look_offset() + 120.0) < 1.0)
	_check("left edge stays inside world", cam.position.x - view_w * 0.5 >= -0.5)

	# 4) 水潭：關掉預看，機位鎖回中線
	fx.set_look_enabled(false)
	_ticks(20, 1.0 / 60.0)
	_check("pool lookahead off", absf(fx.look_offset()) < 0.01)
	_check("pool camera locked at 960", absf(cam.position.x - 960.0) < 0.01)
	fx.set_look_enabled(true)

	# 5) Boss 拉遠：1.15 × 1/1.1 ≈ 1.045，視野變寬、預看被邊界收窄
	cam.zoom = Vector2(1.15, 1.15) * (1.0 / 1.1)
	cam.position = Vector2(960, 540)
	fx.rebind(cam)
	fx.force_enabled = true
	follow.position = Vector2(1800, 820)
	_ticks(40, 1.0 / 60.0)
	_check("boss zoom is 10% wider", absf(cam.zoom.x - 1.15 / 1.1) < 0.002)
	var boss_view: float = 1920.0 / (1.15 / 1.1)
	var boss_max_x: float = 1920.0 - boss_view * 0.5
	_check("boss clamp keeps edge inside", cam.position.x <= boss_max_x + 0.5)
	_check("boss pan is narrower than 120", cam.position.x - 960.0 < 120.0)

	# 6) 階段微推：0.3s 內推近約 5%，之後回到基準
	fx.phase_push()
	_ticks(4, 0.05)   # 0.1s/0.15s 附近，正弦接近峰值
	_check("phase push bumps zoom", cam.zoom.x > 1.15 / 1.1 * 1.03)
	_ticks(8, 0.05)   # 收乾 0.3s
	_check("phase push settles back", absf(cam.zoom.x - 1.15 / 1.1) < 0.002)

	# 7) 震屏仍走 offset、不靠機位；關掉開關全部歸位
	fx.kick(12)
	_ticks(1, 1.0 / 60.0)
	_check("shake uses offset", cam.offset.length() > 0.5)
	_check("shake offset magnitude capped", absf(cam.offset.x) <= 12.01 and absf(cam.offset.y) <= 9.01)
	fx.force_enabled = false
	fx._on = false
	fx.tick(1.0 / 60.0)
	_check("settings off resets camera", cam.offset == Vector2.ZERO \
		and cam.zoom.is_equal_approx(Vector2(1.15 / 1.1, 1.15 / 1.1)) \
		and absf(cam.position.x - 960.0) < 0.01)

	# 8) 舞台設定：水潭固定、崗頂拉遠、其他場景吃預看
	var pool = load("res://scripts/chapters/scn_06_pool.gd").new()
	_check("pool stage disables lookahead", pool.camera_lookahead_enabled() == false)
	pool.free()
	var ridge = load("res://scripts/chapters/scn_05_ridge.gd").new()
	_check("ridge stage zooms out 10%", absf(ridge.camera_zoom_mul() - 1.0 / 1.1) < 0.0001)
	ridge.free()
	var trail = load("res://scripts/chapters/scn_02_trail.gd").new()
	_check("normal stage keeps lookahead", trail.camera_lookahead_enabled() == true)
	_check("normal stage keeps 1.15 base", is_equal_approx(trail.camera_zoom_mul(), 1.0))
	trail.free()
	_check("stage base zoom leaves 120px margin", 1920.0 - 1920.0 / STAGE_BASE.CAMERA_BASE_ZOOM >= 240.0)

	print("CAMERA_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails, " ticks=", n)
	quit(0 if fails.is_empty() else 1)
