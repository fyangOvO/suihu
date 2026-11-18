extends SceneTree
## OPT-07 soak：三場自動循環（正常打完 → 指定死亡重開 → 換場），長時間監測記憶體、
## 節點數、孤兒節點與載入次數；預設 60 遊戲分鐘（216000 邏輯幀）。
##
## 用法：
##   godot --headless --path <game> --script res://tools/soak_60min.gd -- --minutes=60
##   （--minutes=5 可先做短程煙測）
## 輸出每遊戲分鐘一行 SOAK，結束一行 SOAK_RESULT。

const CHAPTER_MANAGER := "res://scripts/chapter_manager.gd"
const SCENES := [
	{"id": "SCN-02", "beat": "B3", "path": "res://scenes/chapters/SCN_02_Trail.tscn", "cap": 900},
	{"id": "SCN-03", "beat": "B5", "path": "res://scenes/chapters/SCN_03_Forest.tscn", "cap": 1500},
	{"id": "SCN-05", "beat": "B7", "path": "res://scenes/chapters/SCN_05_Ridge.tscn", "cap": 3600},
]
const ACTIONS := ["p1_left", "p1_right", "p1_light", "p1_heavy"]

var cm
var total_frames: int = 0
var target_frames: int = 60 * 60 * 60
var loads: int = 0
var deaths: int = 0
var kills: int = 0
var minute_mark: int = 0
var base_mem: int = -1
var base_nodes: int = -1
var fails: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			target_frames = int(arg.get_slice("=", 1)) * 60 * 60
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load(CHAPTER_MANAGER).new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	await process_frame

	print("SOAK_START target_frames=", target_frames, " minutes=", target_frames / 3600)
	while total_frames < target_frames:
		for cfg in SCENES:
			await _run_fight(cfg, false)
		# 每輪抽一場走「死亡重開」：打死玩家，等死亡流程收尾，再釋放重載
		await _run_fight(SCENES[1], true)

	_finish()
	quit(0 if fails.is_empty() else 1)

## 一場：載入 → 固定輸入 → 敵人死（或玩家死）→ 釋放。god_mode 時定期補血，避免 soak 被平衡卡住。
func _run_fight(cfg: Dictionary, die_mode: bool) -> void:
	cm.set_beat(cfg["beat"])
	var scene = load(cfg["path"]).instantiate()
	root.add_child(scene)
	loads += 1
	await physics_frame
	await physics_frame
	var p1 = scene.p1
	var p2 = scene.p2
	var frames: int = 0
	var forced_die: bool = false
	var cap: int = cfg["cap"]
	while frames < cap:
		frames += 1
		total_frames += 1
		if p1 != null and p2 != null:
			_drive(p1, p2, frames)
			if not die_mode and frames % 20 == 0:
				p1.current_hp = p1.max_hp   # soak 穩定優先；死亡由 die_mode 專門測
			if die_mode and frames >= 360 and not forced_die:
				forced_die = true
				p1.take_damage(9999, 1.0)
			if die_mode and p1._death_done:
				deaths += 1
				break
			if p2.current_hp <= 0 and p2._death_done:
				kills += 1
				break
		await physics_frame
	# 打不死就強制收尾，保證流程前進（不影響穩定性觀測）
	if not die_mode and p2 != null and not p2._death_done:
		p2.take_damage(99999, 1.0)
		for i in 30:
			await physics_frame
			total_frames += 1
		kills += 1
	if die_mode and p1 != null and not p1._death_done:
		deaths += 1
	_release(scene)
	await physics_frame
	await physics_frame
	if total_frames >= minute_mark + 3600:
		minute_mark = total_frames
		_log_minute()

func _drive(p1, p2, frame: int) -> void:
	for a in ACTIONS:
		Input.action_release(a)
	var dx: float = p2.global_position.x - p1.global_position.x
	if absf(dx) > 150.0:
		Input.action_press("p1_right" if dx > 0.0 else "p1_left")
	if frame % 14 < 2:
		Input.action_press("p1_light")
	if frame % 70 < 2:
		Input.action_press("p1_heavy")

func _release(scene) -> void:
	for a in ACTIONS:
		Input.action_release(a)
	if scene != null and is_instance_valid(scene):
		scene.queue_free()

func _log_minute() -> void:
	var mem: int = OS.get_static_memory_usage()
	if base_mem < 0:
		base_mem = mem
		base_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("SOAK minute=", total_frames / 3600, " frames=", total_frames,
		" mem_mb=%.1f" % (float(mem) / 1048576.0),
		" nodes=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		" orphan=", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		" loads=", loads, " kills=", kills, " deaths=", deaths)

func _finish() -> void:
	var mem: int = OS.get_static_memory_usage()
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphan: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var grew_mb: float = float(mem - base_mem) / 1048576.0 if base_mem >= 0 else 0.0
	if total_frames < target_frames:
		fails.append("finished early: %d/%d frames" % [total_frames, target_frames])
	if grew_mb > 64.0:
		fails.append("memory grew %.1f MB (>64)" % grew_mb)
	if orphan > 16:
		fails.append("orphan nodes %d (>16)" % orphan)
	if loads < 2:
		fails.append("too few scene loads: %d" % loads)
	print("SOAK_RESULT result=", "PASS" if fails.is_empty() else "FAIL",
		" minutes=%.1f" % (float(total_frames) / 3600.0),
		" frames=", total_frames, " loads=", loads,
		" kills=", kills, " deaths=", deaths,
		" grew_mb=%.1f" % grew_mb,
		" nodes=", nodes, " orphan=", orphan,
		" fails=", fails)
