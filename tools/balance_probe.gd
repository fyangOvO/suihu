extends SceneTree
## OPT-05 平衡探針：固定打法（貼身輕連段／看招站防／不可格擋就閃）在真實章節把三敵打完，
## 記錄 TTK、掉血、覺醒使用次數。只量測、不改數值。
## 用法：godot --headless --path <game> --script res://tools/balance_probe.gd -- SCN-02

const SCENES := {
	"SCN-02": ["res://scenes/chapters/SCN_02_Trail.tscn", "B3", 180],
	"SCN-03": ["res://scenes/chapters/SCN_03_Forest.tscn", "B5", 350],
	"SCN-05": ["res://scenes/chapters/SCN_05_Ridge.tscn", "B7", 1200],
}
const TEST_SAVE := "user://balance_probe_checkpoint.json"
const MAX_FRAMES: int = 9000
const NEUTRAL := ["Idle", "Walk", "Air", "Hurt", "Knockdown", "WakeUp", "Death", "Spawn",
	"BossPhase", "BossIdle", "BossWalk", "BossHurt"]

var scene_id: String = "SCN-02"
var cautious: bool = false
var novice: bool = false
var novice_cd: int = 0
var trace_tick: bool = false
var game: Node2D
var cm
var n: int = 0
var first_hit_frame: int = -1
var finished: bool = false
var p1_start_hp: int = 800
var enemy_start_hp: int = 180
var p1_min_hp: int = 800
var supers: int = 0
var last_p1_state: String = ""
var taps: Dictionary = {}
var block_held: bool = false
var move_dir: int = 0
var punish_gap: int = 0
var dash_cd: int = 0

func _tap(action: String, frames: int) -> void:
	Input.action_press(action)
	taps[action] = frames

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

func _set_block(on: bool) -> void:
	if on == block_held:
		return
	block_held = on
	if on:
		Input.action_press("p1_block")
	else:
		Input.action_release("p1_block")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and SCENES.has(args[0]):
		scene_id = args[0]
	for a in args:
		if a == "--cautious":
			cautious = true
		elif a == "--trace":
			trace_tick = true
		elif a == "--novice":
			novice = true
	var info: Array = SCENES[scene_id]
	seed(20261118)
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat(info[1])
	game = (load(info[0]) as PackedScene).instantiate()
	root.add_child(game)
	enemy_start_hp = int(info[2])
	physics_frame.connect(_on_physics)

func _finish(note: String) -> void:
	if finished:
		return
	finished = true
	for a in ["p1_light", "p1_heavy", "p1_block", "p1_jump", "p1_dash", "p1_special",
			"p1_left", "p1_right"]:
		Input.action_release(a)
	var combat: int = maxi(0, n - first_hit_frame) if first_hit_frame > 0 else -1
	print("BALANCE_RESULT scene=", scene_id, " note=", note,
		" frames=", n, " combat=", combat,
		" sec=", snappedf(float(n) / 60.0, 0.1),
		" combat_sec=", snappedf(float(combat) / 60.0, 0.1),
		" p1_hp_min=", p1_min_hp, " enemy_start=", enemy_start_hp,
		" supers=", supers, " first_hit=", first_hit_frame)
	quit(0)

func _spec_of(e: CharacterBody2D) -> Dictionary:
	if e.has_method("_spec"):
		return e._spec(e._state)
	return {}

func _threat(e: CharacterBody2D) -> bool:
	if e._state in NEUTRAL:
		return false
	if not e.has_method("_spec"):
		return true
	return int(_spec_of(e).get("damage", 0)) > 0

func _recovering(e: CharacterBody2D) -> bool:
	if e._state in NEUTRAL:
		return true
	var spec: Dictionary = _spec_of(e)
	var startup: int = int(spec.get("startup", 0))
	var active: int = int(spec.get("active", 0))
	return e._frame > startup + active + 2

