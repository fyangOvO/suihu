extends Node
## 輕量物件池（OPT-04）：戰鬥熱路徑的短命節點（石頭這類）在場景內循環重用，
## 避免每次出手都 new ＋ queue_free 造成配置與回收尖峰。
##
## 用法：
##   var rock = pool.acquire("rock", func(): return ROCK_SCENE.new(), get_parent())
##   pool.release("rock", rock)          # 節點自己收尾時呼叫，或由持有者歸還
## 取用時若節點有 `pool_reset()` 會先歸零狀態；歸還時一律隱藏並掛在池下（池本身停用處理）。

const MAX_IDLE_PER_KEY: int = 3

var _idle: Dictionary = {}
var _stats: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

## 取一個可用節點：優先拿回收桶裡的，沒有才由 factory 新建；一律掛到 target_parent。
func acquire(key: String, factory: Callable, target_parent: Node) -> Node:
	if target_parent == null or not is_instance_valid(target_parent):
		return null
	var bucket: Array = _idle.get(key, [])
	var node: Node = null
	if bucket.size() > 0:
		node = bucket.pop_back()
		_idle[key] = bucket
		_stat(key)["reused"] = int(_stat(key)["reused"]) + 1
		remove_child(node)
	else:
		node = factory.call()
		_stat(key)["created"] = int(_stat(key)["created"]) + 1
	target_parent.add_child(node)
	node.set_meta("pool", self)
	node.set_meta("pool_key", key)
	_stat(key)["live"] = int(_stat(key)["live"]) + 1
	if node.has_method("pool_reset"):
		node.call("pool_reset")
	elif node is CanvasItem:
		(node as CanvasItem).visible = true
	return node

## 歸還：先從原父節點摘下來，超過上限就真的釋放，否則收進池中待下次重用。
func release(key: String, node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var parent: Node = node.get_parent()
	if parent == self:
		return
	if parent != null:
		parent.remove_child(node)
	var stat: Dictionary = _stat(key)
	if int(stat["live"]) > 0:
		stat["live"] = int(stat["live"]) - 1
	var bucket: Array = _idle.get(key, [])
	if bucket.size() >= MAX_IDLE_PER_KEY:
		stat["dropped"] = int(stat["dropped"]) + 1
		node.queue_free()
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	add_child(node)
	bucket.append(node)
	_idle[key] = bucket
	stat["released"] = int(stat["released"]) + 1

func idle_count(key: String) -> int:
	var bucket: Array = _idle.get(key, [])
	return bucket.size()

func live_count(key: String) -> int:
	return int(_stat(key)["live"])

## 用量統計：created／reused／released／dropped／live。傳空字串取全部。
func stats(key: String = "") -> Dictionary:
	if key != "":
		return _stat(key).duplicate()
	var out: Dictionary = {}
	for k in _stats.keys():
		out[k] = _stat(String(k)).duplicate()
	return out

func _stat(key: String) -> Dictionary:
	if not _stats.has(key):
		_stats[key] = {"created": 0, "reused": 0, "released": 0, "dropped": 0, "live": 0}
	return _stats[key]
