extends CharacterBody2D
## 武松格鬥控制器（60fps 邏輯幀驅動；姿態由 frame_animator 毫秒序列播放）
##
## 時鐘分工：
##   每個 _physics_process = 1 邏輯幀（60fps，16.667ms），判定/取消/硬直以此計數
##   視覺姿態序列由 frame_animator 按 spec.visual.fps（預設 30fps / 33.333ms）換幀
## 所有招式數值來自 data/action_frame_data.gd，與 docs/06 Frame Data 對齊。

const DATA := preload("res://data/action_frame_data.gd")

@export var is_player1: bool = true
@export var walk_speed: float = 220.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

# 戰鬥資源
var max_hp: int = 800
var current_hp: int
var wine_gauge: float = 0.0
var face_direction: float = 1.0
var opponent = null
var is_blocking: bool = false

# 狀態機
var _state: String = "Idle"
var _frame: int = 0
var _has_hit: bool = false

# 輸入
var _move_x: float = 0.0
var _down: bool = false
var _jump_pressed: bool = false
var _light_pressed: bool = false
var _heavy_pressed: bool = false
var _block_held: bool = false
var _dash_pressed: bool = false
var _drink_pressed: bool = false

# P2 AI 冷卻
var _ai_cd: float = 0.8

# 狀態分組（與 data spec 對應）
const ATTACKS: Array = ["Light1", "Light2", "Light3", "Heavy", "CrouchLight", "AirLight", "AirHeavy", "CmdTiger", "CmdUp", "Super"]
const REACTION: Array = ["HurtStand", "HurtAir", "Knockdown", "WakeUp"]

func _ready() -> void:
	current_hp = max_hp
	face_direction = 1.0 if is_player1 else -1.0
	change_state("Idle")

func change_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	_frame = 0
	_has_hit = false
	velocity.x = 0.0
	_set_attack_shape(false)  # 離開招式一律關閉攻擊盒，避免殘留命中判定

func _physics_process(delta: float) -> void:
	_read_input()
	if not is_player1:
		_run_ai(delta)

	var spec: Dictionary = DATA.spec(_state)

	# Reaction 層最高優先級：受擊/倒地/起身只推進時鐘與物理，不接受攻擊輸入
	if _state in REACTION:
		_frame += 1
		_apply_gravity(delta)
		move_and_slide()
		$Visual.play_action(_state, spec, delta)
		if _frame >= DATA.total_frames(spec):
			change_state("Idle")
		return

	# 一次性動作（攻擊 / Dash / Drink / Land…）
	if not bool(spec.loop) and DATA.total_frames(spec) > 0:
		_frame += 1
		if _state in ATTACKS:
			_try_hit(spec)
			if _try_cancel():
				return  # 取消切入新狀態，下一幀按新狀態處理
		_apply_gravity(delta)
		if _state == "Dash":
			velocity.x = face_direction * 480.0
		else:
			velocity.x = 0.0
		move_and_slide()
		$Visual.play_action(_state, spec, delta)
		if _frame >= DATA.total_frames(spec):
			change_state("Idle")
		return

	# 自由姿態層：決定狀態 → 物理 → 播放
	_decide_free_state(delta)
	_apply_gravity(delta)
	move_and_slide()
	_face_opponent_when_free()
	$Visual.play_action(_state, DATA.spec(_state), delta)

func _read_input() -> void:
	if is_player1:
		_move_x = Input.get_axis("p1_left", "p1_right")
		_down = Input.is_action_pressed("p1_down")
		_jump_pressed = Input.is_action_just_pressed("p1_jump")
		_light_pressed = Input.is_action_just_pressed("p1_light")
		_heavy_pressed = Input.is_action_just_pressed("p1_heavy")
		_block_held = Input.is_action_pressed("p1_block")
		_dash_pressed = Input.is_action_just_pressed("p1_dash")
		_drink_pressed = Input.is_action_just_pressed("p1_drink")
	else:
		_move_x = 0.0
		_down = false
		_jump_pressed = false
		_light_pressed = false
		_heavy_pressed = false
		_block_held = false
		_dash_pressed = false
		_drink_pressed = false

func _run_ai(delta: float) -> void:
	if opponent == null:
		return
	var dx: float = opponent.global_position.x - global_position.x
	_move_x = signf(dx) * 0.55
	_ai_cd -= delta
	if absf(dx) < 150.0 and _ai_cd <= 0.0 and _state == "Idle":
		_light_pressed = true
		_ai_cd = 1.4
	elif absf(dx) >= 150.0:
		_ai_cd = maxf(_ai_cd, 0.2)

