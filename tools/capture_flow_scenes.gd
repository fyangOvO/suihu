extends SceneTree
## 離屏截圖：SCN-05 崗頂 Boss 戰 + SCN-06 水潭對話，確認章節場景 HUD 與版式。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_flow_scenes.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const STORY := preload("res://data/story_beats.gd")

var vp: SubViewport
var current: Node = null
var cm
var frames: int = 0
var phase: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)
	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B7")
	current = load("res://scenes/chapters/SCN_05_Ridge.tscn").instantiate()
	vp.add_child(current)

func _capture(name: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image for ", name)
		return
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + name)
	print("CAPTURE ", name, " err=", err)

func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames >= 8:
		_capture("flow-scn05-ridge.png")
		current.queue_free()
		phase = 1
		frames = 0
	elif phase == 1 and frames >= 2:
		cm.set_beat("B8")
		current = load("res://scenes/chapters/SCN_06_Pool.tscn").instantiate()
		vp.add_child(current)
		phase = 2
		frames = 0
	elif phase == 2 and frames >= 3:
		current.process_mode = Node.PROCESS_MODE_DISABLED
		var dlg = current.get_node_or_null("DialogueUI")
		if dlg != null:
			dlg.play(STORY.lines("B8"))
			dlg._process(1.4)
		phase = 3
		frames = 0
	elif phase == 3 and frames >= 4:
		_capture("flow-scn06-pool.png")
		quit(0)
		return true
	return false
