extends SceneTree
## 離屏截圖：主菜單 + SCN-01 酒肆對話框，確認 1920×1080 版式。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_flow.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const STORY := preload("res://data/story_beats.gd")

var vp: SubViewport
var current: Node = null
var frames: int = 0
var phase: int = 0

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
	_show_menu()

func _show_menu() -> void:
	current = load("res://scenes/MainMenu.tscn").instantiate()
	vp.add_child(current)
	frames = 0

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
	if phase == 0 and frames >= 6:
		_capture("flow-main-menu.png")
		current.queue_free()
		phase = 1
		frames = 0
	elif phase == 1 and frames >= 2:
		current = load("res://scenes/chapters/SCN_01_Inn.tscn").instantiate()
		vp.add_child(current)
		phase = 2
		frames = 0
	elif phase == 2 and frames >= 3:
		current.process_mode = Node.PROCESS_MODE_DISABLED
		var dlg = current.get_node_or_null("DialogueUI")
		if dlg == null:
			for child in current.get_children():
				if child is CanvasLayer and child.get_script() != null and String(child.get_script().resource_path).ends_with("dialogue_ui.gd"):
					dlg = child
		if dlg != null:
			dlg.visible = true
			dlg.play(STORY.lines("B1"))
			dlg._process(1.4)
		phase = 3
		frames = 0
	elif phase == 3 and frames >= 4:
		_capture("flow-scn01-dialogue.png")
		quit(0)
		return true
	return false
