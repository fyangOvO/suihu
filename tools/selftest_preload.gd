extends SceneTree
## OPT-04 場景非同步預載無頭自測：
##  A. 狀態機：空路徑回 NONE、壞路徑回 FAILED、取用回 null
##  B. 真預載：request → LOADING → READY，ready_scene 出 PackedScene 且同一份、重複 request 不重排
##  C. 舞台接線：進場時自動預載「下一拍」場景；同一場景的下一拍不預載
##  D. 切場景成本：六個章節場景冷載入實測（CACHE_MODE_IGNORE）皆 < 3000ms，預載後取用 < 100ms
## 用法：godot --headless --path <game> --script res://tools/selftest_preload.gd
## PASS 退出 0；FAIL 退出 1。

const PRELOADER := preload("res://scripts/scene_preloader.gd")
const STORY := preload("res://data/story_beats.gd")
const STAGE_SCENE := preload("res://scenes/chapters/SCN_02_Trail.tscn")
const SCENE_BUDGET_MS: int = 3000
const WARM_BUDGET_MS: int = 100

var fails: Array = []
var checks: int = 0
var stage: int = 0
var frame: int = 0
var wait_frames: int = 0
var exit_code: int = 0

var first_path: String = ""
var stage_node: Node = null

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	PRELOADER.force_headless = true   # 本套自測就是要驗線程預載本身
	PRELOADER.clear_all()
	first_path = String(STORY.SCENE_PATHS["SCN-01"])

func _process(_delta: float) -> bool:
	frame += 1
	match stage:
		0:
			if frame >= 2:
				_check_basics()
				PRELOADER.request(first_path)
				stage = 1
				frame = 0
		1:
			var st: int = PRELOADER.poll(first_path)
			if st == PRELOADER.State.READY or frame >= 120:
				_check_preload_ready(st)
				_check_stage_wiring()
				stage = 2
				frame = 0
		2:
			if frame >= 4:
				_check_stage_preload()
				_check_scene_budget()
				_finish()
				stage = 3
				frame = 0
		3:
			# 線程載入的收尾要跨幾幀才乾淨，立刻 quit 會留 1 個 ObjectDB 警告
			if frame >= 4:
				quit(exit_code)
				return true
	return false

# --- A. 狀態機基礎 ---

func _check_basics() -> void:
	_check("empty path is NONE", PRELOADER.state("") == PRELOADER.State.NONE)
	_check("request empty stays NONE", PRELOADER.request("") == PRELOADER.State.NONE)
	_check("unknown path is NONE", PRELOADER.ready_scene("res://scenes/unknown_probe.tscn") == null)
	# 用「不是 PackedScene 的資源」驗失敗分支：載入本身成功、型別不符才算 FAILED，不製造引擎錯誤
	var wrong_type: String = "res://tools/selftest_preload.gd"
	PRELOADER.request(wrong_type)
	var st: int = PRELOADER.State.LOADING
	for _i in 30:
		st = PRELOADER.poll(wrong_type)
		if st != PRELOADER.State.LOADING:
			break
	_check("non-scene resource reports FAILED", st == PRELOADER.State.FAILED)
	_check("failed resource yields no scene", PRELOADER.take(wrong_type) == null)
	PRELOADER.clear(wrong_type)
	_check("clear removes entry", PRELOADER.state(wrong_type) == PRELOADER.State.NONE)

# --- B. 真預載 ---

func _check_preload_ready(st: int) -> void:
	_check("first scene preloads to READY", st == PRELOADER.State.READY)
	var packed: PackedScene = PRELOADER.ready_scene(first_path)
	_check("ready_scene returns PackedScene", packed is PackedScene)
	_check("second take returns same resource", PRELOADER.ready_scene(first_path) == packed)
	_check("repeat request does not requeue", PRELOADER.request(first_path) == PRELOADER.State.READY)
	_check("load_ms recorded", PRELOADER.load_ms(first_path) >= 0)
	var st_map: Dictionary = PRELOADER.stats()
	_check("stats marks ready", bool(st_map.get(first_path, {}).get("ready", false)))

# --- C. 舞台接線 ---

func _check_stage_wiring() -> void:
	var cm = get_root().get_node_or_null("ChapterManager")
	_check("chapter manager present", cm != null)
	if cm == null:
		return
	cm.set_beat("B2")     # SCN-02，下一拍 B3 仍是同一個場景 → 不該預載
	stage_node = STAGE_SCENE.instantiate()
	root.add_child(stage_node)
	wait_frames = frame

func _check_stage_preload() -> void:
	if stage_node == null or stage_node.get_parent() == null:
		_check("stage instantiated", false)
		return
	var cm = get_root().get_node_or_null("ChapterManager")
	var same_next_path: String = STORY.scene_path(STORY.next_id("B2"))
	_check("same-scene next not preloaded", PRELOADER.state(same_next_path) == PRELOADER.State.NONE)

	cm.set_beat("B3")     # 下一拍 B4 是山神廟：不同場景，應該被預載
	stage_node._preload_next_scene()
	var next_path: String = STORY.scene_path(STORY.next_id("B3"))
	_check("different next scene starts preload", PRELOADER.state(next_path) != PRELOADER.State.NONE)
	_check("preload target path correct", next_path.contains("SCN_04"))
	# 把這次預載收乾：留著未完成的線程請求會讓退出時報 1 個 ObjectDB 洩漏
	var settled: PackedScene = PRELOADER.take(next_path)
	_check("stage preload settles to scene", settled is PackedScene)
	root.remove_child(stage_node)
	stage_node.free()
	stage_node = null

# --- D. 切場景成本 ---

func _check_scene_budget() -> void:
	var worst: int = 0
	var worst_inst: int = 0
	for id in STORY.SCENE_PATHS.keys():
		var path: String = String(STORY.SCENE_PATHS[id])
		var t0: int = Time.get_ticks_msec()
		var packed = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		var cold: int = Time.get_ticks_msec() - t0
		var inst_ms: int = -1
		if packed is PackedScene:
			var t2: int = Time.get_ticks_msec()
			var inst: Node = packed.instantiate()
			inst_ms = Time.get_ticks_msec() - t2
			if inst != null:
				inst.free()
		print("SCENE_COST ", id, " ", path, " cold=", cold, "ms inst=", inst_ms, "ms")
		if packed is PackedScene:
			worst = maxi(worst, cold)
			worst_inst = maxi(worst_inst, inst_ms)
		_check("scene %s under %dms" % [id, SCENE_BUDGET_MS], packed is PackedScene and cold + maxi(inst_ms, 0) < SCENE_BUDGET_MS)
	print("SCENE_COST worst_load=", worst, "ms worst_inst=", worst_inst,
		"ms budget=", SCENE_BUDGET_MS, "ms")

	var t1: int = Time.get_ticks_msec()
	var warm: PackedScene = PRELOADER.ready_scene(first_path)
	var warm_ms: int = Time.get_ticks_msec() - t1
	_check("preloaded take is warm", warm is PackedScene and warm_ms < WARM_BUDGET_MS)
	print("SCENE_COST preloaded_take=", warm_ms, "ms (budget ", WARM_BUDGET_MS, "ms)")

func _finish() -> void:
	PRELOADER.clear_all()   # 測試結束把靜態表清乾淨，避免退出時還扣著資源
	if fails.is_empty():
		print("PRELOAD_SELFTEST result=PASS fails=[] checks=", checks)
		exit_code = 0
	else:
		print("PRELOAD_SELFTEST result=FAIL fails=", fails, " checks=", checks)
		exit_code = 1
