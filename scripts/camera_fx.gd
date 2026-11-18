extends RefCounted
## 鏡頭層：OPT-03 取景（lookahead ±120、邊界 clamp、Boss 拉遠、階段微推）
## ＋ OPT-01 打擊感（命中震屏、2% 微推、1.5% 過掃）。
## 只動 Camera2D 的 position / offset / zoom；機位基準由舞台在建相機時決定。
## 世界只有 1920×1080、背景貼齊視窗，故基準取景收到 1.15，左右各留 125px 邊，
## 平移 120px 不會露邊；Boss 戰再乘 1/1.1 拉遠約 10%。開關讀 [display] camera_fx。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")

const WORLD := Vector2(1920.0, 1080.0)
const LOOK_MAX: float = 120.0       # 平視預看上限（docs/09 §14.2）
const LOOK_TRACK: float = 0.25      # 玩家離畫面中線每 1px 帶動 0.25px
const LOOK_BIAS: float = 20.0       # 朝向前方的固定預看
const LOOK_LERP: float = 8.0        # 每秒追平係數，太硬會暈、太軟會拖
const PHASE_TIME: float = 0.3       # Boss 換階段的微推時長
const PHASE_PUSH: float = 0.05      # 換階段瞬間推近 5%，正弦進出

const TRAUMA_TIME: float = 0.8      # 震屏衰減到 0 的秒數（docs/09 §14.2）
const PUSH_TIME: float = 0.1        # 微推回彈時間
const PUSH_ZOOM: float = 0.02       # 命中推 2%
const MAX_SHAKE := Vector2(12.0, 9.0)
const OVERSHOOT: float = 0.015      # 震屏期間的 1.5% 過掃，避免位移露出手繪背景邊緣
const ENABLE_RECHECK: float = 0.5

var camera: Camera2D = null
var base_offset := Vector2.ZERO
var base_zoom := Vector2.ONE
var base_position := Vector2.ZERO

var _follow: Node2D = null
var _look: float = 0.0
var _look_on: bool = true
var _phase_left: float = 0.0

var _trauma: float = 0.0
var _push: float = 0.0
var _overscan: float = 0.0
var _clock: float = 0.0
var _on: bool = true
var _check_t: float = ENABLE_RECHECK

## 自測用：繞過 settings.cfg，強制開啟
var force_enabled: bool = false

func _init(cam: Camera2D, follow: Node2D = null) -> void:
	camera = cam
	_follow = follow
	if camera != null:
		base_offset = camera.offset
		base_zoom = camera.zoom
		base_position = camera.position

## 命中重量換算：4 幀輕 / 8 幀重 / 12 幀覺醒 → trauma 0.38 / 0.55 / 0.75
static func trauma_for(frames: int) -> float:
	return clampf(0.20 + 0.55 * clampf(float(frames) / 12.0, 0.0, 1.0), 0.0, 1.0)

## 換人跟隨（章節切場重建玩家時用）
func set_follow_target(target: Node2D) -> void:
	_follow = target
	_look = 0.0

## 水潭這類固定機位：關掉預看，只留震屏
func set_look_enabled(on: bool) -> void:
	_look_on = on
	if not on:
		_look = 0.0

## Boss 換階段：0.3s 正弦微推（推近再收回）
func phase_push() -> void:
	_phase_left = PHASE_TIME

func kick(frames: int) -> void:
	if camera == null:
		return
	_trauma = minf(1.0, _trauma + trauma_for(frames))
	_push = 1.0

func trauma() -> float:
	return _trauma

func push_amount() -> float:
	return _push

func look_offset() -> float:
	return _look

func is_enabled() -> bool:
	return force_enabled or _on

## 預看目標：玩家離中線越遠，鏡頭越往那邊偏；朝向再補一點提前量
func _look_target() -> float:
	if not _look_on or _follow == null or not is_instance_valid(_follow):
		return 0.0
	var raw: float = (_follow.global_position.x - WORLD.x * 0.5) * LOOK_TRACK
	var facing: float = 1.0
	if "face_direction" in _follow:
		facing = _follow.face_direction
	return clampf(raw + facing * LOOK_BIAS, -LOOK_MAX, LOOK_MAX)

## 依目前縮放把機位夾在世界內；視野比世界大時直接置中（不會出現黑邊）
func _clamp_position(target: Vector2, zoom_now: Vector2) -> Vector2:
	var view: Vector2 = WORLD / zoom_now
	var half := view * 0.5
	var lo := half
	var hi := WORLD - half
	if lo.x >= hi.x:
		target.x = WORLD.x * 0.5
	else:
		target.x = clampf(target.x, lo.x, hi.x)
	if lo.y >= hi.y:
		target.y = WORLD.y * 0.5
	else:
		target.y = clampf(target.y, lo.y, hi.y)
	return target

## 每幀推進：先刷新開關，再衰減 trauma / 微推，最後寫回相機位移、縮放與機位
func tick(delta: float) -> void:
	if camera == null:
		return
	_clock += delta
	if not force_enabled:
		_check_t -= delta
		if _check_t <= 0.0:
			_check_t = ENABLE_RECHECK
			_on = SETTINGS.load_camera_fx()
	if not is_enabled():
		reset()
		return
	_trauma = maxf(0.0, _trauma - delta / TRAUMA_TIME)
	_push = maxf(0.0, _push - delta / PUSH_TIME)
	# 過掃：震屏期間立刻補 1.5%（背景剛好 1920×1080，位移會露邊），結束後 0.2s 收回
	if _trauma > 0.0:
		_overscan = OVERSHOOT
	else:
		_overscan = maxf(0.0, _overscan - delta / 0.2)
	# 預看：追平目標偏移，關掉時歸零
	var want: float = _look_target()
	_look = lerpf(_look, want, clampf(delta * LOOK_LERP, 0.0, 1.0))
	if _phase_left > 0.0:
		_phase_left = maxf(0.0, _phase_left - delta)
	var phase_t: float = 1.0 - _phase_left / PHASE_TIME
	var phase_k: float = sin(PI * phase_t) * PHASE_PUSH if _phase_left > 0.0 else 0.0
	var weight: float = _trauma * _trauma
	camera.offset = base_offset + Vector2(
		sin(_clock * 71.0) * MAX_SHAKE.x * weight,
		cos(_clock * 53.0) * MAX_SHAKE.y * weight)
	var k: float = _overscan + PUSH_ZOOM * _push + phase_k
	var zoom_now := Vector2(base_zoom.x * (1.0 + k), base_zoom.y * (1.0 + k))
	camera.zoom = zoom_now
	if _follow != null:
		var target := base_position + Vector2(_look, 0.0)
		camera.position = _clamp_position(target, zoom_now)

## 回到基準機位；關閉開關與場景切換前呼叫都安全
func reset() -> void:
	_trauma = 0.0
	_push = 0.0
	_overscan = 0.0
	_phase_left = 0.0
	_look = 0.0
	if camera != null:
		camera.offset = base_offset
		camera.zoom = base_zoom
		camera.position = base_position

## 換場景後相機可能被重建：重新綁定並保留目前開關狀態
func rebind(cam: Camera2D) -> void:
	camera = cam
	if camera != null:
		base_offset = camera.offset
		base_zoom = camera.zoom
		base_position = camera.position
	_clock = 0.0
	reset()
