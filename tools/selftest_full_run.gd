extends SceneTree
## S09 線性全流程自測：主菜單起點 → 酒肆 → 山道 → 山神廟 → 亂林 → 崗頂 → 水潭 → 章末結算。
## 全程用 Input.action_press 模擬玩家，不直接改血量、不呼叫 take_damage。
## 用法：godot --headless --path <game> --script res://tools/selftest_full_run.gd

const SCN01 := "res://scenes/chapters/SCN_01_Inn.tscn"
const TEST_SAVE := "user://selftest_full_run_checkpoint.json"
const ALL_ATTACKS: Array = [
	"CorpseLight", "CorpseHeavy", "CorpseDash",
	"TigerPounce", "TigerTail", "TigerPounceChain", "TigerCross",
	"BossPounce", "BossTail", "BossRearUp", "BossRoar", "BossSummon",
	"BossIronTail", "BossDeathPounce", "BossPounceP3", "BossRearUpP3",
]
const BOSS_UNBLOCKABLE: Array = ["BossPounce", "BossPounceP3", "BossDeathPounce"]
const MAX_FRAMES: int = 16000
const SCENE_BUDGET: int = 3200
const BEATS: Array = ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9"]

var fails: Array = []
var cm
var n: int = 0
var finished: bool = false
var scene_key: String = ""
var scene_frames: int = 0
var visited: Array = []
var deaths: int = 0
var dialogue_calls: int = 0
var corpse_down: bool = false
var tiger_down: bool = false
var boss_down: bool = false
var checkpoint_seen: bool = false
var summary_seen: bool = false
var scene_p1_hp_min: int = 800
var move_dir: int = 0
var block_held: bool = false
var release_ticks: Dictionary = {}
var last_beat: String = ""
var start_hp: int = 800

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
	last_beat = cm.current_beat
	physics_frame.connect(_on_physics)
	call_deferred("_boot")

func _boot() -> void:
	change_scene_to_file(SCN01)

func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)

func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)

func _tap(action: String, frames: int = 2) -> void:
	if release_ticks.has(action) and int(release_ticks[action]) > 0:
		return
	Input.action_press(action)
	release_ticks[action] = frames

func _tick_taps() -> void:
	for action in release_ticks.keys():
		var left: int = int(release_ticks[action]) - 1
		release_ticks[action] = left
		if left <= 0:
			Input.action_release(action)
			release_ticks.erase(action)

func _set_move(dir: int) -> void:
	if dir == move_dir:
		return
	_release("p1_left")
	_release("p1_right")
	move_dir = dir
	if dir > 0:
		_press("p1_right")
	elif dir < 0:
		_press("p1_left")

func _drop_all() -> void:
	_set_move(0)
	_release("p1_block")
	block_held = false
	for action in ["p1_light", "p1_heavy", "p1_dash", "p1_special", "p1_jump", "p1_drink", "p1_super"]:
		_release(action)
	release_ticks.clear()

func _finish() -> void:
	if finished:
		return
	finished = true
	_drop_all()
	var cleared: bool = true
	for b in BEATS:
		if not cm.is_clear(b):
			cleared = false
			print("UNCLEAR ", b)
	_check("visited all six scenes", visited.size() == 6)
	_check("scene order B1-B9", visited == ["SCN-01", "SCN-02", "SCN-04", "SCN-03", "SCN-05", "SCN-06"])
	_check("player never died", deaths == 0)
	_check("corpse ghost defeated in real fight", corpse_down)
	_check("tiger defeated in real fight", tiger_down)
	_check("boss defeated in real fight", boss_down)
	_check("all B1-B9 marked clear", cleared)
	_check("reached B9", cm.current_beat == "B9")
	_check("B4 checkpoint saved", checkpoint_seen and cm.has_checkpoint())
	_check("summary panel shown", summary_seen)
	print("FULL_RUN_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", n, " deaths=", deaths,
		" beat=", cm.current_beat, " hp=", cm.player_hp,
		" loot=", cm.loot_counts, " dialogue_calls=", dialogue_calls)
	if checkpoint_seen:
		cm.clear_checkpoint()
	quit(0 if fails.is_empty() else 1)

