extends SceneTree
## 離屏截圖（不開視窗）：一切渲染都發生在 SubViewport 裡，主視窗保持 1x1 並移出螢幕外。
## 逐段觸發刀光／酒氣並存 PNG，供目視與對照圖拼接。
## 用法（二選一，優先第一條；若 Vulkan 無窗渲染失敗再用第二條）：
##   godot --display-driver headless --rendering-driver vulkan --script res://tools/capture_fx_preview.gd
##   godot --path <game> --resolution 16x16 --position -32000,-32000 --script res://tools/capture_fx_preview.gd
## 控制器物理關閉，僅手動切狀態；姿態手動推進，特效層按 60fps 自走，每次觸發後固定 +6 幀截圖。

const DEST := "D:/水滸g/docs/preview/"
const RES := Vector2i(1280, 720)
const DATA := preload("res://data/action_frame_data.gd")
const PLAN := [
	{"state": "Light1", "file": "fx-light.png"},
	{"state": "Heavy", "file": "fx-heavy.png"},
	{"state": "CmdUp", "file": "fx-rising.png"},
	{"state": "Awaken", "file": "fx-awaken.png"},
	{"state": "Super", "file": "fx-super.png"},
	{"state": "CmdDrunk", "file": "fx-drunk.png"},
]

var vp: SubViewport
var fighter: CharacterBody2D
var visual: Sprite2D
var fx: Node2D
var idx: int = 0
var wait: int = 0
var captured: bool = false
var started: bool = false

func _initialize() -> void:
	# 主視窗縮到 1x1 並推到螢幕外，避免任何可見視窗干擾
	root.size = Vector2i(1, 1)
	root.position = Vector2i(-32000, -32000)

	vp = SubViewport.new()
	vp.size = RES
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.065, 0.06)
	bg.size = Vector2(RES)
	bg.z_index = -20   # 必須低於角色 aura 的 -1，否則會把輝光整塊蓋掉
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(bg)

	fighter = load("res://scenes/RiggedFighter.tscn").instantiate()
	fighter.position = Vector2(300, 600)
	vp.add_child(fighter)
	# 徹底凍結：process_mode 關閉後子節點（含 Fx）一併停擺，位置不再受重力影響
	fighter.process_mode = Node.PROCESS_MODE_DISABLED
	visual = fighter.get_node("Visual")
	fx = fighter.get_node("Fx")

func _process(_delta: float) -> bool:
	if not started:
		# 首幀才 stage：節點 _ready 會把狀態重置成 Idle，初始化階段切的狀態會被吞掉
		started = true
		_stage(PLAN[0]["state"])
		return false
	# 控制器與 Fx 都被凍結，這裡手動推進姿態序列與特效時鐘（每幀 = 1 邏輯幀）
	var st: String = fighter._play_state()
	visual.play_action(st, DATA.spec(st), 1.0 / 60.0)
	fx._physics_process(1.0 / 60.0)
	if wait > 0:
		wait -= 1
		return false
	if not captured:
		_capture(PLAN[idx]["file"])
		captured = true
		wait = 6                # 兩張之間留幾幀，避免上一張殘影
		return false
	idx += 1
	if idx >= PLAN.size():
		quit(0)
		return true
	_stage(PLAN[idx]["state"])
	return false

## 切到目標狀態，並把等待時間設成「startup 幀數 + 4」——刀光在 active 第一幀之後才截
func _stage(state_name: String) -> void:
	fighter.change_state("Idle")
	if state_name == "Awaken":
		fighter.wine_gauge = 100.0
		fighter._fx_sync()
		wait = 6
	else:
		if state_name == "CmdDrunk":
			fighter.wine_gauge = 50.0
		fighter.change_state(state_name)
		if state_name == "Super":
			fighter.wine_gauge = 100.0
		fighter._fx_sync()
		var lg: Dictionary = DATA.spec(state_name).get("logic", {})
		wait = int(lg.get("startup", 0)) + 4
	captured = false

func _capture(file_name: String) -> void:
	print("DBG ", file_name, " vp=", vp.size, " canvas_xf=", vp.canvas_transform,
		" pos=", fighter.position, " vis_scale=", visual.scale, " root_size=", root.size)
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL null image ", file_name)
		return
	img.resize(RES.x, RES.y, Image.INTERPOLATE_LANCZOS)
	var err: int = img.save_png(DEST + file_name)
	print("CAPTURE ", file_name, " err=", err, " visible slash=", fighter.get_node("Fx/SlashCore").visible)
