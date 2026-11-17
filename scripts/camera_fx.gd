extends RefCounted
## OPT-01 鏡頭層：命中震屏（trauma 平方衰減 0.8s）＋ 2% 微推（0.1s 回彈）。
## 只動 Camera2D 的 offset / zoom，不碰機位本身（OPT-03 的邊界 clamp 與 Boss 拉遠另行處理）。
## 開關讀 user://settings.cfg 的 [display] camera_fx，每 0.5s 刷新一次，暫停頁切換後即時生效。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")

const TRAUMA_TIME: float = 0.8      # 震屏衰減到 0 的秒數（docs/09 §14.2）
const PUSH_TIME: float = 0.1        # 微推回彈時間
const PUSH_ZOOM: float = 0.02       # 命中推 2%
const MAX_SHAKE := Vector2(12.0, 9.0)
const OVERSHOOT: float = 0.015      # 震屏期間的 1.5% 過掃，避免位移露出手繪背景邊緣
const ENABLE_RECHECK: float = 0.5

var camera: Camera2D = null
var base_offset := Vector2.ZERO
var base_zoom := Vector2.ONE

var _trauma: float = 0.0
var _push: float = 0.0
var _overscan: float = 0.0
var _clock: float = 0.0
var _on: bool = true
var _check_t: float = ENABLE_RECHECK

## 自測用：繞過 settings.cfg，強制開啟
var force_enabled: bool = false

func _init(cam: Camera2D) -> void:
	camera = cam
	if camera != null:
		base_offset = camera.offset
		base_zoom = camera.zoom

## 命中重量換算：4 幀輕 / 8 幀重 / 12 幀覺醒 → trauma 0.38 / 0.55 / 0.75
static func trauma_for(frames: int) -> float:
	return clampf(0.20 + 0.55 * clampf(float(frames) / 12.0, 0.0, 1.0), 0.0, 1.0)

func kick(frames: int) -> void:
	if camera == null:
		return
	_trauma = minf(1.0, _trauma + trauma_for(frames))
	_push = 1.0

func trauma() -> float:
	return _trauma

func push_amount() -> float:
	return _push

func is_enabled() -> bool:
	return force_enabled or _on

## 每幀推進：先刷新開關，再衰減 trauma / 微推，最後把位移寫回相機
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
	var weight: float = _trauma * _trauma
	camera.offset = base_offset + Vector2(
		sin(_clock * 71.0) * MAX_SHAKE.x * weight,
		cos(_clock * 53.0) * MAX_SHAKE.y * weight)
	var k: float = _overscan + PUSH_ZOOM * _push
	camera.zoom = Vector2(base_zoom.x * (1.0 + k), base_zoom.y * (1.0 + k))

## 回到基準機位；關閉開關與場景切換前呼叫都安全
func reset() -> void:
	_trauma = 0.0
	_push = 0.0
	_overscan = 0.0
	if camera != null:
		camera.offset = base_offset
		camera.zoom = base_zoom

## 換場景後相機可能被重建：重新綁定並保留目前開關狀態
func rebind(cam: Camera2D) -> void:
	camera = cam
	if camera != null:
		base_offset = camera.offset
		base_zoom = camera.zoom
	_clock = 0.0
	reset()
