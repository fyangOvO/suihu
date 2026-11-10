extends SceneTree
## 離屏截圖（不開可見視窗）：伥鬼死亡化青煙的中段moment，供目視確認煙霧顏色與覆蓋範圍。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_death_preview.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var fighter: CharacterBody2D
var frames: int = 0
var dying_at: int = -1
var captured: bool = false

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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(bg)

	var ground := ColorRect.new()
	ground.color = Color(0.13, 0.115, 0.10)
	ground.position = Vector2(0, 840)
	ground.size = Vector2(RES.x, RES.y - 840)
	ground.z_index = -10
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(ground)

	# 真地板，讓角色能落地站住
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(960, 870)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2400, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	vp.add_child(floor_body)

	fighter = load("res://scenes/RiggedFighter.tscn").instantiate()
	fighter.position = Vector2(960, 780)
	fighter.face_direction = -1.0
	vp.add_child(fighter)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 40:
		fighter._begin_death()          # 站定後開始化煙
		dying_at = frames
	if dying_at > 0 and not captured and frames - dying_at >= 26:
		captured = true
		var img: Image = vp.get_texture().get_image()
		if img == null:
			print("CAPTURE FAIL null image")
			quit(1)
			return true
		img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		var err: int = img.save_png(DEST + "death-mist-preview.png")
		print("CAPTURE death-mist-preview.png err=", err)
		quit(0)
		return true
	if frames > 120:
		print("CAPTURE timeout")
		quit(1)
		return true
	return false
