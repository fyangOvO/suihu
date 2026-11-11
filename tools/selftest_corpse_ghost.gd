extends SceneTree
## 老虎伥鬼实体接入自测：
##  A. CorpseGhost 场景、180 血、专属 anim_dir/状态
##  B. 六帧文件、专属 spec 伤害/启动/总帧
##  C. 实跑 AI：接近、出手、不借用武松状态、不跳
##  D. 受击/死亡映射：CorpseHurt / CorpseDeath，青烟演出完成
##  E. SCN-02 B3：伥鬼死亡后写 B3 完成并排队 B4
## 用法：godot --headless --path <game> --script res://tools/selftest_corpse_ghost.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
const CORPSE_SCENE := "res://scenes/CorpseGhost.tscn"
const PLAYER_SCENE := "res://scenes/RiggedFighter.tscn"
const SCN02 := "res://scenes/chapters/SCN_02_Trail.tscn"
const FRAME_DIR := "D:/水滸g/game/assets/anim/corpse_ghost/"
const FRAMES: Array = ["idle", "walk-a", "walk-b", "thrust", "smash", "hurt"]
const PLAYER_STATES: Array = ["Idle", "Walk", "Crouch", "Light1", "Light2", "Light3", "Heavy",
	"Block", "CrouchBlock", "AirUp", "AirDown", "HurtStand", "HurtAir", "Knockdown", "WakeUp"]
const TEST_SAVE := "user://selftest_corpse_ghost_checkpoint.json"

