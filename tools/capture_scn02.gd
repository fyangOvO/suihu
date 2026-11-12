extends SceneTree
## 離屏截圖：SCN-02 山道伥鬼登場（B3）與教學提示。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_scn02.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var current: Node = null
var cm
var frames: int = 0
var stage: int = 0

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

func _save(name: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image: ", name)
		quit(1)
		return
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + name)
	print("CAPTURE ", name, " err=", err)

func _process(_delta: float) -> bool:
	frames += 1
	if stage == 0 and frames >= 2 and current.p2 != null:
		# 凍住 AI，保留入場站位；迷霧與聚焦框仍可淡入。
		current.p2.set_physics_process(false)
		stage = 1
		frames = 0
	elif stage == 1 and frames >= 22:
		current.process_mode = Node.PROCESS_MODE_DISABLED
		_save("flow-scn02-corpse.png")
		current._tutorial_t = 2.25
		current.process_mode = Node.PROCESS_MODE_INHERIT
		stage = 2
		frames = 0
	elif stage == 2 and frames >= 5:
		current.process_mode = Node.PROCESS_MODE_DISABLED
		_save("flow-scn02-tutorial.png")
		quit(0)
		return true
	if frames > 200:
		print("CAPTURE TIMEOUT stage=", stage)
		quit(1)
		return true
	return false
