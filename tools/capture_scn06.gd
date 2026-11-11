extends SceneTree
## 離屏截圖：SCN-06 水潭倒影與虎屍剪影。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_scn06.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const SCN06 := "res://scenes/chapters/SCN_06_Pool.tscn"

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
	cm.set_beat("B9")
	main = load(SCN06).instantiate()
	vp.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames > 4 and main.dialogue.is_active():
		main.dialogue.close()
	if frames < 20:
		return false
	var img: Image = vp.get_texture().get_image()
	if img != null:
		img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		var err: int = img.save_png(DEST + "scn06-pool.png")
		print("CAPTURE scn06-pool.png err=", err)
	quit(0)
	return true
