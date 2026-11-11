extends SceneTree
## SCN-05 崗頂 Boss 實際入場自測：
##  A. 從 B7 進入 SCN-05，不直接改 Boss 血量
##  B. 玩家在 Boss 攻擊冷卻窗口貼近打 Light1→2→3 連段
##  C. 不可格擋撲擊：醉打無敵優先，沒有醉打就 Dash 穿過；第一輪先吃一次撲擊驗證傷害
##  D. 走完 66%／33% 三階段，Boss 死亡，B7 clear 並排隊 B8
## 用法：godot --headless --path <game> --script res://tools/selftest_scn05_boss_fight.gd

const SCN05 := "res://scenes/chapters/SCN_05_Ridge.tscn"
const TEST_SAVE := "user://selftest_scn05_boss_fight_checkpoint.json"
const BOSS_ATTACKS: Array = ["BossPounce", "BossTail", "BossRearUp", "BossRoar", "BossSummon",
	"BossIronTail", "BossDeathPounce", "BossPounceP3", "BossRearUpP3"]
const UNBLOCKABLE_POUNCE: Array = ["BossPounce", "BossPounceP3", "BossDeathPounce"]
const MAX_FRAMES: int = 2400

var fails: Array = []
var game: Node2D
var cm
var n: int = 0
var finished: bool = false
var saw_attack: bool = false
var saw_player_hurt: bool = false
var saw_phase2: bool = false
var saw_phase3: bool = false
var saw_player_dash: bool = false
var boss_hp_start: int = 1200
var boss_hp_min: int = 1200
var player_hp_start: int = 800
var player_hp_min: int = 800
var attack_timer: int = 0
var dash_timer: int = 0
var special_timer: int = 0
var block_held: bool = false
var move_dir: int = 0
var boss_attack_count: int = 0
var dash_armed: bool = false
var special_armed: bool = false
var saw_special: bool = false
var allow_first_hit: bool = true
var taking_hit: bool = false
var last_boss_state: String = ""

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _press(action: String) -> void:
	Input.action_press(action)

func _release(action: String) -> void:
	Input.action_release(action)

func _set_move(dir: int) -> void:
	if dir == move_dir:
		return
	Input.action_release("p1_left")
	Input.action_release("p1_right")
	move_dir = dir
	if dir > 0:
		Input.action_press("p1_right")
	elif dir < 0:
		Input.action_press("p1_left")

func _initialize() -> void:
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat("B7")
	game = (load(SCN05) as PackedScene).instantiate()
	root.add_child(game)
	physics_frame.connect(_on_physics)

func _finish() -> void:
	if finished:
		return
	finished = true
	for a in ["p1_light", "p1_jump", "p1_dash", "p1_block", "p1_left", "p1_right", "p1_special"]:
		Input.action_release(a)
	_check("Boss starts at 1200 hp", boss_hp_start == 1200)
	_check("player starts at 800 hp", player_hp_start == 800)
	_check("Boss used attacks", saw_attack)
	_check("Boss damaged player", saw_player_hurt)
	_check("player survived until Boss death", player_hp_min > 0)
	_check("Boss reached phase 2", saw_phase2)
	_check("Boss reached phase 3", saw_phase3)
	_check("player used dash vs unblockable pounce", saw_player_dash)
	_check("Boss died from player attacks", game.p2._death_done)
	_check("B7 marked clear", cm.is_clear("B7"))
	_check("SCN-05 queues B8", game._stage_over and game._pending_next == "B8")
	print("SCN05_BOSS_FIGHT_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", n, " p1_hp=", game.p1.current_hp,
		" p1_min=", player_hp_min, " boss_hp=", game.p2.current_hp,
		" boss_min=", boss_hp_min, " attacks=", boss_attack_count,
		" phase=", game.p2.boss_phase)
	quit(0 if fails.is_empty() else 1)

