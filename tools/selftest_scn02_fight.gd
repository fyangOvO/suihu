extends SceneTree
## SCN-02 伥鬼實戰自測：不使用 take_damage 直接秒殺。
##  A. 伥鬼 AI 會主動接近、出 CorpseLight/CorpseHeavy/CorpseDash
##  B. 玩家用普通輕擊（模擬 p1_light）能把 180 血伥鬼打死
##  C. 死亡後 SCN-02 寫 B3 clear 並排隊 B4
## 用法：godot --headless --path <game> --script res://tools/selftest_scn02_fight.gd

const SCN02 := "res://scenes/chapters/SCN_02_Trail.tscn"
const TEST_SAVE := "user://selftest_scn02_fight_checkpoint.json"
const CORPSE_ATTACKS: Array = ["CorpseLight", "CorpseHeavy", "CorpseDash"]

var fails: Array = []
var game: Node2D
var cm
var n: int = 0
var enemy_hp_start: int = 180
var player_hp_start: int = 800
var saw_attack: bool = false
var saw_player_hit: bool = false
var saw_enemy_hit: bool = false
var input_release: int = 0
var attack_press_count: int = 0
var enemy_hp_min: int = 180
var block_held: bool = false
var finished: bool = false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _make_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(900.0, 900.0)
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2400.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	root.add_child(floor_body)

func _initialize() -> void:
	_make_floor()
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat("B3")
	game = (load(SCN02) as PackedScene).instantiate()
	root.add_child(game)
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	if finished:
		return
	n += 1
	var p1: CharacterBody2D = game.get_node_or_null("P1")
	var p2: CharacterBody2D = game.get_node_or_null("P2")
	if p1 == null or p2 == null:
		return

	if n == 3:
		# 拉到一個「已經在輕擊距離內」的起手位置，避免測試花 10 秒等 AI 走過來。
		p1.global_position = Vector2(1000.0, 820.0)
		p2.global_position = Vector2(1120.0, 820.0)
		p1.face_direction = 1.0
		p2.face_direction = -1.0
		p2._ai_cd = 0.0
		enemy_hp_start = p2.current_hp
		player_hp_start = p1.current_hp
		_check("ghost presence built", game.find_child("GhostPresence", true, false) != null)
		_check("ghost cold fog", game.find_child("GhostFogLow", true, false) != null)
		_check("ghost tutorial focus", game.find_child("TutorialFocus", true, false) != null)
		_check("ghost visual scaled up", p2.get_node("Visual").scale.y >= 0.65)

	if n > 5:
		if p2._state in CORPSE_ATTACKS:
			saw_attack = true
		if p1.current_hp < player_hp_start:
			saw_player_hit = true
		if p2.current_hp < enemy_hp_start:
			saw_enemy_hit = true
		enemy_hp_min = mini(enemy_hp_min, p2.current_hp)

		# 每 24 幀按一次 p1_light，按兩幀後放開；不走 take_damage 捷徑。
		# 伥鬼起手時改按 p1_block，模擬玩家看起手防禦，而不是站著挨打。
		var dist: float = absf(p2.global_position.x - p1.global_position.x)
		var enemy_threat: bool = p2._state in CORPSE_ATTACKS and dist < 260.0
		if enemy_threat:
			if not block_held and input_release == 0:
				Input.action_press("p1_block")
				block_held = true
		elif block_held:
			Input.action_release("p1_block")
			block_held = false

		if input_release > 0:
			input_release -= 1
			if input_release == 0:
				Input.action_release("p1_light")
		elif not enemy_threat and not block_held and p2.current_hp > 0 and n % 24 == 0:
			Input.action_press("p1_light")
			attack_press_count += 1
			input_release = 2

	if (p2._death_done or n >= 1200) and not finished:
		finished = true
		Input.action_release("p1_light")
		Input.action_release("p1_block")
		_check("enemy starts at 180 hp", enemy_hp_start == 180)
		_check("AI used corpse attacks", saw_attack)
		_check("AI damaged player", saw_player_hit)
		_check("player light attacks damaged enemy", saw_enemy_hit)
		_check("enemy died from player attacks", p2._death_done)
		_check("B3 marked clear", cm.is_clear("B3"))
		_check("SCN-02 queues B4", game._stage_over and game._pending_next == "B4")
		var focus := game.find_child("TutorialFocus", true, false)
		_check("tutorial focus hides on death", focus == null or not focus.visible)
		print("SCN02_FIGHT_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
			" fails=", fails, " frames=", n, " p1_hp=", p1.current_hp, " p2_hp=", p2.current_hp,
			" min_p2_hp=", enemy_hp_min, " presses=", attack_press_count,
			" p1_state=", p1._state, " p2_state=", p2._state)
		quit(0 if fails.is_empty() else 1)
