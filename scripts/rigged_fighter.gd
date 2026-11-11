extends CharacterBody2D
## 武松格鬥控制器（60fps 邏輯幀驅動；姿態由 frame_animator 毫秒序列播放）
##
## 時鐘分工：
##   每個 _physics_process = 1 邏輯幀（60fps，16.667ms），判定/取消/硬直以此計數
##   視覺姿態序列由 frame_animator 按 spec.visual.fps（預設 30fps / 33.333ms）換幀
## 所有招式數值來自 data/action_frame_data.gd，與 docs/06 Frame Data 對齊。

const DATA := preload("res://data/action_frame_data.gd")

@export var is_player1: bool = true
@export var max_hp: int = 800
@export var anim_dir: String = "":
	set(value):
		anim_dir = value
		if is_node_ready():
			_apply_anim_dir()
## 初始狀態：玩家 Idle；有自己素材表的敵人可指定 TigerIdle 等
@export var start_state: String = "Idle"
## AI 行為組：brute＝伥鬼（站防/輕重棍/扔石頭），tiger＝吊睛小虎（撲/尾掃/三連撲/cross-up/後跳）
@export var ai_profile: String = "brute"
@export var walk_speed: float = 220.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

# 戰鬥資源
var current_hp: int
var wine_gauge: float = 0.0
var face_direction: float = 1.0
var opponent = null
var is_blocking: bool = false
var _defense: String = "none"   # none / stand / crouch / air（驅動差異化減傷與退卻）
var _anim_dirs_ready: bool = false

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
var _ai_throw_cd: float = 0.0   # 扔石頭冷卻（秒）
var _ai_hop: float = 0.0        # 小虎出招後後跳計時（秒）
var _tiger_prev_state: String = "TigerIdle"
var _chain_segments_done: Array[bool] = [false, false, false]   # 三連撲三段是否已命中/判定完

# 牆族：黏牆期間牆所在方向（+1 右 / -1 左）、最近一次額外傷害（供自測讀取）
var _wall_side: float = 0.0
var _wall_bonus_last: int = 0

# 狀態分組（與 data spec 對應）
const ATTACKS: Array = ["Light1", "Light2", "Light3", "Heavy", "CrouchLight", "AirLight", "AirHeavy", "CmdTiger", "CmdUp", "Counter", "CmdDrunk", "Super"]
const REACTION: Array = ["HurtStand", "HurtAir", "Knockdown", "WakeUp", "Stun", "StunShort"]
## 小虎專用招式與受擊姿態（docs/04 §3：不會蹲防、不會投擲、會後跳）
const TIGER_ATTACKS: Array = ["TigerPounce", "TigerTail", "TigerPounceChain", "TigerCross"]
const TIGER_REACTION: Array = ["TigerHurt", "TigerHurtLong", "TigerKnockdown", "TigerWakeUp"]
const BOSS_ATTACKS: Array = ["BossPounce", "BossTail", "BossRearUp", "BossRoar", "BossSummon",
	"BossIronTail", "BossDeathPounce", "BossPounceP3", "BossRearUpP3"]
