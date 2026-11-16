extends RefCounted
## 音頻調用入口：所有遊戲腳本只透過這裡發聲，不直接持有 AudioManager。
## 以 `/root/AudioManager` 取得 autoload；`--script` 自測或單場景預覽沒有
## autoload 時全部安全 no-op，不會因缺管理器而報錯。

const SETTINGS := preload("res://scripts/ui/user_settings.gd")

static func _manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	var root: Window = (loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("AudioManager")

static func has_manager() -> bool:
	return _manager() != null

static func play_sfx(stream_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var manager := _manager()
	if manager == null:
		return false
	return bool(manager.call("play_sfx", stream_name, volume_db, pitch))

static func play_bgm(track: String, fade: float = 0.8) -> bool:
	var manager := _manager()
	if manager == null:
		return false
	return bool(manager.call("play_bgm", track, fade))

static func stop_bgm(fade: float = 0.6) -> void:
	var manager := _manager()
	if manager != null:
		manager.call("stop_bgm", fade)

static func play_voice(stream_name: String, volume_db: float = 0.0) -> bool:
	var manager := _manager()
	if manager == null:
		return false
	return bool(manager.call("play_voice", stream_name, volume_db))

static func duck_dialogue(on: bool) -> void:
	var manager := _manager()
	if manager != null:
		manager.call("duck_for_dialogue", on)

static func set_volume(kind: String, value: float) -> bool:
	var manager := _manager()
	if manager == null:
		# 無管理器時仍寫入存檔，設置頁在預覽場景也能記住音量。
		return SETTINGS.save_volume(kind, value)
	return bool(manager.call("set_volume", kind, value))

static func get_volume(kind: String) -> float:
	var manager := _manager()
	if manager == null:
		return SETTINGS.load_volume(kind)
	return float(manager.call("get_volume", kind))
