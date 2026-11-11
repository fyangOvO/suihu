extends Node
## FLOW-01／FLOW-03：線性章節管理器與單槽檢查點。
## 場景只負責自己的演出；跨場景的節拍、旗標、戰利品與存檔都放這裡。

signal beat_changed(beat_id: String)
signal checkpoint_saved(beat_id: String)
signal checkpoint_failed(reason: String)

const STORY := preload("res://data/story_beats.gd")
const DEFAULT_LOOT := {"碎銀": 0, "小虎爪": 0, "伥鬼的木牌": 0}
const CHECKPOINT_PATH := "user://checkpoint.json"

var current_beat: String = ""
var flags: Dictionary = {}
var loot_counts: Dictionary = DEFAULT_LOOT.duplicate()
var player_hp: int = 800
var checkpoint_path: String = CHECKPOINT_PATH
var last_checkpoint_error: String = ""

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
	get_tree().change_scene_to_file(path)
	return true

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

## FLOW-03：單槽、原子寫入（先寫 .tmp 再覆蓋）。
func save_checkpoint(beat_id: String = "", player_hp: int = 0) -> bool:
	var id: String = beat_id if beat_id != "" else current_beat
	if STORY.beat(id).is_empty():
		checkpoint_failed.emit("unknown beat %s" % id)
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
	var tmp_path: String = checkpoint_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		last_checkpoint_error = "open tmp failed"
		checkpoint_failed.emit(last_checkpoint_error)
		return false
	f.store_string(text)
	f.close()
	var src_abs: String = ProjectSettings.globalize_path(tmp_path)
	var dst_abs: String = ProjectSettings.globalize_path(checkpoint_path)
	var err: int = DirAccess.rename_absolute(src_abs, dst_abs)
	if err != OK:
		# 某些平台不允許 rename 覆蓋；退一步直接寫目標，仍只保留一份。
		var f2: FileAccess = FileAccess.open(checkpoint_path, FileAccess.WRITE)
		if f2 == null:
			last_checkpoint_error = "rename=%d write fallback failed" % err
			checkpoint_failed.emit(last_checkpoint_error)
			return false
		f2.store_string(text)
		f2.close()
		DirAccess.remove_absolute(src_abs)
	last_checkpoint_error = ""
	checkpoint_saved.emit(id)
	return true

func has_checkpoint() -> bool:
	return FileAccess.file_exists(checkpoint_path)

func load_checkpoint() -> bool:
	last_checkpoint_error = ""
	if not FileAccess.file_exists(checkpoint_path):
		last_checkpoint_error = "no checkpoint"
		return false
	var f: FileAccess = FileAccess.open(checkpoint_path, FileAccess.READ)
	if f == null:
		last_checkpoint_error = "open failed"
		return false
	var text: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	var parse_err: int = json.parse(text)
	if parse_err != OK:
		last_checkpoint_error = "malformed json"
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		last_checkpoint_error = "malformed json"
		return false
	var id: String = String(data.get("beat", ""))
	if STORY.beat(id).is_empty():
		last_checkpoint_error = "invalid beat"
		return false
	var saved_flags = data.get("flags", {})
	var saved_loot = data.get("loot", {})
	if typeof(saved_flags) != TYPE_DICTIONARY or typeof(saved_loot) != TYPE_DICTIONARY:
		last_checkpoint_error = "invalid payload"
		return false
	current_beat = id
	flags = saved_flags.duplicate()
	player_hp = int(data.get("player_hp", 800))
	loot_counts = DEFAULT_LOOT.duplicate()
	for key in loot_counts.keys():
		loot_counts[key] = int(saved_loot.get(key, 0))
	beat_changed.emit(current_beat)
	return true

func goto_checkpoint() -> bool:
	if not load_checkpoint():
		return false
	var path: String = STORY.scene_path(current_beat)
	if path == "":
		return false
	get_tree().change_scene_to_file(path)
	return true

func clear_checkpoint() -> void:
	last_checkpoint_error = ""
	if FileAccess.file_exists(checkpoint_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint_path))
	if FileAccess.file_exists(checkpoint_path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint_path + ".tmp"))

## 測試用：把存檔路徑指到獨立檔案，避免污染真正的 user://checkpoint.json
func set_checkpoint_path_for_test(path: String) -> void:
	checkpoint_path = path
	last_checkpoint_error = ""

func reset_after_test() -> void:
	checkpoint_path = CHECKPOINT_PATH
	clear_checkpoint()
	current_beat = STORY.first_beat()
	flags.clear()
	player_hp = 800
	reset_loot()
