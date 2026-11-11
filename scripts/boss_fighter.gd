extends "res://scripts/rigged_fighter.gd"
## 景陽岡猛虎 Boss：三階段、削韌霸體、多受擊盒、階段招式（docs/10-BOS-01）
## 以 RiggedFighter 為基底，只覆寫 Boss 專屬決策；小虎與武松路徑完全不受影響。

const BOSS_IDLE: String = "BossIdle"
const BOSS_WALK: String = "BossWalk"
const BOSS_HURT: String = "BossHurt"
const BOSS_KNOCKDOWN: String = "BossKnockdown"
const BOSS_DEATH: String = "BossDeath"
const BOSS_PHASE: String = "BossPhase"
const BOSS_WALK_SPEED: float = 160.0
const BOSS_DASH_SPEED: float = 240.0
const BOSS_POISE_MAX: int = 320
const BOSS_PHASE_TIME: float = 1.2
const BOSS_HP_PHASE2: float = 0.66
const BOSS_HP_PHASE3: float = 0.33
const TIGER_SCENE := preload("res://scenes/Tiger.tscn")

var boss_phase: int = 1
var boss_poise: int = 0
var boss_transition_t: float = 0.0
var boss_pending_phase: int = 0
var boss_death_pounce_used: bool = false
var boss_summon_cd: float = 0.0
var boss_summoned: Array = []
var boss_retreat_t: float = 0.0
var boss_fight_started: bool = false
var boss_roar_done: bool = false
var _boss_booted: bool = false

func _ready() -> void:
	super._ready()
	# 三塊受擊盒的倍率在 Boss.tscn 的 metadata/damage_mult 裡；這裡只保證初始腹部關閉。
	_set_belly(false)
	boss_phase = 1
	boss_poise = 0
	boss_death_pounce_used = false

func _idle_state() -> String:
	return BOSS_IDLE

## 自由姿態層：Boss 的 AI 已經決定 BossWalk/BossIdle，不能被武松那套 Idle/Walk 覆蓋。
func _decide_free_state(_delta: float) -> void:
	if _state in BOSS_ATTACKS or _state == BOSS_PHASE or _state in BOSS_REACTION:
		return
	if not is_on_floor():
		change_state(BOSS_IDLE)
		return
	if _state != BOSS_WALK and _state != BOSS_IDLE:
		change_state(BOSS_IDLE)

func _death_state() -> String:
	return BOSS_DEATH

func _hurt_state(kind: String) -> String:
	if kind == "Knockdown":
		return BOSS_KNOCKDOWN
	if kind == "WakeUp":
		return BOSS_IDLE
	return BOSS_HURT

func change_state(new_state: String) -> void:
	if new_state == "BossRoar":
		boss_roar_done = false
	super.change_state(new_state)
	# 腹部 ×2 只在倒地窗口開啟；其餘時間關閉，避免和身體盒重複結算。
	_set_belly(new_state == BOSS_KNOCKDOWN)

func _boss_boot() -> void:
	current_hp = max_hp
	boss_phase = 1
	boss_poise = 0
	boss_death_pounce_used = false
	if _state != start_state:
		change_state(start_state)
	_set_belly(false)

func _set_belly(enabled: bool) -> void:
	var shape := get_node_or_null("BellyBox/BellyShape") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not enabled)

func _physics_process(delta: float) -> void:
	# 繼承場景的 export 覆寫晚於 _ready：首個物理幀讀到的才是 max_hp/start_state 真值。
	if not _boss_booted:
		_boss_boot()
		_boss_booted = true
	if boss_transition_t > 0.0:
		boss_transition_t = maxf(0.0, boss_transition_t - delta)
		if boss_transition_t <= 0.0 and boss_pending_phase > 0:
			boss_phase = boss_pending_phase
			boss_pending_phase = 0
			boss_poise = 0
			boss_death_pounce_used = false
	super._physics_process(delta)

