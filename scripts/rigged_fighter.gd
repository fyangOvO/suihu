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
var _special_pressed: bool = false
var _super_pressed: bool = false
var _drunk_cd: float = 0.0      # 醉打蔣門神冷卻（秒）
var _dir_history: Array = []   # 最近相對方向事件（舊→新），供 214 指令緩衝判定

# P2 AI 冷卻
var _ai_cd: float = 0.8
var _ai_retreat: float = 0.0    # 被打後退計時（秒）
var _ai_roll: float = 0.0       # 決策用確定性序列（低差異，無隨機源也能重現）

# 牆族：黏牆期間牆所在方向（+1 右 / -1 左）、最近一次額外傷害（供自測讀取）
var _wall_side: float = 0.0
var _wall_bonus_last: int = 0

# 狀態分組（與 data spec 對應）
const ATTACKS: Array = ["Light1", "Light2", "Light3", "Heavy", "CrouchLight", "AirLight", "AirHeavy", "CmdTiger", "CmdUp", "Counter", "CmdDrunk", "Super"]
const REACTION: Array = ["HurtStand", "HurtAir", "Knockdown", "WakeUp"]

# 防禦減傷比例（站防 / 蹲防 / 空防）
const GUARD_RATIO := {"stand": 0.5, "crouch": 0.35, "air": 0.4}
const SUPER_REQUIRE_WINE: float = 100.0
# 牆族（牆邊連段獎勵）：被擊退時背已貼牆 → 額外傷害 + 黏牆 30 幀 + 彈回可追打（docs/01 §牆族）
const WALL_BONUS_RATIO: float = 0.25
const WALL_BONUS_MIN: int = 10
const WALL_PROBE: float = 20.0      # 牆面偵測探針長度（px）
const WALL_BOUNCE_X: float = 320.0
const WALL_BOUNCE_Y: float = 280.0
const CMD_BUFFER_FRAMES: int = 18   # 指令輸入緩衝窗口（邏輯幀），用於 214 方向序列識別
const DRUNK_CD: float = 4.0         # 醉打蔣門神冷卻（06 §3.3）

# 伥鬼 AI（docs/04 §2：會站防、會輕攻、偶爾前衝棍擊；不會跳/不會蹲防；被打會後退；低血慌亂）
const AI_RANGE_HIT: float = 150.0        # 貼身出手距離
const AI_RANGE_THREAT: float = 220.0      # 對手出招時願意起防的距離
const AI_RANGE_PREFER: float = 300.0     # 超過此距離一律先接近
const AI_ATK_CD: float = 1.2             # 輕攻間隔
const AI_HEAVY_CD: float = 1.8           # 重攻間隔
const AI_PANIC_CD: float = 0.5           # 低血亂揮間隔
const AI_PANIC_HP: float = 0.3           # 30% 血線
const AI_HEAVY_RATE: float = 0.25        # 貼身時改出重招的概率
const AI_DASH_RATE: float = 0.25         # 中距離前衝棍擊的概率
const AI_WALK: float = 0.55              # 移速倍率（沿用原 AI 手感）
const AI_RETREAT_TIME: float = 0.5       # 被打後退持續（秒）
# 伥鬼出手比操作角色慢（docs/04 §2：站輕啟動 8 幀、站重 15 幀）——只加在非 P1 的實例上，
# 不动全局數據表，武松手感維持 6／12。
const ENEMY_STARTUP_BONUS: Dictionary = {"Light1": 2, "Heavy": 3}

## 動作規格：敵方實例在共用數據表上疊 startup 補償；回傳的字典已複製，改動不會污染 SPECS
func _spec(state_name: String) -> Dictionary:
	var base: Dictionary = DATA.spec(state_name)
	if is_player1:
		return base
	var bonus: int = int(ENEMY_STARTUP_BONUS.get(state_name, 0))
	if bonus <= 0:
		return base
	var lg: Dictionary = (base["logic"] as Dictionary).duplicate()
	lg["startup"] = int(lg.get("startup", 0)) + bonus
	var copy: Dictionary = base.duplicate(false)
	copy["logic"] = lg
	return copy

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
	# 醉打穿身：起手忽略對手身體碰撞（地面/牆仍保留），離開即恢復
	if new_state == "CmdDrunk":
		if opponent != null and is_instance_valid(opponent):
			add_collision_exception_with(opponent)
	elif old_state == "CmdDrunk":
		if opponent != null and is_instance_valid(opponent):
			remove_collision_exception_with(opponent)
	# 覺醒演出結束後清空酒氣
	if old_state == "Super" and new_state != "Super":
		wine_gauge = 0.0
	# 指令技出手後清空指令緩衝，避免同一次輸入重複觸發
	if new_state in ["Counter", "CmdTiger", "CmdUp"]:
		_dir_history.clear()
	_fx_state(new_state)