const BOSS_REACTION: Array = ["BossHurt", "BossKnockdown", "BossDeath"]
## 老虎伥鬼专属状态：只引用 assets/anim/corpse_ghost/ 六帧，避免缺图回退武松
const CORPSE_ATTACKS: Array = ["CorpseLight", "CorpseHeavy", "CorpseDash"]
const CORPSE_REACTION: Array = ["CorpseHurt", "CorpseHurtAir", "CorpseDeath"]

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
const AI_THROW_MIN: float = 360.0        # 超過此距離才考慮扔石頭
const AI_THROW_RATE: float = 0.3         # 遠距時選擇扔石頭的概率
const AI_THROW_CD: float = 2.5           # 扔石頭冷卻（秒）
const ROCK_DAMAGE: int = 75              # 石頭傷害（介於站輕 65 與站重 130 之間）
# 小虎 AI（docs/04 §3：前撲可格擋、尾掃要跳、三連撲二段起不可格擋、越頂 cross-up、會後跳拉距）
const TIGER_WALK_SPEED: float = 170.0   # 小虎四足接近速度（比伥鬼快，壓迫感來源）
const TIGER_POUNCE_MIN: float = 170.0    # 前撲起手距離下限
const TIGER_POUNCE_MAX: float = 340.0    # 前撲/越頂的有效距離上限
const TIGER_TAIL_RANGE: float = 110.0   # 尾掃貼身距離
const TIGER_POUNCE_VX: float = 240.0     # 前撲前衝速度
const TIGER_CROSS_VX: float = 380.0      # 越頂水平速度
const TIGER_CROSS_VY: float = -420.0     # 越頂起跳速度
const TIGER_ATK_CD: float = 1.1          # 普通招間隔
const TIGER_CHAIN_CD: float = 1.9        # 三連撲後多緩一拍
const TIGER_HOP_TIME: float = 0.32       # 出招後後跳拉距時長
const ROCK_SCENE := preload("res://scripts/rock_projectile.gd")
const PICKUP_SCENE := preload("res://scripts/coin_pickup.gd")
# 死亡演出（docs/04 §2：伥鬼沒有身體，死後化為一縷青煙）
const DEATH_FADE_START: float = 0.25   # 青煙先起，本體延後淡出
const DEATH_FADE_TIME: float = 0.80
const DEATH_TOTAL: float = 1.05        # 到此刻收尾（隱藏本體、掉東西）
## 青煙序列幀（六格手繪水墨，512×640，底邊對齊 612），由 tools/build_death_mist_frames.py 從序列原畫拆出
const MIST_FRAMES: Array = [
	preload("res://assets/fx/death_mist/mist_01.png"),
	preload("res://assets/fx/death_mist/mist_02.png"),
	preload("res://assets/fx/death_mist/mist_03.png"),
	preload("res://assets/fx/death_mist/mist_04.png"),
	preload("res://assets/fx/death_mist/mist_05.png"),
	preload("res://assets/fx/death_mist/mist_06.png"),
]
const MIST_FPS: float = 9.0

## 死亡狀態 / 掉落
var _dying: bool = false
var _death_done: bool = false
var _death_t: float = 0.0
var _mist_node: AnimatedSprite2D = null
var _rng := RandomNumberGenerator.new()
@export var drop_chance: float = 0.1    # 「伥鬼的木牌」掉率（docs/04 §2）
# 伥鬼出手比操作角色慢（docs/04 §2：站輕啟動 8 幀、站重 15 幀），傷害另給一列——
# 只加在非 P1 的實例上，不动全局數據表，武松手感維持 6／12 幀、40／90 傷害。
const ENEMY_OVERRIDES: Dictionary = {
	"Light1": {"startup": 2, "damage": 65},
	"Heavy": {"startup": 3, "damage": 130},
}

## 動作規格：敵方實例在共用數據表上疊 startup 補償與傷害列；回傳的字典已複製，改動不會污染 SPECS
func _spec(state_name: String) -> Dictionary:
	var base: Dictionary = DATA.spec(state_name)
	if is_player1:
		return base
	var ov: Dictionary = ENEMY_OVERRIDES.get(state_name, {})
	if ov.is_empty():
		return base
	var copy: Dictionary = base.duplicate(false)
	if ov.has("startup"):
		var lg: Dictionary = (base["logic"] as Dictionary).duplicate()
		lg["startup"] = int(lg.get("startup", 0)) + int(ov["startup"])
		copy["logic"] = lg
	if ov.has("damage"):
		copy["damage"] = int(ov["damage"])
	return copy

func _ready() -> void:
	_rng.randomize()
	current_hp = max_hp
	face_direction = 1.0 if is_player1 else -1.0
	_apply_anim_dir.call_deferred()
	change_state(start_state)

## 敵人有自己的素材目錄時插到查找鏈最前；空字串＝沿用武松那三層
func _apply_anim_dir() -> void:
	if anim_dir == "":
		return
	$Visual.set_search_dirs([anim_dir, "res://assets/anim/redraw_clean/", "res://assets/anim/clean/", "res://assets/anim/"])

