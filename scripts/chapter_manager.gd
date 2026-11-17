extends Node
## FLOW-01／FLOW-03：線性章節管理器與單槽檢查點。
## 場景只負責自己的演出；跨場景的節拍、旗標、戰利品與存檔都放這裡。

signal beat_changed(beat_id: String)
signal checkpoint_saved(beat_id: String)
signal checkpoint_failed(reason: String)

const STORY := preload("res://data/story_beats.gd")
const PRELOADER := preload("res://scripts/scene_preloader.gd")
const DEFAULT_LOOT := {"碎銀": 0, "小虎爪": 0, "伥鬼的木牌": 0}
const CHECKPOINT_PATH := "user://checkpoint.json"
const BACKUP_SUFFIX := ".bak"

var current_beat: String = ""
var flags: Dictionary = {}
var loot_counts: Dictionary = DEFAULT_LOOT.duplicate()
var player_hp: int = 800
var checkpoint_path: String = CHECKPOINT_PATH
var last_checkpoint_error: String = ""
var last_load_source: String = ""
var last_load_recovered: bool = false

func _ready() -> void:
	if current_beat == "":
		current_beat = STORY.first_beat()

func start_new_game() -> void:
	current_beat = STORY.first_beat()
	flags.clear()
	loot_counts = DEFAULT_LOOT.duplicate()
	player_hp = 800
	clear_checkpoint()

func set_beat(id: String) -> bool:
	if STORY.beat(id).is_empty():
		return false
	current_beat = id
	beat_changed.emit(id)
	return true

func goto_beat(id: String) -> bool:
	if not set_beat(id):
		return false
	var path: String = STORY.scene_path(id)
	if path == "":
		return false
	_switch_scene(path)
	return true

## 切場景：下一個場景若已被非同步預載好，直接吃現成 PackedScene；否則退回同步載入。
func _switch_scene(path: String) -> void:
	var packed: PackedScene = PRELOADER.ready_scene(path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)

func advance() -> bool:
	var next: String = STORY.next_id(current_beat)
	if next == "":
		return false
	return goto_beat(next)

func current_scene_path() -> String:
	return STORY.scene_path(current_beat)

func mark_clear(id: String = "") -> void:
	var key: String = id if id != "" else current_beat
	if key != "":
		flags[key] = true

func is_clear(id: String) -> bool:
	return bool(flags.get(id, false))

func reset_loot() -> void:
	loot_counts = DEFAULT_LOOT.duplicate()

func add_loot(item_name: String, amount: int = 1) -> void:
	if not loot_counts.has(item_name):
		loot_counts[item_name] = 0
	loot_counts[item_name] += amount

func loot_total() -> int:
	var total: int = 0
	for v in loot_counts.values():
		total += int(v)
	return total

