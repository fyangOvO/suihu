extends SceneTree
## 離屏截圖：SCN-04 山神廟道具。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_scn04.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const SCN04 := "res://scenes/chapters/SCN_04_Temple.tscn"

var vp: SubViewport
var main: Node
var frames: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)
	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B4")
	main = load(SCN04).instantiate()
	vp.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 30:
		return false
	var img: Image = vp.get_texture().get_image()
	if img != null:
		img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		var err: int = img.save_png(DEST + "scn04-temple.png")
		print("CAPTURE scn04-temple.png err=", err)
	quit(0)
	return true
