extends SceneTree
## 離屏截圖：BOS-10 擊殺演出 1.5s 幀（水潭字幕），確認全屏遮罩與字幕排版。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_boss_death_cine.gd

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
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.change_state("BossIdle")
	boss._apply_anim_dir()
	boss.get_node("Visual").play_action("BossIdle", boss._spec("BossIdle"), 0.0)

	var cine: CanvasLayer = boss.get_node("BossDeathCine")
	cine.set_process(false)
	cine.play()
	cine._process(1.5)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image")
		quit(1)
		return true
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + "boss-death-cine.png")
	print("CAPTURE boss-death-cine.png err=", err)
	quit(0)
	return true
