extends SceneTree
## 實體命中盒回歸自測（無頭可跑）：
## 實例化兩名戰鬥者，重疊放置並由 A 使出 Light1，驗證 HitBox/HurtBox 重疊造成傷害。
## 用法：godot --headless --path <game> --script res://tools/selftest_hitbox.gd
## PASS 退出 0；FAIL 退出 1。

var a: CharacterBody2D
var b: CharacterBody2D
var n: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	a = packed.instantiate()
	b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	# 貼近重疊（A 在左朝右，B 在右朝左）
	a.position = Vector2(400.0, 850.0)
	b.position = Vector2(482.0, 850.0)
	a.face_direction = 1.0
	b.face_direction = -1.0
	b._ai_cd = 9999.0   # 抑制 B 的 AI，只驗證 A 的攻擊盒
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	n += 1
	if n == 2:
		a.change_state("Light1")
	if n >= 80:
		var dealt: bool = b.current_hp < b.max_hp
		print("SELFTEST A_hp=", a.current_hp, " B_hp=", b.current_hp,
			" A_state=", a._state, " B_state=", b._state)
		print("SELFTEST result=", "PASS" if dealt else "FAIL")
		quit(0 if dealt else 1)