func change_state(new_state: String) -> void:
	if _state == new_state:
		return
	var old_state := _state
	_state = new_state
	_frame = 0
	_has_hit = false
	_chain_segments_done = [false, false, false]
	velocity.x = 0.0
	_set_attack_shape(false)  # 離開招式一律關閉攻擊盒，避免殘留命中判定
	# 防禦姿態標記 + 派生 blocking 旗標
	if new_state == "Block" or new_state == "CorpseBlock":
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
	# 首幀補套素材目錄：繼承場景的 export 覆寫可能晚於 _ready，延後到這裡最穩
	if not _anim_dirs_ready:
		_apply_anim_dir()
		_anim_dirs_ready = true
	# 死亡演出：完全接管本幀，不再讀輸入、不再出招
	if _dying:
		_tick_death(delta)
		return
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
			if _is_corpse():
				change_state("CorpseHurtAir")
			else:
				change_state("HurtAir")
			velocity = Vector2(-_wall_side * WALL_BOUNCE_X, -WALL_BOUNCE_Y)
		return

	# Reaction 層最高優先級：受擊/倒地/起身只推進時鐘與物理，不接受攻擊輸入
	if _state in REACTION or _state in TIGER_REACTION or _state in BOSS_REACTION or _state in CORPSE_REACTION:
		_frame += 1
		# 被擊瞬間（前4邏輯幀）按重可搶出飞云浦反击 Counter（僅武松）
		if not _is_tiger() and _state == "HurtStand" and _frame <= 4 and _heavy_pressed:
			change_state("Counter")
			return
		_apply_gravity(delta)
		move_and_slide()
		$Visual.play_action(_state, spec, delta)
		if _frame >= DATA.total_frames(spec):
			change_state(_idle_state())
		return

	# 一次性動作（攻擊 / Dash / Drink / Land…）
	if not bool(spec.loop) and DATA.total_frames(spec) > 0:
		_frame += 1
		if _state in ATTACKS or _state in TIGER_ATTACKS or _state in BOSS_ATTACKS or _state in CORPSE_ATTACKS:
			_try_hit(spec)
			if _try_cancel():
				return  # 取消切入新狀態，下一幀按新狀態處理
		_apply_gravity(delta)
		if _state == "Dash":
			velocity.x = face_direction * 480.0
		elif _state == "CmdDrunk" and _frame <= 13:
			velocity.x = face_direction * 360.0   # 醉打：僅起手＋活躍段前衝穿身
		elif _state == "TigerPounce":
			var startup_n: int = int(spec.get("logic", {}).get("startup", 0))
			var active_n: int = int(spec.get("logic", {}).get("active", 0))
			velocity.x = face_direction * TIGER_POUNCE_VX if _frame <= startup_n + active_n else 0.0
		elif _state == "TigerPounceChain":
			# 三連撲：只在 18/28/38 三個命中段附近前衝，段與段之間收腳
			var lunging: bool = (_frame >= 18 and _frame <= 22) \
				or (_frame >= 28 and _frame <= 32) \
				or (_frame >= 38 and _frame <= 42)
			velocity.x = face_direction * TIGER_POUNCE_VX if lunging else 0.0
		elif _state == "TigerCross":
			velocity.x = face_direction * TIGER_CROSS_VX
		elif spec.has("vx"):
			var vx_window: int = int(spec.get("vx_window", 0))
			velocity.x = face_direction * float(spec.get("vx", 0.0)) \
				if vx_window <= 0 or _frame <= vx_window else 0.0
		else:
			velocity.x = 0.0
		move_and_slide()
		$Visual.play_action(_state, spec, delta)
		if _frame >= DATA.total_frames(spec):
			change_state(_idle_state())
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
	_ai_throw_cd = maxf(0.0, _ai_throw_cd - delta)
	# 確定性低差異序列（黃金比例步進）：同一串 ctx 每次跑出來的決策一致，自測可重現
	_ai_roll = fmod(_ai_roll + 0.6180339887, 1.0)
	if ai_profile == "tiger":
		_run_tiger_ai(delta, dx, dist)
		return
	if _is_corpse():
		_ai_apply_corpse(ai_plan(_ai_ctx(dist)), dx)
		return
	_ai_apply(ai_plan(_ai_ctx(dist)), dx)

