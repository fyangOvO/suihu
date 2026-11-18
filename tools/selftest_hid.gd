extends SceneTree
## HID-01 / HID-05 自測：
##  A. HID-01 虎死後靠近虎屍 → 酒氣補滿、WineMist 生成、2.2s 後轉 B8
##  B. HID-01 不靠近 → 6s 超時照常轉 B8，酒氣不補
##  C. HID-05 被 BossDeathPounce 打死 → 先出虎台詞，2.4s 後才彈死亡面板
##  D. HID-05 其他招式致死 → 死亡面板立即出現、不播台詞
##  E. 死因欄位 last_hit_state 存在且預設為空
## 用法：godot --headless --path <game> --script res://tools/selftest_hid.gd

const CHAPTER_MANAGER := "res://scripts/chapter_manager.gd"
const SCN05 := "res://scenes/chapters/SCN_05_Ridge.tscn"
const RIGGED := "res://scenes/RiggedFighter.tscn"
const HID05_LINE := "你也是被放出來的"

var fails: Array = []
var cm

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails.append(label if detail == "" else "%s (%s)" % [label, detail])

func _initialize() -> void:
	await process_frame
	cm = root.get_node_or_null("ChapterManager")
	print("HID_CM_EXISTING=", cm != null)
	if cm == null:
		cm = load(CHAPTER_MANAGER).new()
		cm.name = "ChapterManager"
		root.add_child(cm)
	await process_frame

	await _case_absorb()
	await _case_timeout()
	await _case_hid05(true)
	await _case_hid05(false)

	var fighter = load(RIGGED).instantiate()
	root.add_child(fighter)
	await physics_frame
	_check("last_hit_state defaults empty", fighter.last_hit_state == "", fighter.last_hit_state)
	fighter.queue_free()

	print("HID_RESULT result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails.size(), " ", fails)
	quit(0 if fails.is_empty() else 1)

func _new_scene():
	cm.set_beat("B7")
	var scn = load(SCN05).instantiate()
	root.add_child(scn)
	await physics_frame
	await physics_frame
	return scn

func _drop(scn) -> void:
	scn.queue_free()
	await process_frame
	await process_frame

func _tick(n: int) -> void:
	for i in n:
		await physics_frame

func _kill_boss(scn) -> void:
	scn.p2.take_damage(99999, 1.0)
	for i in 90:
		await physics_frame
		if scn.p2._death_done:
			break

func _wait_window(scn, max_frames: int = 300) -> void:
	for i in max_frames:
		await physics_frame
		if scn._corpse_wait >= 0.0:
			return

func _case_absorb() -> void:
	var scn = await _new_scene()
	await _kill_boss(scn)
	await _wait_window(scn)
	_check("corpse wait started", scn._corpse_wait >= 0.0)
	_check("corpse mist marks spot", scn.get_node_or_null("CorpseMist") != null)
	scn.p1.global_position = scn.p2.global_position + Vector2(-100, 0)
	await _tick(24)
	_check("corpse mist stops after absorb", scn._corpse_mist != null and not scn._corpse_mist.emitting)
	_check("wine filled to 100", is_equal_approx(scn.p1.wine_gauge, 100.0), str(scn.p1.wine_gauge))
	_check("wine mist spawned", scn.get_node_or_null("WineMist") != null)
	_check("absorb banner text", scn._banner.text.begins_with("酒氣入喉"), scn._banner.text)
	await _tick(140)
	_check("advance to B8 after hold", scn._pending_next == "B8", scn._pending_next)
	await _drop(scn)

func _case_timeout() -> void:
	var scn = await _new_scene()
	await _kill_boss(scn)
	await _wait_window(scn)
	# 玩家留在出生點（距虎屍 700+ px），不靠近
	await _tick(340)
	_check("timeout advances to B8", scn._pending_next == "B8", scn._pending_next)
	_check("wine not filled without approach", scn.p1.wine_gauge < 100.0, str(scn.p1.wine_gauge))
	_check("no wine mist on timeout", scn.get_node_or_null("WineMist") == null)
	await _drop(scn)

func _case_hid05(death_pounce: bool) -> void:
	var scn = await _new_scene()
	scn.p1.last_hit_state = "BossDeathPounce" if death_pounce else "BossClaw"
	scn.p1.take_damage(9999, 1.0)
	await _tick(20)
	if death_pounce:
		_check("hid05 flag set only for death pounce", scn._hid05_shown)
		_check("hid05 banner text", scn._banner.text == HID05_LINE, scn._banner.text)
		_check("death panel deferred", scn._shell._page != "death", scn._shell._page)
		await _tick(150)
		_check("death panel shown after line", scn._shell._page == "death", scn._shell._page)
	else:
		_check("no hid05 line for normal death", not scn._hid05_shown)
		_check("death panel immediate", scn._shell._page == "death", scn._shell._page)
	scn._shell._close_all()
	paused = false
	await _drop(scn)
