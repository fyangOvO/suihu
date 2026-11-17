extends SceneTree
## OPT-02 架招白閃目視驗證（離屏渲染，不開可見視窗）：
## 一切渲染在 SubViewport（1280×720）內完成，主視窗 1×1 並移到螢幕外。
## 產出 docs/preview/parry-flash-on.png（白閃第 1 幀）／parry-flash-off.png（5 幀後恢復）。
## 用法：<console.exe> --path <game> --resolution 1x1 --position -32000,-32000 --script res://tools/capture_parry_flash.gd

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1280, 720)
const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const TEST_CFG := "user://selftest_parry_capture.cfg"

var vp: SubViewport
var fighter: CharacterBody2D
var started: bool = false
var step: int = 0
var wait: int = 0

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)
	SETTINGS.set_path_for_test(TEST_CFG)
	SETTINGS.save_parry_fx(true)

	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.size = Vector2(RES)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(bg)

	fighter = load("res://scenes/RiggedFighter.tscn").instantiate()
	fighter.position = Vector2(640, 640)
	fighter.is_player1 = true
	vp.add_child(fighter)

func _process(_delta: float) -> bool:
	if not started:
		# 首幀後 _ready 才跑完，此時切狀態才不會被吞
		if fighter._visual == null:
			return false
		started = true
		# 停掉角色自己的 _physics_process：否則它在幾幀內把白閃 tick 光，截不到最亮那幀
		fighter.process_mode = Node.PROCESS_MODE_DISABLED
		fighter.change_state("Idle")
		fighter._trigger_parry()
		wait = 1
		return false
	if wait > 0:
		wait -= 1
		return false
	if step == 0:
		_capture("parry-flash-on.png")
		for i in range(6):
			fighter._tick_flash()
		step = 1
		wait = 1
		return false
	if step == 1:
		_capture("parry-flash-off.png")
		SETTINGS.clear()
		SETTINGS.reset_path()
		quit(0)
		return true
	return false

func _capture(file_name: String) -> void:
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image ", file_name)
		return
	var err: int = img.save_png(DEST + file_name)
	print("CAPTURE ", file_name, " err=", err,
		" flash=", fighter._flash_mat.get_shader_parameter("flash") if fighter._flash_mat != null else "none")