## 小虎 AI：選招 → 直接切狀態；出招結束後接一段後跳拉距（docs/04 §3「會後跳」）
func _run_tiger_ai(delta: float, dx: float, dist: float) -> void:
	_ai_hop = maxf(0.0, _ai_hop - delta)
	# 上一幀還在出招、這幀已回到移動態 → 立刻起跳後撤
	if _tiger_prev_state in TIGER_ATTACKS and _state not in TIGER_ATTACKS:
		_ai_hop = TIGER_HOP_TIME
	_tiger_prev_state = _state
	var plan: String = "hop" if _ai_hop > 0.0 else tiger_plan(_ai_ctx(dist))
	_ai_apply_tiger(plan, dx, dist)

## 小虎決策（純函數）：遠距越頂/接近，中距前撲或三連撲，貼身尾掃
func tiger_plan(ctx: Dictionary) -> String:
	var dist: float = float(ctx.get("dist", 9999.0))
	var roll: float = float(ctx.get("roll", 0.0))
	var atk_cd: float = float(ctx.get("atk_cd", 0.0))
	var opp_state: String = String(ctx.get("opp_state", "Idle"))
	var opp_frame: int = int(ctx.get("opp_frame", 0))
	var opp_active_end: int = int(ctx.get("opp_active_end", 0))
	# 對手正在出招且已進入判定：小虎不會蹲防，只能後跳拉開
	if opp_state in ATTACKS and opp_frame < opp_active_end and dist < 300.0:
		return "hop"
	if atk_cd > 0.0:
		if dist > 190.0:
			return "approach"
		return "wait"
	if dist > TIGER_POUNCE_MAX:
		if dist <= 460.0 and roll < 0.35:
			return "cross"
		return "approach"
	if dist > TIGER_POUNCE_MIN:
		if roll < 0.45:
			return "pounce"
		if roll < 0.72:
			return "chain"
		if roll < 0.86:
			return "cross"
		return "approach"
	if dist > TIGER_TAIL_RANGE:
		return "tail" if roll < 0.35 else "pounce"
	return "tail" if roll < 0.55 else "chain"

## 把決策映射成小虎的移動／出招（不共用伥鬼的 light/heavy/block 旗標）
func _ai_apply_tiger(plan: String, dx: float, _dist: float) -> void:
	var toward: float = signf(dx) if absf(dx) > 0.01 else face_direction
	_move_x = 0.0
	_block_held = false
	face_direction = toward
	match plan:
		"approach":
			_move_x = toward * 1.0
		"hop":
			_move_x = -toward * 1.0
		"wait":
			pass
		"pounce", "tail", "chain", "cross":
			if _state in ["TigerIdle", "TigerWalk", "TigerCrouch"] and is_on_floor():
				var target: String = ""
				match plan:
					"pounce": target = "TigerPounce"
					"tail": target = "TigerTail"
					"chain": target = "TigerPounceChain"
					"cross": target = "TigerCross"
				if target == "TigerCross":
					velocity = Vector2(toward * TIGER_CROSS_VX, TIGER_CROSS_VY)
				change_state(target)
				_ai_cd = TIGER_CHAIN_CD if target == "TigerPounceChain" else TIGER_ATK_CD

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
		"throw_cd": _ai_throw_cd,
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
	# 3. 遠距：偶爾扔石頭（docs/04 特殊技，慢弧可閃），其餘先接近
	if dist > AI_THROW_MIN and atk_cd <= 0.0 and float(ctx.get("throw_cd", 0.0)) <= 0.0 and roll < AI_THROW_RATE:
		return "rock"
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
		"rock":
			if _state == "Idle" and is_on_floor():
				_ai_spawn_rock()
				_ai_throw_cd = AI_THROW_CD
				_ai_cd = _ai_cd_for_next(AI_ATK_CD)
		"wait":
			pass