func _physics_process(delta: float) -> void:
	_read_input()
	_tick_cooldowns(delta)
	_update_super_effect()
	_fx_sync()
	if not is_player1:
		_run_ai(delta)

	var spec: Dictionary = _spec(_state)

	# 牆族：黏牆期間完全定身（不計重力），時長走完後彈回空中，可被浮空追打
	if _state == "WallStick":
		_frame += 1
		velocity = Vector2.ZERO
		$Visual.play_action(_state, spec, delta)
		if _frame >= DATA.total_frames(spec):
			# 先切狀態再賦速度：change_state 會清零 velocity.x，倒過來寫彈回就沒有水平分量
			change_state("HurtAir")
			velocity = Vector2(-_wall_side * WALL_BOUNCE_X, -WALL_BOUNCE_Y)
		return

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
		elif _state == "CmdDrunk" and _frame <= 13:
			velocity.x = face_direction * 360.0   # 醉打：僅起手＋活躍段前衝穿身
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
	$Visual.play_action(_play_state(), _spec(_play_state()), delta)

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
		_special_pressed = Input.is_action_just_pressed("p1_special")
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
		_special_pressed = false
		_super_pressed = false
		_dir_history.clear()

## 冷卻推進（醉打蔣門神 4s）
func _tick_cooldowns(delta: float) -> void:
	_drunk_cd = maxf(0.0, _drunk_cd - delta)

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
	var dist: float = absf(dx)
	_ai_cd = maxf(0.0, _ai_cd - delta)
	_ai_retreat = maxf(0.0, _ai_retreat - delta)
	# 確定性低差異序列（黃金比例步進）：同一串 ctx 每次跑出來的決策一致，自測可重現
	_ai_roll = fmod(_ai_roll + 0.6180339887, 1.0)
	_ai_apply(ai_plan(_ai_ctx(dist)), dx)

## 組 AI 決策上下文（欄位口徑固定，自測直接用合成 ctx 驗證純函數）
func _ai_ctx(dist: float) -> Dictionary:
	var opp_state: String = "Idle"
	var opp_spec: Dictionary = {}
	if opponent != null and is_instance_valid(opponent):
		opp_state = opponent._state
		opp_spec = opponent._spec(opp_state)
	var lg: Dictionary = opp_spec.get("logic", {})
	var startup: int = int(lg.get("startup", 0))
	var active_end: int = startup + int(lg.get("active", 0))
	var opp_frame: int = int(opponent._frame) if opponent != null and is_instance_valid(opponent) else 0
	return {
		"dist": dist,
		"hp_ratio": float(current_hp) / float(max_hp) if max_hp > 0 else 1.0,
		"opp_state": opp_state,
		"opp_frame": opp_frame,
		"opp_startup": startup,
		"opp_active_end": active_end,
		"atk_cd": _ai_cd,
		"retreat": _ai_retreat,
		"roll": _ai_roll,
	}

## 伥鬼決策（純函數：只讀 ctx，不碰節點狀態，便於無頭斷言）
## 回傳：retreat / block / heavy / light / dash_attack / approach / wait
func ai_plan(ctx: Dictionary) -> String:
	var dist: float = float(ctx.get("dist", 9999.0))
	var hp_ratio: float = float(ctx.get("hp_ratio", 1.0))
	var roll: float = float(ctx.get("roll", 0.0))
	var atk_cd: float = float(ctx.get("atk_cd", 0.0))
	var retreat: float = float(ctx.get("retreat", 0.0))
	var opp_state: String = String(ctx.get("opp_state", "Idle"))
	var opp_frame: int = int(ctx.get("opp_frame", 0))
	var opp_active_end: int = int(ctx.get("opp_active_end", 0))
	# 0. 剛被打：先退一步重組（docs/04「被打會後退」）
	if retreat > 0.0:
		return "retreat"
	# 1. 對手正在出招：起防；對手收招硬直才懲罰（教玩家架招與連段）
	if opp_state in ATTACKS:
		if opp_frame < opp_active_end:
			if dist <= AI_RANGE_THREAT:
				return "block"
		else:
			if dist <= AI_RANGE_HIT + 40.0:
				return "heavy"
	# 2. 低血線：貼身亂揮（間隔縮短），遠了照樣先靠近
	if hp_ratio < AI_PANIC_HP:
		if dist <= AI_RANGE_HIT and atk_cd <= 0.0:
			return "light"
		return "approach"
	# 3. 太遠：先接近
	if dist > AI_RANGE_PREFER:
		return "approach"
	# 4. 中距離：偶爾前衝棍擊，其餘走過去
	if dist > AI_RANGE_HIT:
		if atk_cd <= 0.0 and roll < AI_DASH_RATE:
			return "dash_attack"
		return "approach"
	# 5. 貼身：輕攻為主，四分之一改重招；冷卻中站著等
	if atk_cd > 0.0:
		return "wait"
	return "heavy" if roll < AI_HEAVY_RATE else "light"

