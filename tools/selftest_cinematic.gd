extends SceneTree
## 覺醒過場演出無頭自測：
##  A. 場景演出節點齊備（鏡頭/暗角/刀光/白閃）
##  B. P1 進入 Super 即啟動：對手定格、推鏡、壓暗
##  C. 刀光掃過與定格白閃在時間窗內有效
##  D. 演出結束（超時/離開 Super）完整復位
## 注意：節點 _ready 在 _initialize 階段尚未執行，斷言須延到首個 process_frame。
## 用法：godot --headless --path <game> --script res://tools/selftest_cinematic.gd
## PASS 退出 0；FAIL 退出 1。

const SCENE := "res://scenes/MainRigged.tscn"
var fails: Array = []
var main_node = null
var _ran: bool = false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	main_node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(main_node)
	process_frame.connect(_on_first_frame)

func _on_first_frame() -> void:
	if _ran:
		return
	_ran = true
	main_node.set_process(false)        # 演出由斷言手動逐段推進

	var cam: Camera2D = main_node.get_node_or_null("BattleCam")
	var dim: ColorRect = main_node.get_node_or_null("Cinematic/Dim")
	var slash: ColorRect = main_node.get_node_or_null("Cinematic/Slash")
	var flash: ColorRect = main_node.get_node_or_null("Cinematic/Flash")
	var p1 = main_node.get_node("P1")
	var p2 = main_node.get_node("P2")
	p1.set_physics_process(false)
	p2.set_physics_process(false)

	# ---- A. 節點齊備 ----
	_check("cinematic camera exists", cam != null)
	_check("cinematic dim/slash/flash exist", dim != null and slash != null and flash != null)
	_check("camera starts at home", cam != null and cam.position == Vector2(960, 540) and cam.zoom == Vector2(1, 1))

	# ---- B. 啟動 ----
	p1.wine_gauge = 100.0
	p1.change_state("Super")
	main_node._update_cinematic(0.16)
	_check("cinematic starts on Super", main_node._cine_active)
	_check("opponent frozen during cinematic", not p2.is_physics_processing())

	main_node._update_cinematic(0.10)
	main_node._update_cinematic(0.10)
	main_node._update_cinematic(0.05)
	_check("camera pushes in", cam.zoom.x > 1.10)
	_check("camera follows P1", cam.position.x < 900.0)
	_check("dim fades in", dim.modulate.a > 0.30)

	# ---- C. 刀光 + 白閃 ----
	main_node._update_cinematic(0.05)
	main_node._update_cinematic(0.05)
	_check("slash sweeps in", slash.modulate.a > 0.1)
	_check("freeze flash visible", flash.modulate.a > 0.1)

	# ---- D. 復位 ----
	main_node._update_cinematic(1.00)
	main_node._update_cinematic(1.00)
	_check("cinematic ends", not main_node._cine_active)
	_check("camera restored", cam.position == Vector2(960, 540) and cam.zoom == Vector2(1, 1))
	_check("dim cleared", dim.modulate.a == 0.0)
	_check("slash cleared", slash.modulate.a == 0.0)
	_check("flash cleared", flash.modulate.a == 0.0)
	_check("opponent unfrozen", p2.is_physics_processing())

	# 離開 Super 提前中斷
	p1.wine_gauge = 100.0
	p1.change_state("Super")
	main_node._update_cinematic(0.16)
	_check("cinematic restarts", main_node._cine_active)
	p1.change_state("Idle")
	main_node._update_cinematic(0.10)
	_check("leaving Super aborts cinematic", not main_node._cine_active)
	_check("abort restores camera", cam.zoom == Vector2(1, 1) and cam.position == Vector2(960, 540))

	if fails.is_empty():
		print("CINEMATIC_SELFTEST result=PASS")
		quit(0)
	else:
		print("CINEMATIC_SELFTEST FAIL count=", fails.size(), " -> ", fails)
		quit(1)