## 伥鬼把通用决策映射到专属状态；不再借武松的 Light1/Heavy/Block
func _ai_apply_corpse(plan: String, dx: float) -> void:
	var toward: float = signf(dx) if absf(dx) > 0.01 else face_direction
	_move_x = 0.0
	_block_held = false
	face_direction = toward
	match plan:
		"approach":
			_move_x = toward * 1.0
		"retreat":
			_move_x = -toward * 1.0
		"block":
			_block_held = true
		"light":
			if _state in ["CorpseIdle", "CorpseWalk"] and is_on_floor():
				change_state("CorpseLight")
				_ai_cd = _ai_cd_for_next(AI_ATK_CD)
		"heavy":
			if _state in ["CorpseIdle", "CorpseWalk"] and is_on_floor():
				change_state("CorpseHeavy")
				_ai_cd = _ai_cd_for_next(AI_HEAVY_CD)
		"dash_attack":
			if _state in ["CorpseIdle", "CorpseWalk"] and is_on_floor():
				change_state("CorpseDash")
				_ai_cd = _ai_cd_for_next(AI_HEAVY_CD)
		"rock":
			if _state in ["CorpseIdle", "CorpseWalk"] and is_on_floor():
				_ai_spawn_rock()
				_ai_throw_cd = AI_THROW_CD
				_ai_cd = _ai_cd_for_next(AI_ATK_CD)
		"wait":
			pass

## 生成石頭：純 Node2D + 腳本弧線，不進物理空間，物理幀裡 add_child 也安全
func _ai_spawn_rock() -> void:
	if opponent == null or not is_instance_valid(opponent):
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var dir: float = signf(opponent.global_position.x - global_position.x)
	if is_zero_approx(dir):
		dir = face_direction
	var rock: Node2D = ROCK_SCENE.new()
	parent_node.add_child(rock)
	rock.setup(opponent, dir, ROCK_DAMAGE,
		Vector2(global_position.x + dir * 46.0, global_position.y - 120.0))

## 依血量決定下一次出手間隔（低血慌亂時明顯更密集；重招本就更慢）
func _ai_cd_for_next(base_cd: float) -> float:
	var hp_ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 1.0
	return AI_PANIC_CD if hp_ratio < AI_PANIC_HP else base_cd

func _decide_free_state(_delta: float) -> void:
	if _is_tiger():
		_decide_tiger_free_state()
		return
	if _is_corpse():
		_decide_corpse_free_state()
		return
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

func _is_tiger() -> bool:
	return ai_profile == "tiger"

func _is_corpse() -> bool:
	return ai_profile == "corpse_ghost"

func _idle_state() -> String:
	if _is_tiger():
		return "TigerIdle"
	if _is_corpse():
		return "CorpseIdle"
	return "Idle"

func _death_state() -> String:
	if _is_tiger():
		return "TigerKnockdown"
	if _is_corpse():
		return "CorpseDeath"
	return "Knockdown"

## 小虎受擊姿態映射：武松那套 HurtStand/HurtAir 沒有小虎素材，一律落到 TigerHurt
func _hurt_state(kind: String) -> String:
	if _is_tiger():
		if kind == "Knockdown":
			return "TigerKnockdown"
		if kind == "WakeUp":
			return "TigerWakeUp"
		return "TigerHurt"
	if _is_corpse():
		return "CorpseHurtAir" if kind == "HurtAir" else "CorpseHurt"
	return kind

## 小虎自由移動：只有 TigerWalk / TigerIdle，沒有站防、蹲防、跳躍
func _decide_tiger_free_state() -> void:
	if not is_on_floor():
		change_state("TigerHurt")
		velocity.x = 0.0
		return
	if absf(_move_x) > 0.1:
		change_state("TigerWalk")
		velocity.x = signf(_move_x) * TIGER_WALK_SPEED
		return
	change_state("TigerIdle")
	velocity.x = 0.0