## FLOW-03：單槽、原子寫入（先寫 .tmp 再覆蓋），覆蓋前保留上一份可讀存檔為 .bak。
func save_checkpoint(beat_id: String = "", player_hp: int = 0) -> bool:
	var id: String = beat_id if beat_id != "" else current_beat
	if STORY.beat(id).is_empty():
		last_checkpoint_error = "unknown beat %s" % id
		checkpoint_failed.emit(last_checkpoint_error)
		return false
	var payload: Dictionary = {
		"version": 1,
		"beat": id,
		"flags": flags.duplicate(),
		"loot": loot_counts.duplicate(),
		"player_hp": player_hp,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var text: String = JSON.stringify(payload)
	# 只備份「目前讀得懂」的存檔，避免壞檔把上一份好檔蓋掉。
	if FileAccess.file_exists(checkpoint_path):
		var previous_text: String = _read_text(checkpoint_path)
		if previous_text != "" and not _parse_text(previous_text).is_empty():
			_write_atomic(backup_path(), previous_text)
	if not _write_atomic(checkpoint_path, text):
		if last_checkpoint_error == "":
			last_checkpoint_error = "write checkpoint failed"
		checkpoint_failed.emit(last_checkpoint_error)
		return false
	last_checkpoint_error = ""
	last_load_source = ""
	last_load_recovered = false
	checkpoint_saved.emit(id)
	return true

func backup_path() -> String:
	return checkpoint_path + BACKUP_SUFFIX

func has_backup() -> bool:
	return FileAccess.file_exists(backup_path())

## none／ok／backup（主檔壞、備份可救）／corrupt（兩份都壞）。
func checkpoint_state() -> String:
	if not _read_payload(checkpoint_path).is_empty():
		return "ok"
	if not _read_payload(backup_path()).is_empty():
		return "backup"
	if FileAccess.file_exists(checkpoint_path) or FileAccess.file_exists(backup_path()):
		return "corrupt"
	return "none"

func has_checkpoint() -> bool:
	var state: String = checkpoint_state()
	return state == "ok" or state == "backup"

func load_checkpoint() -> bool:
	last_checkpoint_error = ""
	last_load_source = ""
	last_load_recovered = false
	var primary: Dictionary = _read_payload(checkpoint_path)
	if not primary.is_empty():
		_apply_payload(primary)
		last_load_source = "primary"
		return true
	var primary_error: String = "corrupt checkpoint" if FileAccess.file_exists(checkpoint_path) else "no checkpoint"
	var backup: Dictionary = _read_payload(backup_path())
	if backup.is_empty():
		last_checkpoint_error = primary_error
		return false
	# 主檔損壞或遺失時以備份續玩，並把備份回寫成新的主檔。
	_apply_payload(backup)
	last_load_source = "backup"
	last_load_recovered = true
	var backup_text: String = _read_text(backup_path())
	if backup_text != "":
		_write_atomic(checkpoint_path, backup_text)
	return true

func goto_checkpoint() -> bool:
	if not load_checkpoint():
		return false
	var path: String = STORY.scene_path(current_beat)
	if path == "":
		return false
	_switch_scene(path)
	return true

func clear_checkpoint() -> void:
	last_checkpoint_error = ""
	last_load_source = ""
	last_load_recovered = false
	for path in [checkpoint_path, backup_path(), checkpoint_path + ".tmp", backup_path() + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text

func _read_payload(path: String) -> Dictionary:
	return _parse_text(_read_text(path))

## 驗證種類與節拍；任何缺漏或型別錯誤都視為損壞。
func _parse_text(text: String) -> Dictionary:
	if text == "":
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var id: String = String(data.get("beat", ""))
	if STORY.beat(id).is_empty():
		return {}
	if typeof(data.get("flags", {})) != TYPE_DICTIONARY:
		return {}
	if typeof(data.get("loot", {})) != TYPE_DICTIONARY:
		return {}
	return data

func _apply_payload(data: Dictionary) -> void:
	current_beat = String(data.get("beat", ""))
	var saved_flags = data.get("flags", {})
	flags = saved_flags.duplicate()
	player_hp = clampi(_safe_int(data.get("player_hp", 800), 800), 1, 800)
	loot_counts = DEFAULT_LOOT.duplicate()
	var saved_loot = data.get("loot", {})
	for key in saved_loot.keys():
		loot_counts[String(key)] = _safe_int(saved_loot[key], 0)
	for key in DEFAULT_LOOT.keys():
		if not loot_counts.has(key):
			loot_counts[key] = 0
	beat_changed.emit(current_beat)

func _safe_int(value, fallback: int = 0) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return int(value)
		TYPE_STRING:
			return int(value) if String(value).is_valid_int() else fallback
	return fallback

## 先寫 .tmp 再 rename；部分平台不允許 rename 覆蓋，退一步直寫目標。
func _write_atomic(path: String, text: String) -> bool:
	var tmp_path: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		last_checkpoint_error = "open tmp failed"
		return false
	f.store_string(text)
	f.close()
	var src_abs: String = ProjectSettings.globalize_path(tmp_path)
	var dst_abs: String = ProjectSettings.globalize_path(path)
	var err: int = DirAccess.rename_absolute(src_abs, dst_abs)
	if err != OK:
		var f2: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f2 == null:
			last_checkpoint_error = "rename=%d write fallback failed" % err
			return false
		f2.store_string(text)
		f2.close()
		DirAccess.remove_absolute(src_abs)
	return true

## 測試用：把存檔路徑指到獨立檔案，避免污染真正的 user://checkpoint.json
func set_checkpoint_path_for_test(path: String) -> void:
	checkpoint_path = path
	last_checkpoint_error = ""
	last_load_source = ""
	last_load_recovered = false

func reset_after_test() -> void:
	checkpoint_path = CHECKPOINT_PATH
	clear_checkpoint()
	current_beat = STORY.first_beat()
	flags.clear()
	player_hp = 800
	reset_loot()
