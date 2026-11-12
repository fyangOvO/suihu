extends SceneTree
## 離屏截圖：暫停、設置、死亡重開、章末結算與 Boss 條。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_ui_shell.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const SCN01 := "res://scenes/chapters/SCN_01_Inn.tscn"
const SCN05 := "res://scenes/chapters/SCN_05_Ridge.tscn"

var vp: SubViewport
var main: Node
var shell: CanvasLayer
var frames: int = 0
var stage: int = 0

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
	cm.set_beat("B1")
	main = load(SCN01).instantiate()
	vp.add_child(main)

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
	if stage == 0 and frames >= 5:
		shell = main.get_node_or_null("GameShell")
		shell.show_pause()
		stage = 1
		frames = 0
	elif stage == 1 and frames >= 3:
		_capture("ui-pause.png")
		shell.get_node("ShellRoot/PausePanel").visible = false
		shell.get_node("ShellRoot/SettingsPanel").visible = true
		stage = 2
		frames = 0
	elif stage == 2 and frames >= 2:
		_capture("ui-settings.png")
		shell._on_resume()
		shell.show_death(true)
		stage = 3
		frames = 0
	elif stage == 3 and frames >= 3:
		_capture("ui-death.png")
		shell._on_resume()
		shell.show_summary({"碎銀": 3, "小虎爪": 2, "伥鬼的木牌": 1})
		stage = 4
		frames = 0
	elif stage == 4 and frames >= 3:
		_capture("ui-summary.png")
		shell._on_resume()
		main.queue_free()
		root.get_node("ChapterManager").set_beat("B7")
		main = load(SCN05).instantiate()
		vp.add_child(main)
		stage = 5
		frames = 0
	elif stage == 5 and frames >= 8:
		_capture("ui-boss.png")
		quit(0)
		return true
	return false