func _run_ai(delta: float) -> void:
	if opponent == null or not is_instance_valid(opponent):
		return
	boss_fight_started = true
	var dx: float = opponent.global_position.x - global_position.x
	var dist: float = absf(dx)
	_ai_cd = maxf(0.0, _ai_cd - delta)
	boss_summon_cd = maxf(0.0, boss_summon_cd - delta)
	boss_retreat_t = maxf(0.0, boss_retreat_t - delta)
	# 黃金比例步進，保持自測可重現
	_ai_roll = fmod(_ai_roll + 0.6180339887, 1.0)
	if _state == BOSS_PHASE or boss_transition_t > 0.0:
		return
	if _state in BOSS_ATTACKS:
		_tick_summon()
		_tick_roar()
		return
	if not is_on_floor():
		return
	_tick_summon()
	_boss_apply(_boss_plan(dist), dx, dist)

## 決策純函數：只讀 dist/phase/roll/cooldowns，回傳動作名
func boss_plan(dist: float, phase: int, roll: float, atk_cd: float, summon_cd: float, retreat: float) -> String:
	if atk_cd > 0.0:
		if dist > 330.0:
			return "approach"
		return "wait"
	if phase == 1:
		if retreat > 0.0:
			return "retreat"
		if dist > 520.0:
			return "approach"
		if dist > 300.0:
			if roll < 0.55:
				return "pounce"
			if roll < 0.85:
				return "approach"
			return "retreat"
		if roll < 0.45:
			return "pounce"
		if roll < 0.80:
			return "tail"
		return "retreat"
	if phase == 2:
		if dist > 520.0:
			return "approach"
		if dist > 300.0:
			return "rear" if roll < 0.45 else "approach"
		if summon_cd <= 0.0 and roll < 0.18:
			return "summon"
		if roll < 0.40:
			return "rear"
		if roll < 0.62:
			return "roar"
		return "tail"
	# phase 3：不再後退、不再召小虎
	if dist > 520.0:
		return "approach"
	if dist > 340.0:
		return "pounce" if roll < 0.60 else "rib"
	if roll < 0.42:
		return "iron"
	if roll < 0.62:
		return "death"
	if roll < 0.85:
		return "pounce"
	return "rib"

func _boss_plan(dist: float) -> String:
	return boss_plan(dist, boss_phase, _ai_roll, _ai_cd, boss_summon_cd, boss_retreat_t)

func _boss_apply(plan: String, dx: float, _dist: float) -> void:
	var toward: float = signf(dx) if absf(dx) > 0.01 else face_direction
	face_direction = toward
	match plan:
		"approach":
			if _state != BOSS_WALK:
				change_state(BOSS_WALK)
			velocity.x = toward * BOSS_WALK_SPEED
		"retreat":
			if _state != BOSS_WALK:
				change_state(BOSS_WALK)
			velocity.x = -toward * BOSS_WALK_SPEED
			boss_retreat_t = maxf(boss_retreat_t, 0.8)
		"wait":
			if _state != BOSS_IDLE:
				change_state(BOSS_IDLE)
			velocity.x = 0.0
		"pounce", "tail", "rear", "roar", "summon", "iron", "death", "rib":
			_start_boss_attack(plan, toward)

func _start_boss_attack(plan: String, toward: float) -> void:
	if _state in BOSS_ATTACKS or _dying:
		return
	var target: String = ""
	match plan:
		"pounce": target = "BossPounce" if boss_phase < 3 else "BossPounceP3"
		"tail": target = "BossTail"
		"rear": target = "BossRearUp" if boss_phase < 3 else "BossRearUpP3"
		"roar": target = "BossRoar"
		"summon": target = "BossSummon"
		"iron": target = "BossIronTail"
		"death": target = "BossDeathPounce"
		"rib": target = "BossRearUpP3"
	if target == "BossDeathPounce":
		if boss_death_pounce_used:
			target = "BossIronTail"
			if boss_phase < 3:
				target = "BossPounceP3"
		else:
			boss_death_pounce_used = true
	if target == "BossSummon":
		if boss_summon_cd > 0.0:
			target = "BossTail"
		else:
			boss_summon_cd = 12.0
	var spec: Dictionary = _spec(target)
	_ai_cd = float(spec.get("cooldown", 2.0))
	change_state(target)
	# 撲擊類起手先給一點前衝；base 的 vx 欄位會在活躍窗口維持速度
	if "vx" in spec:
		velocity.x = toward * float(spec.get("vx", 0.0))