## 把決策映射成虛擬輸入（沿用 P1 的同一套輸入旗標，不另開 AI 專用狀態機）
func _ai_apply(plan: String, dx: float) -> void:
	var toward: float = signf(dx) if absf(dx) > 0.01 else face_direction
	_move_x = 0.0
	_block_held = false
	match plan:
		"approach":
			_move_x = toward * AI_WALK
		"retreat":
			_move_x = -toward * AI_WALK
		"block":
			_block_held = true
		"light":
			if _state == "Idle" and is_on_floor():
				_light_pressed = true
				_ai_cd = _ai_cd_for_next(AI_ATK_CD)
		"heavy":
			# 防禦中按重會被判成飛雲浦反擊，懲罰重招只在完全空閒時出
			if _state == "Idle" and is_on_floor():
				_heavy_pressed = true
				_ai_cd = _ai_cd_for_next(AI_HEAVY_CD)
		"dash_attack":
			if _state == "Idle" and is_on_floor():
				_dash_pressed = true
				_ai_cd = _ai_cd_for_next(AI_HEAVY_CD)
		"wait":
			pass

## 依血量決定下一次出手間隔（低血慌亂時明顯更密集；重招本就更慢）
func _ai_cd_for_next(base_cd: float) -> float:
	var hp_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	return AI_PANIC_CD if hp_ratio < AI_PANIC_HP else base_cd

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
	# 醉打蔣門神（RB / U）：4s 冷卻，穿身無敵
	if _special_pressed and _drunk_cd <= 0.0:
		_drunk_cd = DRUNK_CD
		change_state("CmdDrunk")
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
	var spec: Dictionary = _spec(_state)
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
	var spec: Dictionary = _spec(_state)
	if DATA.is_invulnerable(spec, _frame):
		return
	current_hp -= dmg
	wine_gauge = minf(100.0, wine_gauge + 5.0)
	# 伥鬼被打會後退一步重組（docs/04 §2）
	if not is_player1:
		_ai_retreat = AI_RETREAT_TIME
	# 牆族：擊退方向就是牆的方向 → 額外傷害 + 黏牆 30 幀（01 §牆族「額外傷害＋彈回」）
	if _state != "WallStick" and _wall_on_side(from_dir):
		var bonus: int = maxi(WALL_BONUS_MIN, int(round(float(dmg) * WALL_BONUS_RATIO)))
		current_hp -= bonus
		_wall_bonus_last = bonus
		_wall_side = signf(from_dir)
		velocity = Vector2.ZERO
		change_state("WallStick")
		return
	velocity = Vector2(from_dir * 200.0, -100.0 if knock_up <= 0.0 else -knock_up)
	change_state("HurtStand")

## 擊退方向上 20px 內是否有靜態牆；對手身體不算牆（貼身對打不能誤判成牆族）
func _wall_on_side(dir: float) -> bool:
	if absf(dir) < 0.01:
		return false
	var col := KinematicCollision2D.new()
	var hit: bool = test_move(global_transform, Vector2(signf(dir) * WALL_PROBE, 0.0), col)
	if not hit:
		return false
	return col.get_collider() is StaticBody2D

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

## 特效層一次性觸發：進入招式狀態即出一刀刀光；醉打額外出酒紅刀光
func _fx_state(state_name: String) -> void:
	var fx := get_node_or_null("Fx")
	if fx == null:
		return
	var kind := _fx_kind(state_name)
	if kind == "":
		fx.cancel()          # 切入非攻擊狀態（受擊/待機等）＝上一刀被打斷
		return
	# 刀光等 startup 走完（進入 active 命中窗口）才亮，與判定盒開盒同步
	var lg: Dictionary = _spec(state_name).get("logic", {})
	var startup: int = int(lg.get("startup", 0))
	fx.strike(kind, face_direction, float(startup) / 60.0)

## 招式 → 刀光種類（弧度/寬度/色溫不同，rise 由下往上、air 由上往下）
func _fx_kind(state_name: String) -> String:
	match state_name:
		"Light1", "Light2", "Counter":
			return "light"
		"Light3", "Heavy", "CmdTiger":
			return "heavy"
		"CrouchLight":
			return "low"
		"AirLight", "AirHeavy":
			return "air"
		"CmdUp":
			return "rising"
		"CmdDrunk", "Super":
			return "drunk"
	return ""

## 每邏輯幀同步酒氣模式（Super 金脈衝 / 滿氣柔和呼吸 / 醉打酒紅）與酒霧開關
func _fx_sync() -> void:
	var fx := get_node_or_null("Fx")
	if fx != null:
		fx.sync(_state, _frame, wine_gauge)

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