## 伥鬼自由移动：站防 / 拖步 / 站立，不会蹲防、跳跃、空防
func _decide_corpse_free_state() -> void:
	if not is_on_floor():
		change_state("CorpseHurtAir")
		velocity.x = 0.0
		return
	if _block_held:
		change_state("CorpseBlock")
		velocity.x = 0.0
		return
	if absf(_move_x) > 0.1:
		change_state("CorpseWalk")
		velocity.x = _move_x * walk_speed
		return
	change_state("CorpseIdle")
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
	# 三連撲是「一招三判定」：不能用 _has_hit 一次鎖死，走獨立分段流程
	if _state == "TigerPounceChain":
		_try_hit_tiger_chain(spec)
		return
	if not DATA.is_active_frame(spec, _frame):
		_set_attack_shape(false)
		return
	if int(spec.get("damage", 0)) <= 0:
		_set_attack_shape(false)
		return
	# 活躍幀：攻擊盒移到朝向側並啟用，以實體 Area2D 重疊取代舊 dx/dy 距離比較
	_enable_attack_shape()
	if _has_hit:
		return
	_resolve_hit(
		int(spec.get("damage", 0)),
		bool(spec.get("unblockable", false)),
		bool(spec.get("low", false)),
		float(spec.get("knock_up", 0.0))
	)

## 三連撲：18/28/38 三個固定幀各判定一次，第一段可格擋、第二段起不可格擋
func _try_hit_tiger_chain(spec: Dictionary) -> void:
	var hits: Array = spec.get("multi_hit", [])
	var windows: Array = [[18, 22], [28, 32], [38, 42]]
	for i in range(hits.size()):
		if i >= windows.size():
			break
		var start_f: int = int(windows[i][0])
		var end_f: int = int(windows[i][1])
		if _frame < start_f or _frame > end_f:
			continue
		if _chain_segments_done[i]:
			continue
		# Area2D 重疊在啟用當幀未必已刷新，整個窗口保持攻擊盒開啟，命中後才關
		_enable_attack_shape()
		var hit: Dictionary = hits[i]
		if _resolve_hit(
			int(hit.get("damage", 0)),
			bool(hit.get("unblockable", false)),
			false,
			float(spec.get("knock_up", 0.0))
		):
			_chain_segments_done[i] = true
			_set_attack_shape(false)
			return
		if _frame >= end_f:
			_chain_segments_done[i] = true
			_set_attack_shape(false)
		return
	_set_attack_shape(false)

## 防禦裁決：不可格擋一律吃滿；低姿尾掃只無視蹲防，站防仍可擋
static func can_block(low: bool, unblockable: bool, defense: String) -> bool:
	if unblockable or defense == "none":
		return false
	if low and defense == "crouch":
		return false
	return true

func _enable_attack_shape() -> void:
	var shape_node: CollisionShape2D = get_node("HitBox/AttackShape")
	var attack_spec: Dictionary = _spec(_state)
	var hb: Dictionary = attack_spec.get("hitbox", {})
	if hb.is_empty():
		shape_node.position = Vector2(face_direction * 90.0, -90.0)
	else:
		var offset: Array = hb.get("offset", [90, -90])
		shape_node.position = Vector2(face_direction * float(offset[0]), float(offset[1]))
		var size: Array = hb.get("size", [180, 120])
		var target_size := Vector2(float(size[0]), float(size[1]))
		var rect := shape_node.shape as RectangleShape2D
		if rect == null or rect.size != target_size:
			# Boss 與武松共用基底場景的 attack_shape 子資源；改尺寸前先換成本節點獨立資源，
			# 否則會把 P1 的 180×120 也一起改掉。
			var own_rect := RectangleShape2D.new()
			own_rect.size = target_size
			shape_node.shape = own_rect
	shape_node.set_disabled(false)

