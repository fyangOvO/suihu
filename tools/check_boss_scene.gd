extends SceneTree
## BOS-04 验收：Boss.tscn 可实例化，Boss 状态/血量/受击盒/碰撞盒齐全。
## 用法：godot --headless --path <game> --script res://tools/check_boss_scene.gd

var fails: Array = []

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/Boss.tscn")
	_check("Boss.tscn loads", packed != null)
	if packed == null:
		print("BOSS_SCENE fails=", fails.size())
		quit(1)
		return
	var boss: CharacterBody2D = packed.instantiate()
	root.add_child(boss)
	await physics_frame
	_check("is not player1", not boss.is_player1)
	_check("max_hp 1200", boss.max_hp == 1200)
	_check("anim_dir boss", boss.anim_dir == "res://assets/anim/boss/")
	_check("start_state BossIdle", boss.start_state == "BossIdle")
	_check("ai_profile boss", boss.ai_profile == "boss")
	_check("current state BossIdle", boss._state == "BossIdle")
	_check("body collision 110x240", boss.get_node("Collision").shape.size == Vector2(110, 240))
	_check("hurt box body 110x240", boss.get_node("HurtBox/HurtShape").shape.size == Vector2(110, 240))
	_check("head box meta 1.5", is_equal_approx(float(boss.get_node("HeadBox").get_meta("damage_mult", 0.0)), 1.5))
	_check("belly box meta 2.0", is_equal_approx(float(boss.get_node("BellyBox").get_meta("damage_mult", 0.0)), 2.0))
	_check("belly starts disabled", boss.get_node("BellyBox/BellyShape").disabled)
	_check("BossHurt 24f", boss.DATA.total_frames(boss._spec("BossHurt")) == 24)
	_check("BossKnockdown 60f", boss.DATA.total_frames(boss._spec("BossKnockdown")) == 60)
	_check("BossDeath 90f", boss.DATA.total_frames(boss._spec("BossDeath")) == 90)
	print("BOSS_SCENE fails=", fails.size(), " -> ", fails)
	quit(0 if fails.is_empty() else 1)
