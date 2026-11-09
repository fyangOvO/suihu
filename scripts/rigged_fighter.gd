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
var _defense: String = "none"   # none / stand / crouch / air（驅動差異化減傷與退卻）

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
var _super_pressed: bool = false
var _dir_history: Array = []   # 最近相對方向事件（舊→新），供 214 指令緩衝判定

# P2 AI 冷卻
var _ai_cd: float = 0.8

# 狀態分組（與 data spec 對應）
const ATTACKS: Array = ["Light1", "Light2", "Light3", "Heavy", "CrouchLight", "AirLight", "AirHeavy", "CmdTiger", "CmdUp", "Counter", "Super"]
const REACTION: Array = ["HurtStand", "HurtAir", "Knockdown", "WakeUp"]

# 防禦減傷比例（站防 / 蹲防 / 空防）
const GUARD_RATIO := {"stand": 0.5, "crouch": 0.35, "air": 0.4}
const SUPER_REQUIRE_WINE: float = 100.0
const CMD_BUFFER_FRAMES: int = 18   # 指令輸入緩衝窗口（邏輯幀），用於 214 方向序列識別

func _ready() -> void:
	current_hp = max_hp
	face_direction = 1.0 if is_player1 else -1.0
	change_state("Idle")

func change_state(new_state: String) -> void:
	if _state == new_state:
		return
	var old_state := _state
	_state = new_state
	_frame = 0
	_has_hit = false
	velocity.x = 0.0
	_set_attack_shape(false)  # 離開招式一律關閉攻擊盒，避免殘留命中判定
	# 防禦姿態標記 + 派生 blocking 旗標
	if new_state == "Block":
		_defense = "stand"
	elif new_state == "CrouchBlock":
		_defense = "crouch"
	elif new_state == "AirBlock":
		_defense = "air"
	else:
		_defense = "none"
	is_blocking = _defense != "none"
	# 覺醒演出結束後清空酒氣
	if old_state == "Super" and new_state != "Super":
		wine_gauge = 0.0
	# 指令技出手後清空指令緩衝，避免同一次輸入重複觸發
	if new_state in ["Counter", "CmdTiger", "CmdUp"]:
		_dir_history.clear()

func _physics_process(delta: float) -> void:
	_read_input()
	_update_super_effect()
	if not is_player1:
		_run_ai(delta)

	var spec: Dictionary = DATA.spec(_state)

	# Reaction 層最高優先級：受擊/倒地/起身只推進時鐘與物理，不接受攻擊輸入
	if _state in REACTION:
		_frame += 1
		# 被擊瞬間（前4邏輯幀）按重可搶出飞云浦反击 Counter
		if _state == "HurtStand" and _frame <= 4 and _heavy_pressed:
			change_state("Counter")
			return
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
	$Visual.play_action(_play_state(), DATA.spec(_play_state()), delta)

## 滿酒氣待機時切換為拔刀覺醒立繪（僅替換播放姿態，狀態機與判定不變）
func _play_state() -> String:
	if _state == "Idle" and wine_gauge >= SUPER_REQUIRE_WINE:
		return "AwakenIdle"
	return _state

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
		_super_pressed = Input.is_action_just_pressed("p1_super")
		_record_relative_dir()
	else:
		_move_x = 0.0
		_down = false
		_jump_pressed = false
		_light_pressed = false
		_heavy_pressed = false
		_block_held = false
		_dash_pressed = false
		_drink_pressed = false
		_super_pressed = false
		_dir_history.clear()

## 記錄本幀相對朝向的方向事件，維持指令緩衝窗口（舊→新）
## 採數字小鍵盤語義（相對朝向）：5 中 / 2 下 / 1 下後 / 3 下前 / 4 後 / 6 前 / 7 上後 / 8 上 / 9 上前
func _record_relative_dir() -> void:
	var raw: float = Input.get_axis("p1_left", "p1_right")
	var up: bool = Input.is_action_pressed("p1_up")
	var rel: String = "5"
	if _down:
		if raw < -0.1:
			rel = "1"      # 下後
		elif raw > 0.1:
			rel = "3"      # 下前
		else:
			rel = "2"      # 下
	elif up:
		if raw < -0.1:
			rel = "7"
		elif raw > 0.1:
			rel = "9"
		else:
			rel = "8"
	elif absf(raw) > 0.1:
		var toward_forward: bool = (raw > 0.0) == (face_direction > 0.0)
		rel = "6" if toward_forward else "4"
	_dir_history.append(rel)
	if _dir_history.size() > CMD_BUFFER_FRAMES:
		_dir_history.pop_front()

