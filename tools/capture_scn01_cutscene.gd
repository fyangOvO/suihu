extends SceneTree
## 離屏截圖：SCN-01 酒肆演出（喝酒中 / 燈滅尾影）。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_scn01_cutscene.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var current: Node
var cm
var frames: int = 0
var got_drink: bool = false
var got_tail: bool = false

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
	cm.set_beat("B1")
	current = load("res://scenes/chapters/SCN_01_Inn.tscn").instantiate()
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
	if frames == 3 and current.dialogue != null and current.dialogue.is_active():
		current.dialogue.close()
		print("DIALOGUE CLOSED")
	if current._phase == "drink" and current._drink_round == 0 and current._phase_t > 0.55 and not got_drink:
		got_drink = true
		print("PHASE drink t=", current._phase_t, " action=", current._drink_action)
		_save("flow-scn01-drink.png")
	if current._phase == "lamp" and current._tail_shown and current._phase_t > 0.75 and not got_tail:
		got_tail = true
		print("PHASE lamp tail t=", current._phase_t,
			" energy=", current._lamp_light.energy,
			" glow=", current._lamp_glow.modulate.a,
			" flame=", current._lamp_flame.modulate.a,
			" mod=", current._canvas_mod.color)
		_save("flow-scn01-tail.png")
	if got_drink and got_tail:
		quit(0)
		return true
	if frames > 700:
		print("CAPTURE TIMEOUT phase=", current._phase, " t=", current._phase_t, " round=", current._drink_round)
		quit(1)
		return true
	return false