func _on_physics() -> void:
	if finished:
		return
	n += 1
	if n > MAX_FRAMES:
		_finish("timeout")
		return
	var p1: CharacterBody2D = game.get_node_or_null("P1")
	var e: CharacterBody2D = game.get_node_or_null("P2")
	if p1 == null or e == null:
		return
	if n == 2:
		p1_start_hp = p1.current_hp
		p1_min_hp = p1_start_hp

	for a in taps.keys():
		taps[a] -= 1
		if taps[a] <= 0:
			Input.action_release(a)
			taps.erase(a)

	if e.current_hp < enemy_start_hp and first_hit_frame < 0:
		first_hit_frame = n
	if p1.current_hp < p1_min_hp:
		p1_min_hp = p1.current_hp
	if p1._state != last_p1_state:
		if p1._state == "Super":
			supers += 1
		last_p1_state = p1._state
	if p1.current_hp <= 0:
		_finish("player_dead")
		return
	if e._death_done and game._stage_over:
		_finish("enemy_dead")
		return
	if e.current_hp <= 0 and e._death_done:
		_finish("enemy_dead")
		return

	if trace_tick and n % 60 == 0:
		print("BP_TICK ", n, " p1=", p1._state, " f=", p1._frame, " hp=", p1.current_hp,
			" e=", e._state, " ef=", e._frame,
			" ehp=", e.current_hp, " dist=", int(absf(e.global_position.x - p1.global_position.x)),
			" rec=", _recovering(e), " threat=", _threat(e), " block=", block_held)
	if punish_gap > 0:
		punish_gap -= 1
	if dash_cd > 0:
		dash_cd -= 1

	var dist: float = absf(e.global_position.x - p1.global_position.x)
	var dir: int = 1 if e.global_position.x >= p1.global_position.x else -1
	p1.face_direction = float(dir)
	var threat: bool = _threat(e)
	var spec: Dictionary = _spec_of(e)
	var unblockable: bool = bool(spec.get("unblockable", false))
	var startup: int = int(spec.get("startup", 0))
	var active: int = int(spec.get("active", 0))
	var threat_window: bool = threat and e._frame <= startup + active + 2

	# 不可格擋：往後 Dash 穿過，冷卻 14 幀
	if unblockable and dist <= 330.0 and dash_cd <= 0:
		_set_block(false)
		_set_move(-dir)
		_tap("p1_dash", 2)
		dash_cd = 14
		return
	# 有傷害的起手且已在打得到的距離：站防（守規玩家偶爾會漏擋）
	if threat_window and dist <= 240.0 and (not novice or n % 7 != 0):
		_set_move(0)
		_set_block(true)
		return
	_set_block(false)
	if novice:
		# 新手節奏：約每 1.8 秒才組織一次進攻，出手時機不挑、距離不對就空揮
		if novice_cd > 0:
			novice_cd -= 1
		if dist > 235.0:
			_set_move(dir)
		elif dist < 185.0:
			_set_move(-dir)
		else:
			_set_move(0)
		if novice_cd <= 0 and p1._state in ["Idle", "Walk"]:
			_tap("p1_light", 2)
			novice_cd = 110
		return
	if cautious:
		# 保守打法：只在敵人收招後的空窗打一兩下，其餘時間拉到 230–260 等下一次起手
		if dist > 250.0:
			_set_move(dir)
		elif dist < 215.0:
			_set_move(-dir)
		else:
			_set_move(0)
		if _recovering(e) and dist <= 160.0 and punish_gap <= 0 \
				and p1._state in ["Idle", "Walk", "Light1", "Light2"]:
			if p1._state in ["Idle", "Walk"] or p1._frame >= 6:
				_tap("p1_light", 2)
				punish_gap = 14
		return
	# 酒氣滿：貼身直接覺醒
	if p1.wine_gauge >= 100.0 and dist <= 220.0 and p1._state in ["Idle", "Walk"]:
		_set_move(0)
		_tap("p1_special", 2)
		return
	# 其餘時間一律往前壓，進到 120–160 就打輕連段；對招中的少量互換算正常失誤
	if dist > 150.0:
		_set_move(dir)
	elif dist < 116.0:
		_set_move(-dir)
	else:
		_set_move(0)
	if dist <= 168.0 and punish_gap <= 0 and p1._state in ["Idle", "Walk", "Light1", "Light2"]:
		if p1._state in ["Idle", "Walk"] or p1._frame >= 6:
			_tap("p1_light", 2)
			punish_gap = 9