## 在緩衝窗口內按時間先後匹配方向序列（允許中間夾雜中立/其他方向）
func _has_cmd(order: Array) -> bool:
	var idx: int = 0
	for token in _dir_history:
		if token == order[idx]:
			idx += 1
			if idx >= order.size():
				return true
	return false

## 214 下→下後→後（↓↙←），防禦反擊
func _has_214() -> bool:
	return _has_cmd(["2", "1", "4"])

## 236 下→下前→前（↓↘→），打虎拳
func _has_236() -> bool:
	return _has_cmd(["2", "3", "6"])

## 623 前→下→下前（→↓↘），昇龍對空
func _has_623() -> bool:
	return _has_cmd(["6", "2", "3"])

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
	# 空中姿態派生：空防優先於空中攻擊
	if not is_on_floor():
		if _block_held:
			change_state("AirBlock")
			return
		if _light_pressed:
			change_state("AirLight")
			return
		if _heavy_pressed:
			change_state("AirHeavy")
			return
		change_state("AirUp" if velocity.y < 0.0 else "AirDown")
		return

	# 地面一次性觸發：覺醒必殺（酒氣滿100）
	if _super_pressed and wine_gauge >= SUPER_REQUIRE_WINE:
		change_state("Super")
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
	# 防禦中按重 → 飛雲浦反擊（招架無敵後出手，簡化觸發）
	if _heavy_pressed and _state in ["Block", "CrouchBlock"]:
		change_state("Counter")
		return
	# 完整指令技（共用方向緩衝隊列；重鍵觸發，優先級 214 > 623 > 236）
	if _heavy_pressed:
		if _has_214():
			change_state("Counter")
			return
		if _has_623():
			change_state("CmdUp")
			return
		if _has_236():
			change_state("CmdTiger")
			return
	if _light_pressed:
		change_state("Light1")
		return
	if _heavy_pressed:
		change_state("Heavy")
		return
	# 防禦姿態分化：站防 / 蹲防
	if _block_held:
		if _down:
			change_state("CrouchBlock")
		else:
			change_state("Block")
		return

	# 自由移動層
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
	# 出招方無敵（invuln）只在被打方 take_damage 判定；不關閉己方攻擊盒，否則 Super/CmdDrunk 永遠打不中
	if not DATA.is_active_frame(spec, _frame):
		_set_attack_shape(false)
		return
	if int(spec.get("damage", 0)) <= 0:
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
			target.on_blocked(dmg, face_direction, float(spec.get("knock_up", 0.0)))
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

func on_blocked(dmg: int, from_dir: float, knock_up: float = 0.0) -> void:
	# 依防禦姿態折減傷害與擊退；空防不被向上挑空
	var ratio: float = float(GUARD_RATIO.get(_defense, 0.5))
	var push: float = 80.0
	if _defense == "crouch":
		push = 50.0
	elif _defense == "air":
		push = 60.0
	current_hp -= int(round(float(dmg) * ratio))
	velocity.x = from_dir * push
	if _defense == "air":
		velocity.y = minf(velocity.y, 0.0)
	elif knock_up <= 0.0:
		velocity.y = 0.0

## 覺醒 Super 金黃脈衝演出；非 Super 狀態復原原色（以 modulate 脈衝代替外部特效素材）
func _update_super_effect() -> void:
	var vis: Node2D = get_node_or_null("Visual")
	if vis == null:
		return
	if _state == "Super":
		var pulse: float = 0.5 + 0.5 * sin(float(_frame) * 0.35)
		vis.modulate = Color(1.0 + 0.35 * pulse, 0.95 + 0.20 * pulse, 0.45 + 0.45 * pulse)
	elif _state == "Idle" and wine_gauge >= SUPER_REQUIRE_WINE:
		# 滿氣待機：柔和金輝呼吸，與 Super 的強脈衝區分
		var breath: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
		vis.modulate = Color(1.0, 0.94 + 0.10 * breath, 0.72 + 0.22 * breath)
	elif vis.modulate != Color(1.0, 1.0, 1.0):
		vis.modulate = Color(1.0, 1.0, 1.0)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

func _face_opponent_when_free() -> void:
	if opponent == null or _state not in ["Idle", "Walk", "Crouch", "Block", "CrouchBlock"]:
		return
	var target: float = 1.0 if opponent.global_position.x > global_position.x else -1.0
	if target != face_direction:
		face_direction = target
	$Visual.scale.x = absf($Visual.scale.x) * face_direction
