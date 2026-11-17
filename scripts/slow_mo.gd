extends RefCounted
## 架招慢放（OPT-02，docs/09 §14.1「架招回饋：白閃＋慢放 0.15s（可關）」）
##
## 只做一件全域事：把 Engine.time_scale 壓到 0.4，撐 150ms 真實時間後還原。
## 用 Time.get_ticks_msec 計時而不是累加 delta——被 time_scale 影響的 delta 會一起變慢，
## 用它計時會把 0.15s 拉成 0.37s。
## 無頭（自測／CI）預設不啟用：time_scale 會拖慢所有既有自測的物理位移，
## 需要驗慢放本身時由測試打開 force_enabled。
## 設置每 0.5s 重讀一次，暫停頁關掉開關時正在播的慢放會立刻收。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")

const DURATION: float = 0.15
const TIME_SCALE: float = 0.4
const ENABLE_RECHECK: float = 0.5

static var force_enabled: bool = false

static var _active: bool = false
static var _until_ms: int = 0
static var _recheck_at: float = 0.0

## 這個環境能不能真的慢放：有畫面才慢，無頭只在測試強開時慢
static func available() -> bool:
	return force_enabled or DisplayServer.get_name() != "headless"

## 使用者開關；force_enabled 只繞過「無頭」限制，不繞過設置
static func enabled() -> bool:
	return SETTINGS.load_parry_fx()

## 觸發慢放；已在慢放中則延到較晚的結束時刻，不疊倍率
static func trigger(duration: float = DURATION, scale: float = TIME_SCALE) -> bool:
	if not available() or not enabled():
		return false
	Engine.time_scale = scale
	_until_ms = maxi(_until_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	_active = true
	_recheck_at = ENABLE_RECHECK
	return true

## 每幀檢查結束／開關狀態；舞台 _process 第一行呼叫
static func tick(delta: float) -> void:
	if not _active:
		return
	if Engine.time_scale > 1.0 or Engine.time_scale <= 0.0:
		Engine.time_scale = TIME_SCALE   # 被別處寫壞就拉回，避免整場卡住
	if Time.get_ticks_msec() >= _until_ms:
		reset()
		return
	_recheck_at -= delta
	if _recheck_at <= 0.0:
		_recheck_at = ENABLE_RECHECK
		if not enabled():
			reset()

static func reset() -> void:
	_active = false
	_until_ms = 0
	_recheck_at = 0.0
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0

static func is_active() -> bool:
	return _active

static func remaining_ms() -> int:
	return maxi(0, _until_ms - Time.get_ticks_msec()) if _active else 0