func _tick_summon() -> void:
	if _state != "BossSummon" or _frame != 20:
		return
	_clean_summoned()
	var count: int = boss_summoned.size()
	if count >= 2:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i in range(2 - count):
		var tiger: Node2D = TIGER_SCENE.instantiate()
		var side: float = -1.0 if i % 2 == 0 else 1.0
		tiger.position = global_position + Vector2(side * 220.0, 0.0)
		tiger.opponent = opponent
		tiger.ai_profile = "tiger"
		parent_node.add_child(tiger)
		boss_summoned.append(tiger)

func _clean_summoned() -> void:
	var alive: Array = []
	for t in boss_summoned:
		if is_instance_valid(t) and not t._dying:
			alive.append(t)
	boss_summoned = alive

## 咆哮：18–29 活躍窗口內，半徑 300 的玩家吃 30 幀硬直；背對（背向 Boss）減半為 15
func _tick_roar() -> void:
	if _state != "BossRoar" or boss_roar_done:
		return
	if _frame < 18 or _frame >= 30:
		return
	if opponent == null or not is_instance_valid(opponent):
		return
	if absf(opponent.global_position.x - global_position.x) > 300.0:
		return
	var away: float = signf(opponent.global_position.x - global_position.x)
	var back_turned: bool = absf(opponent.face_direction - away) < 0.01
	boss_roar_done = true
	opponent.apply_stun(15 if back_turned else 30)

func take_damage(dmg: int, from_dir: float, knock_up: float = 0.0) -> void:
	if _dying:
		return
	if _state == BOSS_PHASE:
		return
	var spec: Dictionary = _spec(_state)
	if DATA.is_invulnerable(spec, _frame):
		return
	current_hp -= dmg
	current_hp = maxi(current_hp, 0)
	if current_hp <= 0:
		_begin_death()
		return
	# 階段門檻：66% / 33%，一次跨兩線只演一次轉場，直接進最高階段
	var next_phase: int = boss_phase
	if boss_phase == 1 and float(current_hp) <= float(max_hp) * BOSS_HP_PHASE2:
		next_phase = 2
	if boss_phase <= 2 and float(current_hp) <= float(max_hp) * BOSS_HP_PHASE3:
		next_phase = 3
	if next_phase > boss_phase:
		boss_pending_phase = next_phase
		boss_transition_t = BOSS_PHASE_TIME
		boss_poise = 0
		change_state(BOSS_PHASE)
		velocity = Vector2.ZERO
		return
	# 削韌：累積 ceil(dmg*0.5)；滿 320 才破防，否則霸體不進受擊
	boss_poise += int(ceil(float(dmg) * 0.5))
	if boss_poise >= BOSS_POISE_MAX:
		boss_poise = 0
		change_state(BOSS_HURT)
		velocity = Vector2(from_dir * 120.0, -60.0)
		return
	velocity.x = 0.0

func _begin_death() -> void:
	if _dying:
		return
	_dying = true
	_death_done = false
	_death_t = 0.0
	_ai_cd = 999.0
	boss_transition_t = 0.0
	velocity = Vector2.ZERO
	var cine := get_node_or_null("BossDeathCine")
	if cine != null and cine.has_method("play"):
		cine.play()
	change_state(BOSS_DEATH)

func _finish_death() -> void:
	_death_done = true
	$Visual.visible = false
	$Collision.set_deferred("disabled", true)
	for box_name in ["HurtBox", "HeadBox", "BellyBox"]:
		var box := get_node_or_null(box_name) as Area2D
		if box != null:
			box.set_deferred("monitorable", false)
			box.set_deferred("monitoring", false)
