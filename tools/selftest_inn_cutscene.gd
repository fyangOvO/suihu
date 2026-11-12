extends SceneTree
## SCN-01 酒肆演出自測：布景節點、落座、三碗酒、燈滅、尾影、B1→B2。
const SCENE := preload("res://scenes/chapters/SCN_01_Inn.tscn")
const TEST_SAVE := "user://selftest_inn_checkpoint.json"

var cm
var scn
var frames: int = 0
var fails: Array = []
var saw_drink: bool = false
var saw_bowl1: bool = false
var saw_lamp: bool = false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat("B1")
	scn = SCENE.instantiate()
	root.add_child(scn)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_check("InnBack exists", scn.find_child("InnBack", true, false) != null)
		_check("InnFront exists", scn.find_child("InnFront", true, false) != null)
		_check("InnTable exists", scn.find_child("InnTable", true, false) != null)
		_check("three bowls", scn.find_child("Bowl1", true, false) != null
			and scn.find_child("Bowl2", true, false) != null
			and scn.find_child("Bowl3", true, false) != null)
		_check("lamp nodes", scn.find_child("LampLight", true, false) != null
			and scn.find_child("LampGlow", true, false) != null
			and scn.find_child("LampFlame", true, false) != null)
		_check("shopkeeper shadow", scn.find_child("ShopkeeperShadow", true, false) != null)
		var shop_rim := scn.find_child("ShopkeeperRim", true, false) as Line2D
		_check("shopkeeper rim", shop_rim != null and shop_rim.width >= 2.0)
		var tail_line := scn.find_child("TailLine", true, false) as Line2D
		var tail_rim := scn.find_child("TailRim", true, false) as Line2D
		_check("tail silhouette", tail_line != null and tail_line.width >= 40.0)
		_check("tail edge rim", tail_rim != null and tail_rim.width >= 5.0)
		var bowl_detail_ok: bool = scn._bowls.all(Callable(self, "_bowl_has_detail"))
		_check("bowls have body/rim/wine/glint", bowl_detail_ok)
		_check("tail hidden at start", not scn._tail_root.visible)
		_check("B1 no opponent", scn.p2 == null)
		_check("P1 visual ready", scn.p1.get_node_or_null("Visual") != null)
		scn.dialogue.close()
	elif frames > 3 and is_instance_valid(scn):
		if scn._phase == "drink" and not saw_drink:
			saw_drink = true
			_check("drink phase", scn._drink_round == 0)
			_check("drink action first bowl", scn._drink_action == "InnDrink1")
			_check("P1 frozen for cutscene", not scn.p1.is_physics_processing())
			_check("P1 seated lower", scn.p1.get_node("Visual").position.y > -140.0)
			_check("drink frame texture", scn.p1.get_node("Visual").texture != null)
			_check("bowl count 3", scn._bowls.size() == 3)
		if scn._drink_round >= 1 and scn._phase_t > 0.12 and not saw_bowl1:
			saw_bowl1 = true
			_check("first bowl fades", scn._bowls[0].modulate.a < 0.95)
			_check("second drink action", scn._drink_action == "InnDrink2" or scn._phase == "lamp")
		if scn._phase == "lamp" and scn._phase_t > 0.60 and not saw_lamp:
			saw_lamp = true
			_check("lamp energy off", scn._lamp_light.energy < 0.05)
			_check("lamp glow off", scn._lamp_glow.modulate.a < 0.05)
			_check("flame off", scn._lamp_flame.modulate.a < 0.05)
			_check("canvas dimmed", scn._canvas_mod.color != Color.WHITE)
			_check("tail revealed", scn._tail_root.visible and scn._tail_shown)
			_check("all bowls empty", scn._bowls.all(func(b): return b.modulate.a < 0.1))
	if cm.current_beat == "B2":
		_check("B1 clear", cm.is_clear("B1"))
		_check("B1 -> B2", true)
		_check("no visible opponent in inn", scn == null or not is_instance_valid(scn) or scn.p2 == null)
		print("INN_SELFTEST fails=", fails)
		quit(0 if fails.is_empty() else 1)
		return true
	if frames > 1600:
		print("INN_SELFTEST TIMEOUT phase=", scn._phase if is_instance_valid(scn) else "<freed>",
			" stage_over=", scn._stage_over if is_instance_valid(scn) else "?",
			" pending=", scn._pending_next if is_instance_valid(scn) else "?",
			" clear_timer=", scn._clear_timer if is_instance_valid(scn) else "?",
			" dialogue=", scn._dialogue_active if is_instance_valid(scn) else "?",
			" processing=", scn.is_processing() if is_instance_valid(scn) else "?",
			" process_mode=", scn.process_mode if is_instance_valid(scn) else "?",
			" paused=", paused,
			" beat=", cm.current_beat,
			" cm_path=", cm.get_path(),
			" fails=", fails)
		quit(1)
		return true
	return false

func _bowl_has_detail(bowl: Node) -> bool:
	for part in ["BowlBody", "BowlRim", "BowlWine", "BowlWineGlint"]:
		if bowl.find_child(part, true, false) == null:
			return false
	return true
