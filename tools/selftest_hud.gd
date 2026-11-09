extends SceneTree
## 酒氣條 HUD 無頭自測：驗證 P1Wine 數值跟隨 wine_gauge、滿氣提示顯隱。
## 沿用 selftest_hitbox 生命週期：_initialize 掛節點，斷言在 physics_frame 回調執行（此時 _ready 已跑）。
## 關閉戰鬥自動調度，僅手動調用 main._process，避免 AI 戰幹擾。
## 用法：godot --headless --path <game> --script res://tools/selftest_hud.gd
## PASS 退出 0；FAIL 退出 1。

var main: Node2D
var p1: CharacterBody2D
var bar: ProgressBar
var hint: Label
var n: int = 0
var fails: Array = []

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	main = load("res://scenes/MainRigged.tscn").instantiate()
	root.add_child(main)
	p1 = main.get_node("P1")
	main.get_node("P2").set_physics_process(false)
	p1.set_physics_process(false)
	main.set_process(false)   # 關閉引擎自動 _process，本腳本手動驅動同步
	physics_frame.connect(_on_frame)

func _on_frame() -> void:
	n += 1
	if n != 2:
		return
	bar = main.get_node_or_null("HUD/P1Wine")
	hint = main.get_node_or_null("HUD/P1SuperHint")

	_check("HUD/P1Wine node exists", bar != null)
	_check("HUD/P1SuperHint node exists", hint != null)

	p1.wine_gauge = 0.0
	main._process(0.016)
	_check("wine=0 hint hidden", hint.visible == false)
	_check("wine=0 bar empty", bar.value < 1.0)

	p1.wine_gauge = 100.0
	main._process(0.016)
	_check("wine=100 bar full", bar.value >= 99.9)
	_check("wine=100 hint visible", hint.visible == true)

	p1.wine_gauge = 0.0
	main._process(0.016)
	_check("wine drained hint hidden again", hint.visible == false)

	# ---- 醉打（RB/U）冷卻提示 ----
	var drunk_hint: Label = main.get_node_or_null("HUD/P1DrunkHint")
	_check("HUD/P1DrunkHint node exists", drunk_hint != null)

	p1._drunk_cd = 4.0
	main._process(0.016)
	_check("drunk cooling shows countdown", drunk_hint.text.contains("冷卻"))
	_check("drunk cooling text has seconds", drunk_hint.text.contains("4.0s"))
	_check("drunk cooling is greyed", drunk_hint.modulate.r < 0.6 and drunk_hint.modulate.g < 0.6)

	p1._drunk_cd = 0.0
	main._process(0.016)
	_check("drunk ready shows ready text", drunk_hint.text.contains("可發"))
	_check("drunk ready is not greyed", drunk_hint.modulate.r >= 0.6)

	if fails.is_empty():
		print("HUD_SELFTEST result=PASS")
		quit(0)
	else:
		print("HUD_SELFTEST FAIL count=", fails.size(), " -> ", fails)
		quit(1)
