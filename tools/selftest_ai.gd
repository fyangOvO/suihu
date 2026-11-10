extends SceneTree
## 伥鬼 AI（docs/04 §2）無頭自測：
##  A. 純決策函數 ai_plan：距離分檔、架招起防、收招懲罰、被打後退、低血亂揮、冷卻等待
##  B. 決策輸出合法性：任何 roll 都不會產生跳躍/蹲防/投擲等伥鬼不具備的行為
##  C. 實跑：P2 自動接近、貼身後出手、不跳，被打後確實後退
## 用法：godot --headless --path <game> --script res://tools/selftest_ai.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
const AI_PLANS: Array = ["retreat", "block", "heavy", "light", "dash_attack", "approach", "wait"]

var fails: Array = []
var a: CharacterBody2D      # P1 假人
var b: CharacterBody2D      # 伥鬼 AI
var n: int = 0
var phase: int = 0
var start_dist: float = 0.0
var min_dist: float = 9999.0
var saw_attack: bool = false
var saw_jump: bool = false
var hp_before: int = 0
var retreat_dx: float = 0.0
var x_at_hit: float = 0.0
var saw_crouch_block: bool = false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _ctx(dist: float, over: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {
		"dist": dist, "hp_ratio": 1.0, "opp_state": "Idle", "opp_frame": 0,
		"opp_startup": 0, "opp_active_end": 0, "atk_cd": 0.0, "retreat": 0.0, "roll": 0.5,
	}
	for k in over.keys():
		ctx[k] = over[k]
	return ctx

func _initialize() -> void:
	# 自立地板（否則兩人都會一直下墜，AI 永遠處於空中姿態）
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(900.0, 900.0)
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2400.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	root.add_child(floor_body)

	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	a = packed.instantiate()
	b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.is_player1 = true
	a.set_physics_process(false)   # 假人完全靜止，不干擾 AI 判定
	b.is_player1 = false           # 伥鬼 AI

	# ---- 伥鬼数值：HP 由主场景给 180；出手 startup 比操作角色慢 2／3 帧 ----
	_check("enemy Light1 startup 8", int(b._spec("Light1").get("logic", {}).get("startup", 0)) == 8)
	_check("enemy Heavy startup 15", int(b._spec("Heavy").get("logic", {}).get("startup", 0)) == 15)
	_check("enemy Light1 total 24 frames", int(DATA.total_frames(b._spec("Light1"))) == 24)
	_check("player Light1 stays 6", int(a._spec("Light1").get("logic", {}).get("startup", 0)) == 6)
	_check("global table untouched", int(DATA.spec("Light1").get("logic", {}).get("startup", 0)) == 6)

	# ---- A. 純決策：距離分檔 ----
	_check("far (>300) -> approach", b.ai_plan(_ctx(420.0)) == "approach")
	_check("mid (150..300) rolls dash", b.ai_plan(_ctx(200.0, {"roll": 0.1})) == "dash_attack")
	_check("mid (150..300) otherwise walks", b.ai_plan(_ctx(200.0, {"roll": 0.9})) == "approach")
	_check("close rolls light", b.ai_plan(_ctx(120.0, {"roll": 0.9})) == "light")
	_check("close rolls heavy", b.ai_plan(_ctx(120.0, {"roll": 0.1})) == "heavy")
	_check("close but cooling -> wait", b.ai_plan(_ctx(120.0, {"atk_cd": 0.4})) == "wait")

	# ---- 架招 / 懲罰 ----
	_check("opp startup & close -> block",
		b.ai_plan(_ctx(160.0, {"opp_state": "Heavy", "opp_frame": 3, "opp_active_end": 12})) == "block")
	_check("opp active & close -> block",
		b.ai_plan(_ctx(160.0, {"opp_state": "Heavy", "opp_frame": 13, "opp_active_end": 16})) == "block")
	_check("opp recovery & close -> heavy punish",
		b.ai_plan(_ctx(160.0, {"opp_state": "Heavy", "opp_frame": 20, "opp_active_end": 16})) == "heavy")
	_check("opp startup but far -> no block",
		b.ai_plan(_ctx(320.0, {"opp_state": "Heavy", "opp_frame": 3, "opp_active_end": 12})) == "approach")

	# ---- 被打後退 / 低血亂揮 ----
	_check("retreat timer -> retreat", b.ai_plan(_ctx(120.0, {"retreat": 0.3})) == "retreat")
	_check("low hp & close -> light", b.ai_plan(_ctx(120.0, {"hp_ratio": 0.2, "roll": 0.9})) == "light")
	_check("low hp & far -> approach", b.ai_plan(_ctx(420.0, {"hp_ratio": 0.2})) == "approach")
	_check("hp 0.35 is not panic (respects cd)",
		b.ai_plan(_ctx(120.0, {"hp_ratio": 0.35, "atk_cd": 0.3, "roll": 0.9})) == "wait")
	# ---- B. 決策合法性：大量 roll 掃描 ----
	var legal: bool = true
	for i in 100:
		var p: String = b.ai_plan(_ctx(120.0, {"hp_ratio": 0.9, "roll": float(i) / 100.0}))
		if not (p in AI_PLANS):
			legal = false
	_check("all plans legal for 100 rolls", legal)
	_check("never yields crouch/jump/throw", not _contains_forbidden())
	a.position = Vector2(400.0, 820.0)
	b.position = Vector2(1000.0, 820.0)
	a.face_direction = 1.0
	b.face_direction = -1.0
	b._ai_cd = 0.0
	start_dist = absf(b.position.x - a.position.x)
	hp_before = a.current_hp
	physics_frame.connect(_on_physics)

func _contains_forbidden() -> bool:
	for p in AI_PLANS:
		if p in ["jump", "air", "crouch", "block_crouch", "throw"]:
			return true
	return false

func _on_physics() -> void:
	n += 1
	if phase == 0:
		if n == 1:
			# _ready/_physics 在首帧才真正生效，血量基准與凍結都要等到這時
			a.set_physics_process(false)
			hp_before = a.current_hp
			start_dist = absf(b.position.x - a.position.x)
		var dist: float = absf(b.position.x - a.position.x)
		min_dist = minf(min_dist, dist)
		if b._state in ["Light1", "Light2", "Heavy", "CmdTiger"]:
			saw_attack = true
		# 落地後的空中姿態只可能來自跳躍（伥鬼不會跳）
		if n > 90 and b._state in ["AirUp", "AirLight", "AirHeavy"]:
			saw_jump = true
		if b._jump_pressed:
			saw_jump = true
		if n == 420:
			_check("AI approaches (min_dist < start)", min_dist < start_dist - 100.0)
			_check("AI attacked P1", saw_attack and a.current_hp < hp_before)
			_check("AI never jumps", not saw_jump)
			a.current_hp = a.max_hp
			x_at_hit = b.position.x
			b.current_hp = 1        # 壓到低血線，順便驗 panic 節奏
			b.take_damage(10, -1.0, 0.0)   # 從右側被擊中 → 擊退往左，AI 應往右退
			_check("hit sets retreat timer", b._ai_retreat > 0.0)
			phase = 1
			n = 0
	elif phase == 1:
		if n == 30:
			# 被打後退：0.5s 內應往遠離 P1 的方向移動（P1 在左側 → x 變大）
			_check("retreats after being hit", b.position.x > x_at_hit + 2.0)
			# 第三段：凍結的對手起重招（停在 startup 幀）→ 伥鬼應持續站防
			b.current_hp = 100
			a.position = Vector2(b.position.x - 160.0, b.position.y)
			a.change_state("Heavy")
			a._frame = 4
			phase = 2
			n = 0
	elif phase == 2:
		if b._state == "CrouchBlock":
			saw_crouch_block = true
		if n == 14:
			_check("blocks player startup (stand block)", b._state == "Block")
			_check("block flag + stand defense", b.is_blocking and b._defense == "stand")
			_check("never crouch-blocks", not saw_crouch_block)
			print("SELFTEST ai min_dist=", min_dist, " retreat_dx=", b.position.x - x_at_hit,
				" fails=", fails.size())
			quit(0 if fails.is_empty() else 1)
