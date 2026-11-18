extends SceneTree
## OPT-03 取景目視驗證（離屏渲染，主視窗 1×1 移螢幕外）：
## SCN-02 把武松推到最右／最左，看預看 120px 時背景有沒有露邊；
## SCN-06 確認水潭機位鎖死中線；SCN-05 確認 Boss 拉遠 10% 後仍無黑邊。
## 用法：<console.exe> --path <game> --resolution 1x1 --position -32000,-32000 --script res://tools/capture_camera_framing.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)

var vp: SubViewport
var cm: Node
var stage: Node = null
var step: int = 0
var wait: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)
	cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)

	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	_load_stage("res://scenes/chapters/SCN_02_Trail.tscn", "B2")

func _load_stage(path: String, beat: String) -> void:
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	cm.set_beat(beat)
	stage = load(path).instantiate()
	vp.add_child(stage)
	wait = 8

func _quiet() -> void:
	# 截圖只看世界，HUD／對話框會擋住左右邊緣
	if stage.get("hud") != null:
		stage.get("hud").visible = false
	if stage.get("dialogue") != null:
		stage.get("dialogue").visible = false

func _hold(frames: int) -> void:
	wait = frames

func _process(_delta: float) -> bool:
	if wait > 0:
		wait -= 1
		if wait == 0:
			_advance()
		return false
	_advance()
	return false

func _advance() -> void:
	if stage == null:
		quit(0)
		return
	var p1 = stage.get("p1")
	var cam: Camera2D = stage.get("camera")
	match step:
		0:
			_quiet()
			stage.get("_cam_fx").force_enabled = true
			if stage.get("p2") != null:
				stage.get("p2").set_physics_process(false)
			p1.global_position = Vector2(1800, 820)
			step = 1
			_hold(120)
		1:
			_capture("camera-look-right.png")
			print("FRAME right cam_x=", cam.position.x, " zoom=", cam.zoom.x)
			p1.global_position = Vector2(120, 820)
			step = 2
			_hold(120)
		2:
			_capture("camera-look-left.png")
			print("FRAME left cam_x=", cam.position.x, " zoom=", cam.zoom.x)
			step = 3
			_load_stage("res://scenes/chapters/SCN_06_Pool.tscn", "B8")
		3:
			_quiet()
			_capture("camera-pool-fixed.png")
			print("FRAME pool cam_x=", cam.position.x, " zoom=", cam.zoom.x)
			step = 4
			_load_stage("res://scenes/chapters/SCN_05_Ridge.tscn", "B7")
		4:
			_quiet()
			step = 5
			_hold(10)
		5:
			_capture("camera-boss-zoom.png")
			print("FRAME boss cam_x=", cam.position.x, " zoom=", cam.zoom.x)
			quit(0)

func _capture(file_name: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image ", file_name)
		return
	print("CAPTURE ", file_name, " err=", img.save_png(DEST + file_name))
