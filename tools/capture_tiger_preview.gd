extends SceneTree
## 離屏截圖：吊睛小虎站立幀，確認 512x640 幀在場景裡的比例、腳位與色調。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_tiger_preview.gd

const DATA := preload("res://data/action_frame_data.gd")
const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var tiger: CharacterBody2D
var frames: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)

	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.065, 0.06)
	bg.size = Vector2(RES)
	bg.z_index = -20
	vp.add_child(bg)

	var ground := ColorRect.new()
	ground.color = Color(0.13, 0.115, 0.10)
	ground.position = Vector2(0, 850)
	ground.size = Vector2(RES.x, RES.y - 850)
	ground.z_index = -10
	vp.add_child(ground)

	tiger = load("res://scenes/Tiger.tscn").instantiate()
	tiger.position = Vector2(960, 850)
	vp.add_child(tiger)
	# 必須進樹之後才關，否則進樹時會被重新啟用
	tiger.process_mode = Node.PROCESS_MODE_DISABLED
	tiger.change_state("TigerIdle")
	tiger._apply_anim_dir()
	tiger.get_node("Visual").play_action("TigerIdle", DATA.spec("TigerIdle"), 0.0)

func _process(delta: float) -> bool:
	frames += 1
	tiger.get_node("Visual").tick(delta)
	if frames < 6:
		return false
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image")
		quit(1)
		return true
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + "tiger-preview.png")
	print("CAPTURE tiger-preview.png err=", err)
	quit(0)
	return true
