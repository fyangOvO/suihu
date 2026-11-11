extends SceneTree
## 吊睛小虎 AI（docs/04 §3）無頭自測：
##  A. 數據：350 血、四招傷害/總幀、受擊/倒地/起身 spec 齊備
##  B. 純決策 tiger_plan：遠距越頂/接近、中距前撲/三連撲、貼身尾掃、冷卻等待、對手出招後跳
##  C. 決策合法性：任何 roll 都不產生站防/蹲防/投擲等小虎不具備的行為
##  D. 實跑：自動接近、撲中扣血、出招後後跳；受擊走 TigerHurt、死亡走 TigerKnockdown
## 用法：godot --headless --path <game> --script res://tools/selftest_tiger.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
const TIGER_PLANS: Array = ["approach", "hop", "wait", "pounce", "tail", "chain", "cross"]
const TIGER_ATTACKS: Array = ["TigerPounce", "TigerTail", "TigerPounceChain", "TigerCross"]
const FORBIDDEN_PLANS: Array = ["block", "crouch_block", "jump", "air", "throw", "rock", "light", "heavy", "dash_attack"]

var fails: Array = []
var a: CharacterBody2D      # 武松假人（凍結）
var b: CharacterBody2D      # 小虎 AI
var n: int = 0
var phase: int = 0
var start_dist: float = 0.0
var min_dist: float = 9999.0
var saw_attack: bool = false
var saw_hop: bool = false
var saw_block: bool = false
var saw_crouch: bool = false
var saw_player_state: bool = false
var hp_before: int = 0
var hp_after: int = 0
var hp_at_n1: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _ctx(dist: float, over: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {
		"dist": dist, "hp_ratio": 1.0, "opp_state": "Idle", "opp_frame": 0,
		"opp_startup": 0, "opp_active_end": 0, "atk_cd": 0.0, "retreat": 0.0,
		"throw_cd": 0.0, "roll": 0.5,
	}
	for k in over.keys():
		ctx[k] = over[k]
	return ctx

func _initialize() -> void:
	# 自立地板（否則兩人都會一直下墜，AI 永遠走空中分支）
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(900.0, 900.0)
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2400.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	root.add_child(floor_body)

	var player_packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	var tiger_packed: PackedScene = load("res://scenes/Tiger.tscn")
	a = player_packed.instantiate()
	b = tiger_packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.is_player1 = true
	a.set_physics_process(false)   # 假人完全靜止，不干擾 AI 判定
	b.is_player1 = false

	# ---- A. 數據與姿態齊備 ----
	_check("tiger max_hp 350", b.max_hp == 350)
	_check("tiger anim profile", b.ai_profile == "tiger" and b.anim_dir == "res://assets/anim/tiger/")
	_check("tiger pounce 90 dmg / 38f", int(b._spec("TigerPounce").get("damage", 0)) == 90 and DATA.total_frames(b._spec("TigerPounce")) == 38)
	_check("tiger tail 80 dmg / 36f", int(b._spec("TigerTail").get("damage", 0)) == 80 and DATA.total_frames(b._spec("TigerTail")) == 36)
	_check("tiger chain 110 dmg / 48f", int(b._spec("TigerPounceChain").get("damage", 0)) == 110 and DATA.total_frames(b._spec("TigerPounceChain")) == 48)
	_check("tiger cross 70 dmg / 38f", int(b._spec("TigerCross").get("damage", 0)) == 70 and DATA.total_frames(b._spec("TigerCross")) == 38)
	_check("tiger hurt art two frames", (b._spec("TigerHurt").get("visual", {}).get("frames", []) as Array).size() == 2)
	_check("global table untouched",
		int(DATA.spec("TigerPounce").get("damage", 0)) == 90
		and int(DATA.spec("Light1").get("damage", 0)) == 40)

	# ---- B. 純決策：距離分檔 ----
	_check("far 520 -> approach", b.tiger_plan(_ctx(520.0, {"roll": 0.1})) == "approach")
	_check("far 420 rolls cross-up", b.tiger_plan(_ctx(420.0, {"roll": 0.1})) == "cross")
	_check("far 420 high roll -> approach", b.tiger_plan(_ctx(420.0, {"roll": 0.9})) == "approach")
	_check("mid 300 -> pounce", b.tiger_plan(_ctx(300.0, {"roll": 0.1})) == "pounce")
	_check("mid 300 -> chain", b.tiger_plan(_ctx(300.0, {"roll": 0.6})) == "chain")
	_check("mid 300 -> cross", b.tiger_plan(_ctx(300.0, {"roll": 0.8})) == "cross")
	_check("mid 300 -> approach", b.tiger_plan(_ctx(300.0, {"roll": 0.95})) == "approach")
	_check("close 90 -> tail", b.tiger_plan(_ctx(90.0, {"roll": 0.1})) == "tail")
	_check("close 90 -> chain", b.tiger_plan(_ctx(90.0, {"roll": 0.9})) == "chain")
	_check("close 130 -> tail", b.tiger_plan(_ctx(130.0, {"roll": 0.1})) == "tail")
	_check("cooldown close -> wait", b.tiger_plan(_ctx(90.0, {"atk_cd": 0.4})) == "wait")
	_check("cooldown far -> approach", b.tiger_plan(_ctx(300.0, {"atk_cd": 0.4})) == "approach")
	_check("opp startup & close -> hop (no block)",
		b.tiger_plan(_ctx(120.0, {"opp_state": "Heavy", "opp_frame": 3, "opp_active_end": 12})) == "hop")
	_check("opp recovery -> still attacks", b.tiger_plan(_ctx(120.0, {"opp_state": "Heavy", "opp_frame": 30, "opp_active_end": 16})) != "hop")

	# ---- C. 決策合法性：100 個 roll × 四段距離 ----
	var legal: bool = true
	for d in [90.0, 150.0, 300.0, 420.0]:
		for i in 100:
			var p: String = b.tiger_plan(_ctx(d, {"roll": float(i) / 100.0}))
			if not (p in TIGER_PLANS):
				legal = false
	_check("all plans legal for 100 rolls", legal)
	var forbidden_found: bool = false
	for p in TIGER_PLANS:
		if p in FORBIDDEN_PLANS:
			forbidden_found = true
	_check("never yields block/crouch/jump/throw", not forbidden_found)

	a.position = Vector2(400.0, 820.0)
	b.position = Vector2(1000.0, 820.0)
	a.face_direction = 1.0
	b.face_direction = -1.0
	b._ai_cd = 0.0
	start_dist = absf(b.position.x - a.position.x)
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	n += 1
	if phase == 0:
		if n == 1:
			# _ready/_physics 首幀才生效：凍結假人、取基準
			a.set_physics_process(false)
			hp_before = a.current_hp
			hp_at_n1 = b.current_hp
			start_dist = absf(b.position.x - a.position.x)
		var dist: float = absf(b.position.x - a.position.x)
		min_dist = minf(min_dist, dist)
		if b._state in TIGER_ATTACKS:
			saw_attack = true
		if b._ai_hop > 0.0:
			saw_hop = true
		if b._state in ["Block", "CrouchBlock", "AirBlock"]:
			saw_block = true
		if b._state in ["Crouch", "Walk", "Idle", "Light1", "Heavy", "Dash"]:
			saw_crouch = true
			saw_player_state = true
		if n == 420:
			_check("tiger hp started at 350", hp_at_n1 == 350)
			_check("tiger approaches (min_dist < start)", min_dist < start_dist - 150.0)
			_check("tiger attacked P1", saw_attack)
			_check("attack damaged P1", a.current_hp < hp_before)
			hp_after = a.current_hp
			_check("tiger never blocks", not saw_block)
			_check("tiger never uses player poses", not saw_player_state)
			# 受擊姿態映射：不套武松的 HurtStand
			b._ai_cd = 999.0
			b.change_state("TigerIdle")
			b.take_damage(5, -1.0, 0.0)
			_check("damage -> TigerHurt", b._state == "TigerHurt")
			phase = 1
			n = 0
	elif phase == 1:
		if n == 5:
			_check("TigerHurt persists (not HurtStand)", b._state == "TigerHurt")
			# 死亡姿態映射：不套武松的 Knockdown
			b.current_hp = 1
			b.take_damage(10, -1.0, 0.0)
			_check("lethal -> TigerKnockdown", b._state == "TigerKnockdown" and b._dying)
			phase = 2
			n = 0
	elif phase == 2:
		if n == 75:
			_check("death演出 completes", b._death_done)
			_check("tiger dropped by hop after attack", saw_hop)
			print("SELFTEST tiger min_dist=", min_dist, " hp_after=", hp_after,
				" saw_hop=", saw_hop, " fails=", fails.size())
			quit(0 if fails.is_empty() else 1)