## 對重疊到的 HurtBox 結算一次傷害；回傳是否命中/被擋
func _resolve_hit(dmg: int, unblockable: bool, low: bool, knock_up: float) -> bool:
	if dmg <= 0:
		return false
	# 一個角色可能有多塊 HurtBox（Boss 頭/身/肚）；同一目標只結算一次，取最高倍率。
	var targets: Dictionary = {}
	for area in get_node("HitBox").get_overlapping_areas():
		var target = _fighter_of(area)
		if target == null or target == self:
			continue
		var mult: float = float(area.get_meta("damage_mult", 1.0))
		targets[target] = maxf(float(targets.get(target, 1.0)), mult)
	var attack_spec: Dictionary = _spec(_state)
	var guard_ratio: float = float(attack_spec.get("guard_ratio", -1.0))
	var guard_push: float = float(attack_spec.get("guard_push", -1.0))
	for target in targets:
		var mult: float = float(targets[target])
		var final_dmg: int = int(round(float(dmg) * mult))
		if target.is_blocking and can_block(low, unblockable, target._defense):
			target.on_blocked(final_dmg, face_direction, knock_up, guard_ratio, guard_push)
			_has_hit = true
			# 小虎被架招/格擋後進入長硬直 38 幀，這是 docs/04 §3 的弱點
			if _is_tiger():
				_tiger_guard_stun()
			return true
		target.take_damage(final_dmg, face_direction, knock_up)
		_has_hit = true
		wine_gauge = minf(100.0, wine_gauge + 3.0)
		return true
	return false

func _tiger_guard_stun() -> void:
	if not _is_tiger():
		return
	if _state in TIGER_ATTACKS:
		change_state("TigerHurtLong")

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

## Boss 咆哮施加的純硬直（0 傷害）：30 幀正面、15 幀背對
func apply_stun(frames: int) -> void:
	if _dying:
		return
	change_state("Stun" if frames >= 30 else "StunShort")

func take_damage(dmg: int, from_dir: float, knock_up: float = 0.0) -> void:
	if _dying:
		return
	var spec: Dictionary = _spec(_state)
	if DATA.is_invulnerable(spec, _frame):
		return
	current_hp -= dmg
	wine_gauge = minf(100.0, wine_gauge + 5.0)
	# 伥鬼被打會後退一步重組（docs/04 §2）
	if not is_player1:
		_ai_retreat = AI_RETREAT_TIME
	# 牆族：擊退方向就是牆的方向 → 額外傷害 + 黏牆 30 幀（01 §牆族「額外傷害＋彈回」）
	# 小虎沒有 WallStick 素材與招式，且 docs/04 只給伥鬼牆族表現，這裡直接跳過
	if not _is_tiger() and _state != "WallStick" and _wall_on_side(from_dir):
		var bonus: int = maxi(WALL_BONUS_MIN, int(round(float(dmg) * WALL_BONUS_RATIO)))
		current_hp -= bonus
		_wall_bonus_last = bonus
		_wall_side = signf(from_dir)
		velocity = Vector2.ZERO
		change_state("WallStick")
		return
	# 血量歸零：伥鬼化青煙（docs/04 §2），不進常規受擊
	current_hp = maxi(current_hp, 0)
	if not is_player1 and current_hp <= 0:
		_begin_death()
		return
	velocity = Vector2(from_dir * 200.0, -100.0 if knock_up <= 0.0 else -knock_up)
	change_state(_hurt_state("HurtStand"))

## 死亡演出開始：倒地姿態 + 青煙粒子，本體隨後淡出
func _begin_death() -> void:
	if _dying:
		return
	_dying = true
	_death_done = false
	_death_t = 0.0
	_ai_cd = 999.0
	_ai_retreat = 0.0
	velocity = Vector2.ZERO
	change_state(_death_state())
	_spawn_death_mist()

## 死亡演出推進：不讀輸入、不出招；青煙先起，本體 0.25s 後淡出 0.8s
func _tick_death(delta: float) -> void:
	_death_t += delta
	_frame += 1
	velocity = Vector2.ZERO
	$Visual.play_action(_death_state(), _spec(_death_state()), delta)
	if _death_t >= DEATH_FADE_START:
		var k: float = clampf((_death_t - DEATH_FADE_START) / DEATH_FADE_TIME, 0.0, 1.0)
		$Visual.modulate.a = 1.0 - k
	if _death_t >= DEATH_TOTAL and not _death_done:
		_finish_death()