func _on_physics() -> void:
	if finished:
		return
	n += 1
	_tick_taps()
	var scene: Node = current_scene
	if scene == null:
		if n >= MAX_FRAMES:
			_check("timeout waiting for first scene", false)
			_finish()
		return
	var sid: String = ""
	if scene.has_method("scene_id"):
		sid = String(scene.call("scene_id"))
	if sid != scene_key:
		scene_key = sid
		scene_frames = 0
		visited.append(sid)
		print("SCENE ", n, " -> ", sid, " beat=", cm.current_beat)
	else:
		scene_frames += 1

	if cm.current_beat != last_beat:
		print("BEAT ", n, " ", last_beat, " -> ", cm.current_beat)
		last_beat = cm.current_beat
	if cm.has_checkpoint():
		checkpoint_seen = true

	if n >= MAX_FRAMES:
		_check("timeout before reaching B9", false)
		_finish()
		return
	if scene_frames > SCENE_BUDGET and not (sid == "SCN-06" and bool(scene.get("_stage_over"))):
		_check("scene %s stuck over %d frames" % [sid, SCENE_BUDGET], false)
		_finish()
		return

	var dialogue = scene.get("dialogue")
	if dialogue != null and dialogue.has_method("is_active") and dialogue.call("is_active"):
		_drop_all()
		if n % 18 == 0:
			dialogue.call("next")
			dialogue_calls += 1
		return

	if sid == "SCN-06" and bool(scene.get("_stage_over")):
		_drop_all()
		var shell = scene.get("_shell")
		var page: String = ""
		if shell != null and shell.has_method("current_page"):
			page = String(shell.call("current_page"))
		if page == "summary":
			summary_seen = true
		if summary_seen or scene_frames > 180:
			_finish()
		return

	var p1: CharacterBody2D = scene.get_node_or_null("P1")
	var p2: CharacterBody2D = scene.get_node_or_null("P2")
	if p1 == null:
		return
	scene_p1_hp_min = mini(scene_p1_hp_min, p1.current_hp)
	if p1.current_hp <= 0:
		deaths += 1
		_check("player died at %s" % sid, false)
		_finish()
		return
	if p2 == null:
		_drop_all()
		return
	if p2._death_done:
		_drop_all()
		if sid == "SCN-02":
			corpse_down = true
		elif sid == "SCN-03":
			tiger_down = true
		elif sid == "SCN-05":
			boss_down = true
		return
	if not p2.is_physics_processing():
		_drop_all()
		return

	var dist: float = absf(p2.global_position.x - p1.global_position.x)
	var p2state: String = String(p2._state)
	var p2frame: int = int(p2._frame)
	if n % 120 == 0:
		print("TICK ", n, " ", sid, " beat=", cm.current_beat, " p1=", p1._state,
			" hp=", p1.current_hp, " p2=", p2state, " f=", p2frame,
			" hp=", p2.current_hp, " dist=", int(dist), " ai_cd=", snappedf(p2._ai_cd, 0.01))
	if sid == "SCN-05":
		_drive_boss(p1, p2, dist, p2state, p2frame)
	else:
		_drive_melee(p1, p2, dist, p2state, p2frame)

func _drive_melee(p1: CharacterBody2D, p2: CharacterBody2D, dist: float, p2state: String, p2frame: int) -> void:
	var threat: bool = p2state in ALL_ATTACKS
	var chain_unblockable: bool = p2state == "TigerPounceChain" and p2frame >= 22
	if chain_unblockable and dist <= 280.0:
		if block_held:
			_release("p1_block")
			block_held = false
		_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
		if p1._drunk_cd <= 0.0 and p2frame >= 18 and p2frame <= 26 and dist <= 240.0:
			_tap("p1_special")
		elif p2frame >= 24 and p2frame <= 32 and dist <= 260.0:
			_tap("p1_dash")
		return
	if threat and dist < 360.0:
		_set_move(0)
		if not block_held:
			_press("p1_block")
			block_held = true
		return
	if block_held:
		_release("p1_block")
		block_held = false
	if dist > 150.0:
		_set_move(1 if p2.global_position.x > p1.global_position.x else -1)
		return
	_set_move(0)
	var combo_cancel: bool = p1._state in ["Light1", "Light2"] and p1._frame >= 6
	if combo_cancel or n % 18 == 0:
		_tap("p1_light")

func _drive_boss(p1: CharacterBody2D, p2: CharacterBody2D, dist: float, p2state: String, p2frame: int) -> void:
	var boss_threatening: bool = p2state == "BossPhase" or p2state in ALL_ATTACKS
	var unblockable: bool = p2state in BOSS_UNBLOCKABLE
	if unblockable:
		if block_held:
			_release("p1_block")
			block_held = false
		_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
		var special_at: int = 38
		if p2state == "BossPounceP3":
			special_at = 26
		elif p2state == "BossDeathPounce":
			special_at = 20
		var dash_at: int = 42
		if p2state == "BossPounceP3":
			dash_at = 30
		elif p2state == "BossDeathPounce":
			dash_at = 24
		if dist <= 340.0 and p1._drunk_cd <= 0.0 and p2frame >= special_at and p2frame <= special_at + 3:
			_tap("p1_special")
		elif dist <= 340.0 and p2frame >= dash_at and p2frame <= dash_at + 3:
			_tap("p1_dash")
		return
	if boss_threatening:
		_set_move(0)
		if not block_held:
			_press("p1_block")
			block_held = true
		return
	if block_held:
		_release("p1_block")
		block_held = false
	var combo_cancel: bool = dist <= 170.0 and p1._state in ["Light1", "Light2"] and p1._frame >= 6
	if combo_cancel:
		_set_move(0)
		_tap("p1_light")
	elif dist <= 155.0 and p2._ai_cd > 0.8 and n % 24 == 0:
		_set_move(0)
		_tap("p1_light")
	elif p2._ai_cd <= 0.8:
		if dist < 350.0:
			_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
		elif dist > 370.0:
			_set_move(1 if p2.global_position.x > p1.global_position.x else -1)
		else:
			_set_move(0)
	else:
		if dist > 150.0:
			_set_move(1 if p2.global_position.x > p1.global_position.x else -1)
		elif dist < 135.0:
			_set_move(-1 if p2.global_position.x > p1.global_position.x else 1)
		else:
			_set_move(0)
