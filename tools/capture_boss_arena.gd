extends SceneTree
## 離屏截圖：SCN-05 崗頂 Boss 競技場，確認 Boss 與武松同場比例、HUD 與背景。
## 用法：godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_boss_arena.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1920, 1080)
const OUT := Vector2i(960, 540)

var vp: SubViewport
var arena: Node2D
var frames: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)

	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	arena = load("res://scenes/BossArena.tscn").instantiate()
	vp.add_child(arena)
	# 進樹後再凍結，避免 _ready 把 process 重新打開
	var p1 = arena.get_node("P1")
	var boss = arena.get_node("P2")
	p1.process_mode = Node.PROCESS_MODE_DISABLED
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	p1.change_state("Idle")
	p1._apply_anim_dir()
	p1.get_node("Visual").play_action("Idle", p1._spec("Idle"), 0.0)
	boss.change_state("BossIdle")
	boss._apply_anim_dir()
	boss.get_node("Visual").play_action("BossIdle", boss._spec("BossIdle"), 0.0)

func _process(delta: float) -> bool:
	frames += 1
	arena.get_node("P1/Visual").tick(delta)
	arena.get_node("P2/Visual").tick(delta)
	if frames < 6:
		return false
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image")
		quit(1)
		return true
	img.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + "boss-arena.png")
	print("CAPTURE boss-arena.png err=", err)
	quit(0)
	return true