func _decide_free_state(_delta: float) -> void:
	# 空中姿態派生
	if not is_on_floor():
		if _light_pressed:
			change_state("AirLight")
			return
		if _heavy_pressed:
			change_state("AirHeavy")
			return
		change_state("AirUp" if velocity.y < 0.0 else "AirDown")
		return

	if _jump_pressed:
		velocity.y = jump_velocity
		change_state("AirUp")
		return
	if _dash_pressed:
		change_state("Dash")
		return
	if _drink_pressed:
		change_state("Drink")
		return
	if _light_pressed:
		change_state("Light1")
		return
	if _heavy_pressed:
		change_state("Heavy")
		return
	if _block_held:
		change_state("Block")
		is_blocking = true
		return

	is_blocking = false
	if _down:
		change_state("Crouch")
		velocity.x = 0.0
		return
	if absf(_move_x) > 0.1:
		change_state("Walk")
		velocity.x = _move_x * walk_speed
		return
	change_state("Idle")
	velocity.x = 0.0

## 取消鏈：僅在取消幀之後、且招式允許時切入（對齊 06 §3.6）
func _try_cancel() -> bool:
	var spec: Dictionary = DATA.spec(_state)
	var cancel_frame: int = int(spec.get("cancel_frame", -1))
	if cancel_frame < 0 or _frame < cancel_frame:
		return false
	if _state == "Light1" and _light_pressed:
		change_state("Light2")
		return true
	if _state == "Light2" and _light_pressed:
		change_state("Light3")
		return true
	if (_state == "Light1" or _state == "Light2" or _state == "Heavy") and _heavy_pressed:
		change_state("Heavy")
		return true
	return false

func _try_hit(spec: Dictionary) -> void:
	if DATA.is_invulnerable(spec, _frame):
		_set_attack_shape(false)
		return
	if not DATA.is_active_frame(spec, _frame):
		_set_attack_shape(false)
		return
	# 活躍幀：攻擊盒移到朝向側並啟用，以實體 Area2D 重疊取代舊 dx/dy 距離比較
	var shape_node: CollisionShape2D = get_node("HitBox/AttackShape")
	shape_node.position = Vector2(face_direction * 90.0, -90.0)
	shape_node.set_disabled(false)
	if _has_hit:
		return
	var dmg: int = int(spec.get("damage", 0))
	for area in get_node("HitBox").get_overlapping_areas():
		var target = _fighter_of(area)
		if target == null or target == self:
			continue
		if target.is_blocking:
			target.on_blocked(dmg / 2, face_direction)
		else:
			target.take_damage(dmg, face_direction, float(spec.get("knock_up", 0.0)))
			_has_hit = true
			wine_gauge = minf(100.0, wine_gauge + 3.0)
			break

## 重疊到的 Area2D 若是對手 HurtBox，回傳其所屬角色控制器節點
func _fighter_of(area: Area2D):
	var parent_node: Node = area.get_parent()
	if parent_node != null and parent_node.has_method("take_damage"):
		return parent_node
	return null

## 啟用/關閉攻擊盒；節點尚未就緒時安全跳過
func _set_attack_shape(enabled: bool) -> void:
	var n := get_node_or_null("HitBox/AttackShape")
	if n != null:
		n.set_disabled(not enabled)

func take_damage(dmg: int, from_dir: float, knock_up: float = 0.0) -> void:
	var spec: Dictionary = DATA.spec(_state)
	if DATA.is_invulnerable(spec, _frame):
		return
	current_hp -= dmg
	wine_gauge = minf(100.0, wine_gauge + 5.0)
	velocity = Vector2(from_dir * 200.0, -100.0 if knock_up <= 0.0 else -knock_up)
	change_state("HurtStand")

func on_blocked(dmg: int, from_dir: float) -> void:
	current_hp -= dmg
	velocity.x = from_dir * 80.0

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _face_opponent_when_free() -> void:
	if opponent == null or _state not in ["Idle", "Walk", "Crouch", "Block"]:
		return
	var target: float = 1.0 if opponent.global_position.x > global_position.x else -1.0
	if target != face_direction:
		face_direction = target
	$Visual.scale.x = absf($Visual.scale.x) * face_direction
