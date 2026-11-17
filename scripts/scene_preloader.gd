extends RefCounted
## OPT-04 場景非同步預載：趁玩家還在當前場景時，就把下一個場景的 PackedScene 用線程載好。
## 切場景時用 `change_scene_to_packed` 直接用現成資源，把資源載入時間從「切換瞬間」挪到遊玩過程中。
##
## 用法：
##   PRELOADER.request(next_path)               # 進場時就開始載
##   var scene = PRELOADER.ready_scene(path)    # 非阻塞：好了回 PackedScene，沒好回 null
##   scene != null → change_scene_to_packed(scene)；否則退回 change_scene_to_file
## 全部狀態放在腳本靜態字典，不需要新增 autoload。

enum State { NONE, LOADING, READY, FAILED }

const LOAD_TYPE: String = "PackedScene"

## 無頭模式（自測／CI）不自動預載：沒有畫面收益，還會讓行程退出時留下線程請求警告。
## 自測要驗「舞台會不會自動預載」時，先把這個旗標設 true。
static var force_headless: bool = false

static var _entries: Dictionary = {}

## 發起預載；已在載或已載好就直接回報現狀，不重複排隊。
static func request(path: String) -> int:
	if path.is_empty():
		return State.NONE
	if not force_headless and DisplayServer.get_name() == "headless":
		return State.NONE
	var entry: Dictionary = _entries.get(path, {})
	if not entry.is_empty():
		var st: int = int(entry["state"])
		if st == State.READY or st == State.LOADING:
			return st
		_entries.erase(path)   # 上一次失敗：清掉重試
	var err: int = ResourceLoader.load_threaded_request(path, LOAD_TYPE)
	if err != OK:
		_entries[path] = {"state": State.FAILED, "scene": null, "ms": 0, "t0": Time.get_ticks_msec()}
		return State.FAILED
	_entries[path] = {"state": State.LOADING, "scene": null, "ms": 0, "t0": Time.get_ticks_msec()}
	return State.LOADING

## 推進一次狀態機（每幀呼叫或由 ready_scene 代勞）；回傳目前狀態。
static func poll(path: String) -> int:
	if not _entries.has(path):
		return State.NONE
	var entry: Dictionary = _entries[path]
	if int(entry["state"]) != State.LOADING:
		return int(entry["state"])
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(path, progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_finish(path)
		return int(_entries[path]["state"])
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		entry["state"] = State.FAILED
		return State.FAILED
	return State.LOADING

## 非阻塞取用：只有真的載好了才回 PackedScene，否則回 null（呼叫端退回同步切場景）。
static func ready_scene(path: String) -> PackedScene:
	if poll(path) != State.READY:
		return null
	var scene = _entries[path]["scene"]
	return scene as PackedScene

## 阻塞取用（僅給自測／載入畫面用）：沒載完就等它載完。
static func take(path: String) -> PackedScene:
	if not _entries.has(path):
		return null
	if poll(path) == State.LOADING:
		_finish(path)
	return ready_scene(path)

static func state(path: String) -> int:
	return poll(path)

static func is_ready(path: String) -> bool:
	return poll(path) == State.READY

## 本次預載耗時（ms）：request 發起到資源可用的時間。
static func load_ms(path: String) -> int:
	if not _entries.has(path):
		return -1
	return int(_entries[path]["ms"])

static func clear(path: String) -> void:
	_entries.erase(path)

## 收掉所有還在載的請求（節點離開場景樹時呼叫）：放著不管，退出時引擎會報線程洩漏警告。
static func settle_pending() -> void:
	for path in _entries.keys():
		if int(_entries[path]["state"]) == State.LOADING:
			_finish(path)

static func clear_all() -> void:
	_entries.clear()

static func stats() -> Dictionary:
	var out: Dictionary = {}
	for path in _entries.keys():
		var entry: Dictionary = _entries[path]
		out[String(path)] = {
			"state": int(entry["state"]),
			"ms": int(entry["ms"]),
			"ready": entry["scene"] != null,
		}
	return out

static func _finish(path: String) -> void:
	var entry: Dictionary = _entries[path]
	var res = ResourceLoader.load_threaded_get(path)
	if res is PackedScene:
		entry["scene"] = res
		entry["state"] = State.READY
		entry["ms"] = Time.get_ticks_msec() - int(entry["t0"])
	else:
		entry["state"] = State.FAILED
