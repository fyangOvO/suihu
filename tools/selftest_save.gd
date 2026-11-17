extends SceneTree
## FLOW-03 存檔自測：單槽原子寫、覆蓋前備份、主檔損壞回退、雙壞拒絕、
## 缺主檔由備份續玩、非法節拍與型別容錯。
## 用法：godot --headless --path <game> --script res://tools/selftest_save.gd

const MANAGER := preload("res://scripts/chapter_manager.gd")
const TEST_SAVE := "user://selftest_save_checkpoint.json"

var fails: Array = []
var checks: int = 0
var manager

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	manager = root.get_node_or_null("ChapterManager")
	if manager == null:
		manager = MANAGER.new()
		manager.name = "ChapterManager"
		root.add_child(manager)
	manager.set_checkpoint_path_for_test(TEST_SAVE)
	manager.clear_checkpoint()
	_run()
	_finish()

func _run() -> void:
	_check_basic_save()
	_check_backup_made()
	_check_recover_from_backup()
	_check_double_corruption()
	_check_invalid_and_missing()
	_check_unknown_loot_and_hp()

func _check_basic_save() -> void:
	manager.start_new_game()
	_check("fresh state none", manager.checkpoint_state() == "none")
	_check("fresh has no backup", not manager.has_backup())
	manager.set_beat("B4")
	manager.player_hp = 640
	manager.add_loot("碎銀", 2)
	manager.add_loot("小虎爪", 1)
	_check("save B4 returns true", manager.save_checkpoint("B4", 640))
	_check("primary exists", FileAccess.file_exists(TEST_SAVE))
	_check("state ok", manager.checkpoint_state() == "ok")
	_check("has checkpoint", manager.has_checkpoint())
	_check("first save has no backup", not manager.has_backup())
	_check("no tmp leftover", not FileAccess.file_exists(TEST_SAVE + ".tmp"))
	manager.set_beat("B7")
	manager.player_hp = 800
	manager.reset_loot()
	_check("load primary returns true", manager.load_checkpoint())
	_check("load restores beat B4", manager.current_beat == "B4")
	_check("load restores hp 640", manager.player_hp == 640)
	_check("load restores loot 3", manager.loot_total() == 3)
	_check("load source primary", manager.last_load_source == "primary")
	_check("primary not marked recovered", not manager.last_load_recovered)

func _check_backup_made() -> void:
	manager.set_beat("B5")
	manager.player_hp = 500
	_check("save B5 returns true", manager.save_checkpoint("B5", 500))
	_check("second save creates backup", manager.has_backup())
	var backup_text: String = _read(manager.backup_path())
	_check("backup keeps previous beat B4", backup_text.contains("\"B4\""))
	_check("backup does not overwrite primary", manager.checkpoint_state() == "ok")
	_check("backup tmp cleaned", not FileAccess.file_exists(manager.backup_path() + ".tmp"))

func _check_recover_from_backup() -> void:
	_write(TEST_SAVE, "{broken json")
	_check("corrupt primary state backup", manager.checkpoint_state() == "backup")
	_check("corrupt primary still resumable", manager.has_checkpoint())
	manager.set_beat("B6")
	manager.player_hp = 800
	manager.reset_loot()
	_check("load falls back to backup", manager.load_checkpoint())
	_check("fallback source backup", manager.last_load_source == "backup")
	_check("fallback flagged recovered", manager.last_load_recovered)
	_check("fallback restores B4", manager.current_beat == "B4")
	_check("fallback restores hp 640", manager.player_hp == 640)
	_check("fallback restores loot 3", manager.loot_total() == 3)
	_check("fallback repairs primary", manager.checkpoint_state() == "ok")
	_check("fallback clears error", manager.last_checkpoint_error == "")

func _check_double_corruption() -> void:
	_write(TEST_SAVE, "not json")
	_write(manager.backup_path(), "also not json")
	manager.set_beat("B6")
	manager.player_hp = 777
	manager.reset_loot()
	_check("double corruption rejected", not manager.load_checkpoint())
	_check("double corruption state", manager.checkpoint_state() == "corrupt")
	_check("double corruption not resumable", not manager.has_checkpoint())
	_check("double corruption keeps beat", manager.current_beat == "B6")
	_check("double corruption keeps hp", manager.player_hp == 777)
	_check("double corruption records error", manager.last_checkpoint_error != "")
	manager.clear_checkpoint()
	_check("clear removes primary", not FileAccess.file_exists(TEST_SAVE))
	_check("clear removes backup", not FileAccess.file_exists(manager.backup_path()))
	_check("clear resets state none", manager.checkpoint_state() == "none")

func _check_invalid_and_missing() -> void:
	manager.set_beat("B4")
	_check("unknown beat rejected", not manager.save_checkpoint("B99", 800))
	_check("unknown beat writes nothing", manager.checkpoint_state() == "none")
	_check("unknown beat error recorded", manager.last_checkpoint_error.contains("unknown beat"))

	# 缺主檔、只剩備份：仍可續玩並把備份升回主檔。
	manager.start_new_game()
	manager.set_beat("B3")
	manager.add_loot("碎銀", 1)
	_check("seed save B3", manager.save_checkpoint("B3", 620))
	manager.set_beat("B4")
	_check("seed save B4", manager.save_checkpoint("B4", 700))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_check("missing primary state backup", manager.checkpoint_state() == "backup")
	manager.set_beat("B8")
	_check("missing primary loads backup", manager.load_checkpoint())
	_check("missing primary recovers B3", manager.current_beat == "B3")
	_check("missing primary restores hp 620", manager.player_hp == 620)
	_check("missing primary rebuilds primary", FileAccess.file_exists(TEST_SAVE))

func _check_unknown_loot_and_hp() -> void:
	var payload: Dictionary = {
		"version": 1,
		"beat": "B5",
		"flags": {"B4": true},
		"loot": {"碎銀": 2, "自訂": 7, "小虎爪": "3"},
		"player_hp": -50,
		"saved_at": 1,
	}
	_write(TEST_SAVE, JSON.stringify(payload))
	_check("manual payload loads", manager.load_checkpoint())
	_check("unknown loot preserved", int(manager.loot_counts.get("自訂", 0)) == 7)
	_check("numeric string loot coerced", int(manager.loot_counts.get("小虎爪", 0)) == 3)
	_check("missing loot defaults zero", int(manager.loot_counts.get("伥鬼的木牌", -1)) == 0)
	_check("hp clamped to 1", manager.player_hp == 1)
	_check("flags restored", manager.is_clear("B4"))
	manager.clear_checkpoint()

func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text

func _write(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true

func _finish() -> void:
	manager.clear_checkpoint()
	manager.reset_after_test()
	if fails.is_empty():
		print("SAVE_SELFTEST result=PASS fails=0 checks=", checks)
	else:
		print("SAVE_SELFTEST result=FAIL fails=", fails.size(), " checks=", checks, " failed=", fails)
	quit(0 if fails.is_empty() else 1)