var fails: Array = []
var n: int = 0
var phase: int = 0
var p1: CharacterBody2D
var ghost: CharacterBody2D
var hp_before: int = 0
var start_dist: float = 0.0
var min_dist: float = 9999.0
var saw_attack: bool = false
var saw_player_state: bool = false
var saw_jump: bool = false
var ghost_hp_at_n1: int = 0
var scn02: Node2D
var cm
var scn_done_frames: int = 0

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
	# A. 场景与专属配置
	_check("CorpseGhost scene exists", ResourceLoader.exists(CORPSE_SCENE))
	var packed: PackedScene = load(CORPSE_SCENE)
	ghost = packed.instantiate()
	p1 = (load(PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(p1)
	root.add_child(ghost)
	p1.opponent = ghost
	ghost.opponent = p1
	p1.is_player1 = true
	ghost.is_player1 = false
	_check("ghost max_hp 180", ghost.max_hp == 180)
	_check("ghost anim_dir", ghost.anim_dir == "res://assets/anim/corpse_ghost/")
	_check("ghost profile", ghost.ai_profile == "corpse_ghost")
	_check("ghost start_state", ghost.start_state == "CorpseIdle")

	# B. 六帧与 spec
	for frame_name in FRAMES:
		var path: String = FRAME_DIR + frame_name + ".png"
		_check("frame %s exists" % frame_name, FileAccess.file_exists(path))
		var img := Image.new()
		_check("frame %s decodes" % frame_name, img.load(path) == OK)
		_check("frame %s 512x640" % frame_name, img.get_width() == 512 and img.get_height() == 640)
	_check("CorpseLight 65/8f/24f",
		int(ghost._spec("CorpseLight").get("damage", 0)) == 65
		and int(ghost._spec("CorpseLight").get("logic", {}).get("startup", 0)) == 8
		and DATA.total_frames(ghost._spec("CorpseLight")) == 24)
	_check("CorpseHeavy 130/15f/43f",
		int(ghost._spec("CorpseHeavy").get("damage", 0)) == 130
		and int(ghost._spec("CorpseHeavy").get("logic", {}).get("startup", 0)) == 15
		and DATA.total_frames(ghost._spec("CorpseHeavy")) == 43)
	_check("CorpseDash 65/vx", int(ghost._spec("CorpseDash").get("damage", 0)) == 65
		and float(ghost._spec("CorpseDash").get("vx", 0.0)) > 0.0)
	_check("specs only use six own frames",
		_all_frames_owned("CorpseIdle") and _all_frames_owned("CorpseWalk")
		and _all_frames_owned("CorpseBlock") and _all_frames_owned("CorpseLight")
		and _all_frames_owned("CorpseHeavy") and _all_frames_owned("CorpseDash")
		and _all_frames_owned("CorpseHurt") and _all_frames_owned("CorpseHurtAir")
		and _all_frames_owned("CorpseDeath"))
	_check("idle state mapping", ghost._idle_state() == "CorpseIdle")
	_check("death state mapping", ghost._death_state() == "CorpseDeath")
	_check("hurt state mapping", ghost._hurt_state("HurtStand") == "CorpseHurt")
	_check("air hurt mapping", ghost._hurt_state("HurtAir") == "CorpseHurtAir")
	ghost.change_state("CorpseBlock")
	_check("CorpseBlock is stand defense", ghost.is_blocking and ghost._defense == "stand")
	ghost.change_state("CorpseIdle")

	# C. 实跑 AI
	p1.position = Vector2(400.0, 820.0)
	ghost.position = Vector2(1000.0, 820.0)
	p1.face_direction = 1.0
	ghost.face_direction = -1.0
	ghost._ai_cd = 0.0
	start_dist = absf(ghost.position.x - p1.position.x)
	physics_frame.connect(_on_physics)

func _all_frames_owned(state_name: String) -> bool:
	var frames: Array = DATA.spec(state_name).get("visual", {}).get("frames", [])
	if frames.is_empty():
		return false
	for f in frames:
		if not (String(f).get_basename() in FRAMES):
			return false
	return true

func _on_physics() -> void:
	n += 1
	if phase == 0:
		if n == 1:
			p1.set_physics_process(false)
			hp_before = p1.current_hp
			ghost_hp_at_n1 = ghost.current_hp
			start_dist = absf(ghost.position.x - p1.position.x)
		var dist: float = absf(ghost.position.x - p1.position.x)
		min_dist = minf(min_dist, dist)
		if ghost._state in ["CorpseLight", "CorpseHeavy", "CorpseDash"]:
			saw_attack = true
		if ghost._state in PLAYER_STATES:
			saw_player_state = true
		if ghost._state in ["AirUp", "AirLight", "AirHeavy"] or ghost._jump_pressed:
			saw_jump = true
		if n == 420:
			_check("ghost hp started at 180", ghost_hp_at_n1 == 180)
			_check("ghost approaches", min_dist < start_dist - 100.0)
			_check("ghost used corpse attacks", saw_attack)
			_check("ghost damaged player", p1.current_hp < hp_before)
			_check("ghost never uses player states", not saw_player_state)
			_check("ghost never jumps", not saw_jump)
			ghost._ai_cd = 999.0
			ghost.change_state("CorpseIdle")
			ghost.take_damage(5, -1.0, 0.0)
			_check("damage -> CorpseHurt", ghost._state == "CorpseHurt")
			phase = 1
			n = 0
	elif phase == 1:
		if n == 5:
			_check("CorpseHurt persists (not HurtStand)", ghost._state == "CorpseHurt")
			ghost.current_hp = 1
			ghost.take_damage(10, -1.0, 0.0)
			_check("lethal -> CorpseDeath", ghost._state == "CorpseDeath" and ghost._dying)
			phase = 2
			n = 0
	elif phase == 2:
		if n == 75:
			_check("death mist completes", ghost._death_done)
			_check("ghost visual hidden", not ghost.get_node("Visual").visible)
			_start_scn02()
			phase = 3
			n = 0

func _start_scn02() -> void:
	# 优先复用工程 autoload；--script 模式若没挂上再自建
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat("B3")
	scn02 = (load(SCN02) as PackedScene).instantiate()
	root.add_child(scn02)
	scn02.process_mode = Node.PROCESS_MODE_INHERIT
	scn_done_frames = 0
	physics_frame.connect(_on_scn02_physics)

func _on_scn02_physics() -> void:
	scn_done_frames += 1
	if scn_done_frames == 2:
		var enemy = scn02.get_node_or_null("P2")
		_check("SCN-02 has corpse opponent", enemy != null)
		_check("SCN-02 enemy 180hp", enemy != null and enemy.max_hp == 180)
		if enemy != null:
			enemy.current_hp = 1
			enemy.take_damage(10, -1.0, 0.0)
			_check("SCN-02 enemy enters death", enemy._dying)
	if scn_done_frames == 75:
		var enemy_diag = scn02.get_node("P2")
		_check("SCN-02 enemy death completes", enemy_diag._death_done)
		_check("SCN-02 writes B3 clear", cm.is_clear("B3"))
		_check("SCN-02 queue B4", scn02._stage_over and scn02._pending_next == "B4")
		scn02.queue_free()
		cm.reset_after_test()
		print("SELFTEST corpse_ghost min_dist=", min_dist, " player_hp=", p1.current_hp,
			" fails=", fails.size())
		quit(0 if fails.is_empty() else 1)

func _process(_delta: float) -> bool:
	# 用物理帧推进主测试；SCN-02 段单独计帧
	return false
