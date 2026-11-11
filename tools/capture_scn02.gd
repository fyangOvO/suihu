extends SceneTree
## 離屏截圖：SCN-02 山道伥鬼實體（B3 開場，不含 B2 對話）。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_scn02.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var current: Node = null
var cm
var frames: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)
	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_beat("B3")
	current = load("res://scenes/chapters/SCN_02_Trail.tscn").instantiate()
	vp.add_child(current)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 6:
		current.process_mode = Node.PROCESS_MODE_DISABLED
	elif frames == 10:
		var img: Image = vp.get_texture().get_image()
		if img == null:
			print("CAPTURE FAIL null image")
			quit(1)
			return true
		img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		var err: int = img.save_png(DEST + "flow-scn02-corpse.png")
		print("CAPTURE flow-scn02-corpse err=", err)
		quit(0)
		return true
	return false
