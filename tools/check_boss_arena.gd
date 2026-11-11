extends SceneTree
## SCN-05 崗頂 Boss 競技場驗收：Boss 接管 P2、HUD 1200、相機與擊殺演出節點就位。
## 用法：godot --headless --path <game> --script res://tools/check_boss_arena.gd

var fails: Array = []

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/BossArena.tscn")
	_check("BossArena.tscn loads", packed != null)
	var arena = packed.instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame

	_check("P2 is Boss scene", arena.get_node("P2").get_script().resource_path == "res://scripts/boss_fighter.gd")
	_check("P2 hp 1200", arena.get_node("P2").max_hp == 1200 and arena.get_node("P2").current_hp == 1200)
	_check("P2 name 景陽岡猛虎", arena.get_node("HUD/P2Name").text == "景陽岡猛虎")
	_check("HUD P2 max 1200", arena.get_node("HUD/P2HP").max_value == 1200)
	_check("boss death cine node", arena.get_node("P2/BossDeathCine") != null)
	_check("camera exists", arena.get_node("BattleCam") != null)
	_check("loot label exists", arena.get_node("HUD/LootLabel") != null)
	_check("opponents bound", arena.get_node("P2").opponent == arena.get_node("P1") and arena.get_node("P1").opponent == arena.get_node("P2"))

	print("BOSS_ARENA fails=", fails.size(), " -> ", fails)
	quit(0 if fails.is_empty() else 1)