func _on_physics() -> void:
	if finished:
		return
	n += 1
	var p1: CharacterBody2D = game.get_node_or_null("P1")
	var p2: CharacterBody2D = game.get_node_or_null("P2")
	if p1 == null or p2 == null:
		return

	if n <= 5:
		return
	if n == 6:
		boss_hp_start = p2.current_hp
		player_hp_start = p1.current_hp
		_face_each_other(p1, p2)
	if p1.current_hp <= 0:
		_finish()
		return
	if p2._death_done:
		_finish()
		return
	if n >= MAX_FRAMES:
		_check("timeout before Boss death", false)
		_finish()
		return

	boss_hp_min = mini(boss_hp_min, p2.current_hp)
	player_hp_min = mini(player_hp_min, p1.current_hp)
	if p1.current_hp < player_hp_start:
		saw_player_hurt = true
	if p2.boss_phase >= 2:
		saw_phase2 = true
	if p2.boss_phase >= 3:
		saw_phase3 = true
	if p2._state != last_boss_state:
		if p2._state in BOSS_ATTACKS:
			saw_attack = true
			boss_attack_count += 1
		print("BOSS_STATE ", n, " ", last_boss_state, " -> ", p2._state, " hp=", p2.current_hp)
		last_boss_state = p2._state
	var dist: float = absf(p2.global_position.x - p1.global_position.x)
	if n % 120 == 0:
		print("TICK ", n, " p1=", p1._state, " hp=", p1.current_hp, " p2=", p2._state,
			" f=", p2._frame, " hp=", p2.current_hp, " phase=", p2.boss_phase,
			" dist=", int(dist), " ai_cd=", snappedf(p2._ai_cd, 0.01), " poise=", p2.boss_poise,
			" p1x=", int(p1.global_position.x), " p2x=", int(p2.global_position.x),
			" p1vx=", int(p1.velocity.x), " p2vx=", int(p2.velocity.x),
			" p1f=", p1.face_direction, " p2f=", p2.face_direction)

	var bstate: String = p2._state
	var bframe: int = p2._frame
	var boss_threatening: bool = bstate == "BossPhase" or bstate in BOSS_ATTACKS
	var unblockable_pounce: bool = bstate in UNBLOCKABLE_POUNCE

	# 打法：Boss 冷卻結束前 0.8s 退到 350–370；冷卻窗口貼到 135–150 打輕連段。
	# 普通招站防；不可格擋撲擊用醉打無敵／Dash 穿過；第一輪先吃一次撲擊驗證傷害。
	if taking_hit and not unblockable_pounce:
		taking_hit = false
		allow_first_hit = false
	if unblockable_pounce and (allow_first_hit or taking_hit) \
			and bstate == "BossPounce" and bframe >= 8 and dist <= 360.0:
		# 第一輪先故意吃一次撲擊，驗證 Boss 傷害窗口真的能打到玩家；
		# 之後才進入全閃避打法。玩家 800 血，吃 200 仍能撐完整場。
		taking_hit = true
		if block_held:
			_release("p1_block")
			block_held = false
		_set_move(0)
	elif unblockable_pounce:
		if block_held:
			_release("p1_block")
			block_held = false
		_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
		var special_at: int = 38
		if bstate == "BossPounceP3":
			special_at = 26
		elif bstate == "BossDeathPounce":
			special_at = 20
		var dash_at: int = 42
		if bstate == "BossPounceP3":
			dash_at = 30
		elif bstate == "BossDeathPounce":
			dash_at = 24
		if dist <= 340.0 and p1._drunk_cd <= 0.0 and not special_armed \
				and bframe >= special_at and bframe <= special_at + 3:
			_press("p1_special")
			special_timer = 2
			special_armed = true
			saw_special = true
		elif dist <= 340.0 and not dash_armed and bframe >= dash_at and bframe <= dash_at + 3 and dash_timer == 0:
			_press("p1_dash")
			dash_timer = 2
			dash_armed = true
			saw_player_dash = true
	elif boss_threatening:
		# 尾掃／掀天／咆哮／召虎：原地站防，吃折減傷害。
		_set_move(0)
		if not block_held:
			_press("p1_block")
			block_held = true
	else:
		dash_armed = false
		special_armed = false
		if block_held:
			_release("p1_block")
			block_held = false
		var can_punish: bool = dist <= 155.0 and p2._ai_cd > 0.8 \
			and n % 24 == 0
		var combo_cancel: bool = dist <= 170.0 \
			and p1._state in ["Light1", "Light2"] and p1._frame >= 6
		if combo_cancel:
			_set_move(0)
			_press("p1_light")
			attack_timer = 2
		elif can_punish:
			_set_move(0)
			_press("p1_light")
			attack_timer = 2
		elif p2._ai_cd <= 0.8:
			# Boss 隨時可能起手：退到 350–370，撲擊的 300px 前衝追不到。
			if dist < 350.0:
				_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
			elif dist > 370.0:
				_set_move(1 if p2.global_position.x > p1.global_position.x else -1)
			else:
				_set_move(0)
		else:
			# 冷卻窗口：貼到 135–150 打輕連段；太近才後退。
			if dist > 150.0:
				_set_move(1 if p2.global_position.x > p1.global_position.x else -1)
			elif dist < 135.0:
				_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
			else:
				_set_move(0)

	if attack_timer > 0:
		attack_timer -= 1
		if attack_timer == 0:
			_release("p1_light")
	if dash_timer > 0:
		dash_timer -= 1
		if dash_timer == 0:
			_release("p1_dash")
	if special_timer > 0:
		special_timer -= 1
		if special_timer == 0:
			_release("p1_special")

func _face_each_other(p1: CharacterBody2D, p2: CharacterBody2D) -> void:
	if p2.global_position.x > p1.global_position.x:
		p1.face_direction = 1.0
		p2.face_direction = -1.0
	else:
		p1.face_direction = -1.0
		p2.face_direction = 1.0