## 演出收尾：隱藏本體、關碰撞（可穿過青煙）、按 10% 掉木牌
func _finish_death() -> void:
	_death_done = true
	$Visual.visible = false
	$Collision.set_deferred("disabled", true)
	$HurtBox.set_deferred("monitorable", false)
	$HurtBox.set_deferred("monitoring", false)
	_spawn_drop(false)

## 掉落：碎銀必掉；木牌按 drop_chance（docs/04 §2「碎銀 ×10% 概率掉伥鬼的木牌」）
func _spawn_drop(force_tag: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var silver: Node2D = PICKUP_SCENE.new()
	parent_node.add_child(silver)
	silver.setup(opponent, "碎銀", Vector2(global_position.x - 30.0, global_position.y - 30.0))
	if force_tag or _rng.randf() < drop_chance:
		var tag: Node2D = PICKUP_SCENE.new()
		parent_node.add_child(tag)
		var tag_name: String = "小虎爪" if _is_tiger() else "伥鬼的木牌"
		tag.setup(opponent, tag_name, Vector2(global_position.x + 30.0, global_position.y - 30.0))

## 青煙：播六幀手繪水墨序列（9fps，不循環），播完停在最淡一幀再自清
func _spawn_death_mist() -> void:
	var mist := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("mist")
	frames.set_animation_speed("mist", MIST_FPS)
	frames.set_animation_loop("mist", false)
	for tex in MIST_FRAMES:
		frames.add_frame("mist", tex)
	mist.sprite_frames = frames
	mist.animation = "mist"
	mist.position = Vector2(0.0, -288.0)   # 512×640 幀底邊 612 → 縮放後腳底約在原點
	mist.scale = Vector2(0.9, 0.9)
	mist.z_index = 1
	mist.play("mist")
	_mist_node = mist
	add_child(mist)
	get_tree().create_timer(1.8).timeout.connect(_free_mist)

func _free_mist() -> void:
	if is_instance_valid(_mist_node):
		_mist_node.queue_free()
	_mist_node = null

## 擊退方向上 20px 內是否有靜態牆；對手身體不算牆（貼身對打不能誤判成牆族）
func _wall_on_side(dir: float) -> bool:
	if absf(dir) < 0.01:
		return false
	var col := KinematicCollision2D.new()
	var hit: bool = test_move(global_transform, Vector2(signf(dir) * WALL_PROBE, 0.0), col)
	if not hit:
		return false
	return col.get_collider() is StaticBody2D

func on_blocked(dmg: int, from_dir: float, knock_up: float = 0.0, guard_ratio: float = -1.0, guard_push: float = -1.0) -> void:
	# 依防禦姿態折減傷害與擊退；空防不被向上挑空
	if _dying:
		return
	var ratio: float = float(GUARD_RATIO.get(_defense, 0.5)) if guard_ratio < 0.0 else guard_ratio
	var push: float = 80.0 if guard_push < 0.0 else guard_push
	if guard_ratio < 0.0 and _defense == "crouch":
		push = 50.0
	elif guard_ratio < 0.0 and _defense == "air":
		push = 60.0
	current_hp -= int(round(float(dmg) * ratio))
	# 架招也會被打死（邊緣情況）：同樣走青煙演出
	current_hp = maxi(current_hp, 0)
	if not is_player1 and current_hp <= 0:
		_begin_death()
		return
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
	if opponent == null or _state not in ["Idle", "Walk", "Crouch", "Block", "CrouchBlock", "TigerIdle", "TigerWalk", "CorpseIdle", "CorpseWalk", "CorpseBlock"]:
		return
	var target: float = 1.0 if opponent.global_position.x > global_position.x else -1.0
	if target != face_direction:
		face_direction = target
	$Visual.scale.x = absf($Visual.scale.x) * face_direction
