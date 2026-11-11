extends SceneTree
## 離屏截圖：猛虎 Boss idle 幀，確認 768×768 幀在場景裡的比例、腳位與色調。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_boss_preview.gd

const DATA := preload("res://data/action_frame_data.gd")
const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var boss: CharacterBody2D
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

	boss = load("res://scenes/Boss.tscn").instantiate()
	boss.position = Vector2(960, 850)
	vp.add_child(boss)
	# 必須進樹之後才關，否則進樹時會被重新啟用
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.change_state("BossIdle")
	boss._apply_anim_dir()
	boss.get_node("Visual").play_action("BossIdle", DATA.spec("BossIdle"), 0.0)

func _process(delta: float) -> bool:
	frames += 1
	boss.get_node("Visual").tick(delta)
	if frames < 6:
		return false
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image")
		quit(1)
		return true
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + "boss-preview.png")
	print("CAPTURE boss-preview.png err=", err)
	quit(0)
	return true
