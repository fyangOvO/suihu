extends SceneTree
## SCN-04 山神廟道具與眨眼彩蛋自測。

const SCN04 := "res://scenes/chapters/SCN_04_Temple.tscn"

var main: Node
var fails: Array[String] = []
var frame: int = 0

func _check(label: String, ok: bool) -> void:
	if not ok:
		fails.append(label)
	print("CHECK ", label, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B4")
	main = load(SCN04).instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if frame == 5:
		var bg := main.get_node_or_null("Background")
		_check("Background exists", bg != null)
		if bg == null:
			quit(0)
			return true
		_check("TempleProps exists", bg.get_node_or_null("TempleProps") != null)
		_check("Altar exists", bg.get_node_or_null("TempleProps/Altar") != null)
		_check("IdolBody exists", bg.get_node_or_null("TempleProps/IdolBody") != null)
		_check("left eye exists", bg.get_node_or_null("TempleProps/IdolEyeL") != null)
		_check("right eye exists", bg.get_node_or_null("TempleProps/IdolEyeR") != null)
		_check("candle exists", bg.get_node_or_null("TempleProps/Candle360") != null)
		_check("temple banner exists", bg.get_node_or_null("TempleProps/TempleBanner548") != null)
		main._blink_once()
		_check("blink once", main._blink_count == 1)
		main._blink_once()
		_check("blink not repeated", main._blink_count == 1)
		print("SCN04_TEMPLE_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails)
		quit(0)
		return true
	return false
