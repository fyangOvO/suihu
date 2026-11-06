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

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	var a = packed.instantiate()
	var b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	b._ai_cd = 9999.0

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

	if fails.is_empty():
		print("GAMEPLAY_SELFTEST result=PASS")
		quit(0)
	else:
		print("GAMEPLAY_SELFTEST FAIL count=", fails.size(), " -> ", fails)
		quit(1)
