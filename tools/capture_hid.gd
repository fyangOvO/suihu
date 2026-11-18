extends SceneTree
## HID-01 / HID-05 離屏截圖：
##   hid01-absorb.png  Boss 死後靠近虎屍，酒氣補滿＋黑霧吸入
##   hid05-line.png    被絕命撲擊打死，虎台詞「你也是被放出來的」
## 用法：godot --path 'D:\水滸g\game' --resolution 1x1 --position -32000,-32000 --script res://tools/capture_hid.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)
const SCN05 := "res://scenes/chapters/SCN_05_Ridge.tscn"

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
	_spawn()

func _spawn() -> void:
	cm.set_beat("B7")
	current = load(SCN05).instantiate()
	vp.add_child(current)
	frames = 0

func _save(name: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image: ", name)
		quit(1)
		return
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	print("CAPTURE ", name, " err=", img.save_png(DEST + name))

func _process(_delta: float) -> bool:
	frames += 1
	match stage:
		0:
			if frames >= 4 and current.p2 != null:
				current.p2.take_damage(99999, 1.0)
				var cine = current.p2.get_node_or_null("BossDeathCine")
				if cine != null:
					cine.skip()   # 截圖不需要 3s 字幕過場
				stage = 1
				frames = 0
		1:
			if current.p2 != null and current.p2._death_done:
				current.p1.global_position = current.p2.global_position + Vector2(-110, 0)
				stage = 2
				frames = 0
			elif frames > 150:
				print("CAPTURE TIMEOUT boss death")
				quit(1)
				return true
		2:
			if frames >= 70:
				current.process_mode = Node.PROCESS_MODE_DISABLED
				_save("hid01-absorb.png")
				current.queue_free()
				stage = 3
				frames = 0
		3:
			if frames >= 3:
				_spawn()
				stage = 4
				frames = 0
		4:
			if frames >= 4:
				current.p1.last_hit_state = "BossDeathPounce"
				current.p1.take_damage(9999, 1.0)
				stage = 5
				frames = 0
		5:
			if frames >= 26:
				current.process_mode = Node.PROCESS_MODE_DISABLED
				_save("hid05-line.png")
				quit(0)
				return true
	if frames > 400:
		print("CAPTURE TIMEOUT stage=", stage)
		quit(1)
		return true
	return false
