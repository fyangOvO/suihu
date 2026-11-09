extends SceneTree
## 玩法补全無頭自測（可 headless 運行）：
##  A. 蹲防/站防/空防差異化減傷與空防不浮空
##  B. Counter 招架幀無敵、出無敵後受擊
##  C. Super/Counter 數據窗口（傷害、總幀、無敵區間）
##  D. 防禦狀態 -> _defense 映射；Super 結束清酒氣
## 用法：godot --headless --path <game> --script res://tools/selftest_gameplay.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
var fails: Array = []
var b = null
var _phase: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	var a = packed.instantiate()
	b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	b._ai_cd = 9999.0
	a.set_physics_process(false)   # 只用 A 做對手，不讓它參與物理
	b.is_player1 = true            # 關閉 P2 AI，避免斷言期間被 AI 改狀態

	# ---- A. 防禦減傷分化（直接調用 on_blocked）----
	b.current_hp = 800
	b._defense = "crouch"
	b.on_blocked(100, 1.0, 0.0)
	_check("crouch-block takes 35%", b.current_hp == 800 - int(round(100.0 * 0.35)))

	b.current_hp = 800
	b._defense = "stand"
	b.on_blocked(100, 1.0, 0.0)
	_check("stand-block takes 50%", b.current_hp == 800 - 50)

	b.current_hp = 800
	b._defense = "air"
	b.velocity = Vector2(0.0, -120.0)
	b.on_blocked(100, 1.0, 300.0)
	_check("air-block takes 40%", b.current_hp == 800 - int(round(100.0 * 0.4)))
	_check("air-block keeps downward (no launch)", b.velocity.y <= 0.0)

	# ---- B. Counter 招架無敵 ----
	b.current_hp = 800
	b.change_state("Counter")
	b._frame = 0
	b.take_damage(100, 1.0, 0.0)
	_check("Counter startup frame0 invulnerable", b.current_hp == 800)
	b.change_state("Counter")
	b._frame = 7
	b.take_damage(100, 1.0, 0.0)
	_check("Counter after invuln can take damage", b.current_hp == 700)

	# ---- C. 數據窗口 ----
	var sup: Dictionary = DATA.spec("Super")
	_check("Super damage 320", int(sup.get("damage", 0)) == 320)
	_check("Super total 108 frames", DATA.total_frames(sup) == 108)
	_check("Super invuln 0..108", DATA.is_invulnerable(sup, 0) and DATA.is_invulnerable(sup, 107) and not DATA.is_invulnerable(sup, 108))
	var ctr: Dictionary = DATA.spec("Counter")
	_check("Counter damage 120", int(ctr.get("damage", 0)) == 120)
	_check("Counter startup active window", DATA.is_active_frame(ctr, 6) and not DATA.is_active_frame(ctr, 5) and not DATA.is_active_frame(ctr, 10))
	_check("CrouchBlock loop posture", bool(DATA.spec("CrouchBlock").get("loop", false)))
	_check("AirBlock loop posture", bool(DATA.spec("AirBlock").get("loop", false)))

	# ---- D. 狀態映射 + Super 結束清氣 ----
	b.change_state("CrouchBlock")
	_check("CrouchBlock->crouch defense", b._defense == "crouch" and b.is_blocking)
	b.change_state("AirBlock")
	_check("AirBlock->air defense", b._defense == "air" and b.is_blocking)
	b.change_state("Block")
	_check("Block->stand defense", b._defense == "stand" and b.is_blocking)
	b.change_state("Idle")
	_check("Idle clears defense", b._defense == "none" and not b.is_blocking)
	b.wine_gauge = 100.0
	b.change_state("Super")
	b.change_state("Idle")
	_check("Super ends with wine drained", b.wine_gauge == 0.0)

	# ---- E. 方向指令緩衝（數字小鍵盤語義，相對朝向）----
	b._dir_history = ["2", "1", "4"]
	_check("214 down-back-back recognized", b._has_214())
	b._dir_history = ["4", "1", "2"]
	_check("214 reversed rejected", not b._has_214())
	b._dir_history = ["2", "5", "1", "5", "4"]
	_check("214 ignores neutral gaps", b._has_214())
	b._dir_history = ["2", "1"]
	_check("214 missing back end rejected", not b._has_214())

	b._dir_history = ["2", "3", "6"]
	_check("236 qcf recognized", b._has_236())
	b._dir_history = ["6", "3", "2"]
	_check("236 reversed rejected", not b._has_236())
	b._dir_history = []
	_check("empty history rejected", not b._has_236())

	b._dir_history = ["6", "2", "3"]
	_check("623 dp recognized", b._has_623())
	b._dir_history = ["2", "3", "6"]
	_check("623 does not match 236 sequence", not b._has_623())
	b._dir_history = ["6", "2"]
	_check("623 missing down-forward rejected", not b._has_623())

	# 互斥：236 序列不應誤觸 214 / 623
	b._dir_history = ["2", "3", "6"]
	_check("236 does not trigger 214", not b._has_214())
	_check("236 does not trigger 623", not b._has_623())

	# ---- F. 真實接線驗證：需先落到地面，交由 physics_frame 觸發 ----
	var ground := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 40.0)
	col.shape = shape
	ground.add_child(col)
	ground.position = Vector2(700.0, 870.0)
	root.add_child(ground)
	b.position = Vector2(700.0, 820.0)
	b.velocity = Vector2.ZERO
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	_phase += 1
	if _phase < 20:
		return    # 等待重力落地（約 30px、需 12+ 物理幀），is_on_floor 生效
	b.set_physics_process(false)   # 停止自動狀態機，改為手動驅動決策

	_check("wiring grounded", b.is_on_floor())

	# 236 + 重 → 打虎拳
	b.change_state("Idle")
	b._dir_history = ["2", "3", "6"]
	b._heavy_pressed = true
	b._light_pressed = false
	b._decide_free_state(0.016)
	_check("236+heavy -> CmdTiger", b._state == "CmdTiger")

	# 623 + 重 → 昇龍
	b.change_state("Idle")
	b._dir_history = ["6", "2", "3"]
	b._heavy_pressed = true
	b._decide_free_state(0.016)
	_check("623+heavy -> CmdUp", b._state == "CmdUp")

	# 214 + 重 → 飛雲浦反擊
	b.change_state("Idle")
	b._dir_history = ["2", "1", "4"]
	b._heavy_pressed = true
	b._decide_free_state(0.016)
	_check("214+heavy -> Counter", b._state == "Counter")

	# 無指令 + 重 → 普通重攻
	b.change_state("Idle")
	b._dir_history = []
	b._heavy_pressed = true
	b._decide_free_state(0.016)
	_check("no-motion+heavy -> Heavy", b._state == "Heavy")

	# 236 序列 + 輕 → 不應誤觸指令技
	b.change_state("Idle")
	b._dir_history = ["2", "3", "6"]
	b._heavy_pressed = false
	b._light_pressed = true
	b._decide_free_state(0.016)
	_check("236+light -> Light1 (no command)", b._state == "Light1")

	# 指令技出手後清空緩衝
	b.change_state("Idle")
	b._dir_history = ["2", "3", "6"]
	b.change_state("CmdTiger")
	_check("command clears dir buffer", b._dir_history.is_empty())

	# ---- G. 滿氣立繪切換（僅視覺姿態，不動狀態機）----
	var awaken: Dictionary = DATA.spec("AwakenIdle")
	_check("AwakenIdle is loop", bool(awaken.get("loop", false)))
	_check("AwakenIdle frame is draw-knife", String(awaken.visual.frames[0]) == "draw-knife.png")
	_check("AwakenIdle has no damage", int(awaken.get("damage", 0)) == 0)

	b.change_state("Idle")
	b.wine_gauge = 100.0
	_check("full gauge idle plays awaken art", b._play_state() == "AwakenIdle")
	b.wine_gauge = 40.0
	_check("partial gauge idle plays normal art", b._play_state() == "Idle")
	b.wine_gauge = 100.0
	b.change_state("Walk")
	_check("full gauge walking keeps walk art", b._play_state() == "Walk")
	b.change_state("Super")
	_check("Super keeps its own art", b._play_state() == "Super")
	b.wine_gauge = 0.0
	b.change_state("Idle")

	_finish()

func _finish() -> void:
	if fails.is_empty():
		print("GAMEPLAY_SELFTEST result=PASS")
		quit(0)
	else:
		print("GAMEPLAY_SELFTEST FAIL count=", fails.size(), " -> ", fails)
		quit(1)
