extends SceneTree
## 離屏截圖（不開可見視窗）：確認「扔石頭」在暗色畫面裡的大小、位置與可讀性。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_rock_preview.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const ROCK := preload("res://scripts/rock_projectile.gd")

var vp: SubViewport
var rock: Node2D
var frames: int = 0
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

	# 左邊投擲者、右邊被瞄準的武松，都用既有立繪，只為看石頭與人體的比例
	var thrower = load("res://scenes/RiggedFighter.tscn").instantiate()
	thrower.position = Vector2(340, 840)
	vp.add_child(thrower)
	thrower.process_mode = Node.PROCESS_MODE_DISABLED
	thrower.face_direction = 1.0
	thrower.get_node("Visual").play_action("Idle", {}, 1.0 / 60.0)

	var victim = load("res://scenes/RiggedFighter.tscn").instantiate()
	victim.position = Vector2(1560, 840)
	vp.add_child(victim)
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	victim.face_direction = -1.0
	victim.get_node("Visual").play_action("Idle", {}, 1.0 / 60.0)

	# 石頭擺在弧線頂點附近（投擲點 y≈820、飛越 1220px 的中段），驗證大小與明度
	rock = ROCK.new()
	vp.add_child(rock)
	rock.position = Vector2(940, 520)
	rock.rotation = 0.6
	rock.process_mode = Node.PROCESS_MODE_DISABLED

func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 4 and not captured:
		captured = true
		var img: Image = vp.get_texture().get_image()
		if img == null:
			print("CAPTURE FAIL null image")
			quit(1)
			return true
		img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		var err: int = img.save_png(DEST + "rock-preview.png")
		print("CAPTURE rock-preview.png err=", err)
		quit(0)
		return true
	return false
