extends SceneTree
## S09.1 失敗重開閉環：死亡面板 → 重試本段／回山神廟 → 回到可玩狀態。
## 不驗戰鬥傷害，只驗 UI 按鈕是否真的把場景與章節狀態接回去。
## 用法：godot --headless --path <game> --script res://tools/selftest_restart_flow.gd

const SCN02 := "res://scenes/chapters/SCN_02_Trail.tscn"
const SCN04 := "res://scenes/chapters/SCN_04_Temple.tscn"
const TEST_SAVE := "user://selftest_restart_checkpoint.json"
const MAX_FRAMES: int = 12000

enum {
	WAIT_FIRST_FIGHT,
	WAIT_FIRST_DEATH,
	WAIT_RETRY_RELOAD,
	WAIT_TEMPLE_CHECKPOINT,
	WAIT_B5_FIGHT,
	WAIT_SECOND_DEATH,
	WAIT_CHECKPOINT_RESTORE,
	DONE,
}

var fails: Array = []
var cm
var frame: int = 0
var stage: int = WAIT_FIRST_FIGHT
var scene_key: String = ""
var scene_frames: int = 0
var saved_hp: int = 0
var dialogue_calls: int = 0
var first_retry_scene: String = ""
var restored_scene: String = ""

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	cm = root.get_node_or_null("ChapterManager")
	if cm == null:
		cm = load("res://scripts/chapter_manager.gd").new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	cm.set_checkpoint_path_for_test(TEST_SAVE)
	cm.clear_checkpoint()
	cm.start_new_game()
	cm.set_beat("B3")
	call_deferred("_boot")

func _boot() -> void:
	change_scene_to_file(SCN02)

func _scene() -> Node:
	return current_scene

func _sid() -> String:
	var scene := _scene()
	if scene != null and scene.has_method("scene_id"):
		return String(scene.call("scene_id"))
	return ""

func _shell() -> CanvasLayer:
	var scene := _scene()
	if scene == null:
		return null
	return scene.get_node_or_null("GameShell")

func _p1() -> Node:
	var scene := _scene()
	if scene == null:
		return null
	return scene.get_node_or_null("P1")

func _shell_page() -> String:
	var sh := _shell()
	if sh == null:
		return ""
	if sh.has_method("current_page"):
		return String(sh.call("current_page"))
	return ""

func _press_death_button(node_name: String) -> bool:
	var sh := _shell()
	if sh == null:
		return false
	var btn := sh.get_node_or_null("ShellRoot/DeathPanel/%s" % node_name) as Button
	if btn == null:
		return false
	btn.pressed.emit()
	return true

func _kill_p1() -> void:
	var p1 := _p1()
	if p1 != null and p1.current_hp > 0:
		p1.take_damage(9999, 1.0)
		print("FORCE_DEATH beat=", cm.current_beat, " scene=", _sid())

func _finish() -> void:
	stage = DONE
	print("RESTART_FLOW_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL",
		" fails=", fails, " frames=", frame, " beat=", cm.current_beat,
		" checkpoint=", cm.has_checkpoint(), " dialogue_calls=", dialogue_calls)
	if cm.has_checkpoint():
		cm.clear_checkpoint()
	quit(0 if fails.is_empty() else 1)

func _process(_delta: float) -> bool:
	frame += 1
	if frame >= MAX_FRAMES:
		_check("timeout", false)
		_finish()
		return true

	var scene := _scene()
	if scene == null:
		return false
	var sid := _sid()
	if sid != scene_key:
		scene_key = sid
		scene_frames = 0
		print("SCENE ", frame, " -> ", sid, " beat=", cm.current_beat)
	else:
		scene_frames += 1

	# 所有對話都用 next 推進；對話中不做別的動作。
	var dialogue = scene.get("dialogue")
	if dialogue != null and dialogue.has_method("is_active") and dialogue.call("is_active"):
		if frame % 12 == 0:
			dialogue.call("next")
			dialogue_calls += 1
		return false

	if stage == WAIT_FIRST_FIGHT:
		if sid == "SCN-02" and _p1() != null and scene_frames > 20:
			_kill_p1()
			stage = WAIT_FIRST_DEATH
		return false

	if stage == WAIT_FIRST_DEATH:
		if sid != "SCN-02":
			return false
		if _shell_page() == "death":
			var sh := _shell()
			var checkpoint := sh.get_node_or_null("ShellRoot/DeathPanel/DeathCheckpoint") as Button
			_check("death panel shown before checkpoint", true)
			_check("checkpoint disabled without save", checkpoint != null and checkpoint.disabled)
			_check("tree paused on death", paused)
			if not _press_death_button("DeathRetry"):
				_check("DeathRetry button exists", false)
				_finish()
				return true
			first_retry_scene = sid
			stage = WAIT_RETRY_RELOAD
		return false

	if stage == WAIT_RETRY_RELOAD:
		if sid == "SCN-02" and scene_frames > 12:
			var p1 := _p1()
			_check("retry reloads SCN-02", true)
			_check("retry keeps B3", cm.current_beat == "B3")
			_check("retry resumes playable state", scene != null and not bool(scene.get("_stage_over"))
				and p1 != null and p1.current_hp == 800 and p1.is_physics_processing())
			_check("retry closes shell", _shell_page() == "" and not paused)
			# 這段只驗重開；直接把流程推到 B4 檢查點。
			cm.mark_clear("B3")
			cm.set_beat("B4")
			change_scene_to_file(SCN04)
			stage = WAIT_TEMPLE_CHECKPOINT
			return false
		return false

	if stage == WAIT_TEMPLE_CHECKPOINT:
		if sid != "SCN-04":
			return false
		if cm.has_checkpoint():
			saved_hp = cm.player_hp
			_check("B4 checkpoint saved", cm.current_beat == "B4" and saved_hp == 800)
			stage = WAIT_B5_FIGHT
		return false

	if stage == WAIT_B5_FIGHT:
		if sid == "SCN-03" and _p1() != null and scene_frames > 20:
			_check("B4 checkpoint transitions to B5", cm.current_beat == "B5")
			_kill_p1()
			stage = WAIT_SECOND_DEATH
		return false

	if stage == WAIT_SECOND_DEATH:
		if sid != "SCN-03":
			return false
		if _shell_page() == "death":
			var sh := _shell()
			var checkpoint := sh.get_node_or_null("ShellRoot/DeathPanel/DeathCheckpoint") as Button
			var retry := sh.get_node_or_null("ShellRoot/DeathPanel/DeathRetry") as Button
			_check("B5 death panel shown", true)
			_check("checkpoint enabled after B4", checkpoint != null and not checkpoint.disabled)
			if not _press_death_button("DeathCheckpoint"):
				_check("DeathCheckpoint button exists", false)
				_finish()
				return true
			stage = WAIT_CHECKPOINT_RESTORE
		return false

	if stage == WAIT_CHECKPOINT_RESTORE:
		if sid == "SCN-04" and scene_frames > 12:
			var p1 := _p1()
			restored_scene = sid
			_check("checkpoint returns to SCN-04", true)
			_check("checkpoint restores B4", cm.current_beat == "B4")
			_check("checkpoint restores saved hp", p1 != null and p1.current_hp == saved_hp)
			_check("checkpoint resumes playable state", scene != null and not bool(scene.get("_stage_over"))
				and p1 != null and p1.is_physics_processing())
			_check("checkpoint closes shell", _shell_page() == "" and not paused)
			_finish()
			return true
		return false

	return false
