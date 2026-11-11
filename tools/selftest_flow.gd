extends SceneTree
## FLOW-06：章節資料、對話框、檢查點、六場景載入的無頭自測。
## 用法：godot --headless --path <game> --script res://tools/selftest_flow.gd

const STORY := preload("res://data/story_beats.gd")
const DIALOGUE_SCENE := preload("res://scenes/ui/DialogueUI.tscn")
const SCENES := {
	"SCN-01": "res://scenes/chapters/SCN_01_Inn.tscn",
	"SCN-02": "res://scenes/chapters/SCN_02_Trail.tscn",
	"SCN-03": "res://scenes/chapters/SCN_03_Forest.tscn",
	"SCN-04": "res://scenes/chapters/SCN_04_Temple.tscn",
	"SCN-05": "res://scenes/chapters/SCN_05_Ridge.tscn",
	"SCN-06": "res://scenes/chapters/SCN_06_Pool.tscn",
}
const TEST_SAVE := "user://selftest_flow_checkpoint.json"

var fails: Array = []

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	# 測試模式不會自動載入 autoload，手動掛一個同名節點到 /root。
	var manager = load("res://scripts/chapter_manager.gd").new()
	manager.name = "ChapterManager"
	root.add_child(manager)
	await process_frame
	# A. 故事資料
	var errors: Array = STORY.validate()
	_check("story beats valid", errors.is_empty())
	if not errors.is_empty():
		print("STORY errors: ", errors)
	_check("B1-B9 order", STORY.ORDER.size() == 9 and STORY.ORDER[0] == "B1" and STORY.ORDER[8] == "B9")
	_check("every beat has scene", STORY.ORDER.all(func(id): return STORY.scene_path(id) != ""))
	_check("D-01..D-10 length <= 40", STORY.D.size() == 10 and STORY.D.values().all(func(t): return String(t).length() <= 40))

	# B. 章節管理器
	manager.set_checkpoint_path_for_test(TEST_SAVE)
	manager.clear_checkpoint()
	manager.start_new_game()
	_check("new game starts at B1", manager.current_beat == "B1")
	_check("new game loot zero", manager.loot_total() == 0)
	manager.add_loot("碎銀", 2)
	manager.add_loot("小虎爪", 1)
	_check("loot accumulates", manager.loot_total() == 3)
	manager.player_hp = 700
	_check("save checkpoint B4", manager.save_checkpoint("B4", 700))
	_check("checkpoint exists", manager.has_checkpoint())
	manager.set_beat("B7")
	manager.reset_loot()
	_check("load checkpoint", manager.load_checkpoint())
	_check("load restores beat B4", manager.current_beat == "B4")
	_check("load restores hp 700", manager.player_hp == 700)
	_check("load restores loot", manager.loot_total() == 3)

	# 損壞存檔必須拒絕，不得把壞資料讀進來
	manager.set_beat("B5")
	var bad: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	bad.store_string("{broken json")
	bad.close()
	_check("corrupt checkpoint rejected", not manager.load_checkpoint())
	_check("corrupt checkpoint keeps beat", manager.current_beat == "B5")
	_check("corrupt error recorded", manager.last_checkpoint_error != "")
	manager.clear_checkpoint()
	_check("clear checkpoint", not manager.has_checkpoint())

	# C. 對話框
	var dlg = DIALOGUE_SCENE.instantiate()
	root.add_child(dlg)
	await process_frame
	var done: Array = [false]
	dlg.play([{"speaker": "山神", "text": "回頭，還是上去？"}], func(): done[0] = true)
	await process_frame
	_check("dialogue active", dlg.is_active())
	_check("dialogue speaker", dlg.current_speaker() == "山神")
	dlg.next()  # 打字中 → 顯示全文
	_check("dialogue skip completes text", dlg.current_text() == "回頭，還是上去？")
	dlg.next()  # 下一句 → 結束
	_check("dialogue finishes", not dlg.is_active() and done[0])
	dlg.queue_free()
	await process_frame

	# D. 六場景可載入、節點齊全
	for id in SCENES.keys():
		var packed: PackedScene = load(SCENES[id])
		_check("%s loads" % id, packed != null)
		var inst = packed.instantiate()
		root.add_child(inst)
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		_check("%s has P1" % id, inst.get_node_or_null("P1") != null)
		_check("%s has HUD" % id, inst.get_node_or_null("HUD") != null)
		_check("%s has camera" % id, inst.get_node_or_null("BattleCam") != null)
		if id == "SCN-03":
			_check("SCN-03 Tiger 350hp", inst.get_node("P2").max_hp == 350)
		elif id == "SCN-05":
			_check("SCN-05 Boss 1200hp", inst.get_node("P2").max_hp == 1200)
		else:
			_check("%s no opponent" % id, inst.get_node_or_null("P2") == null)
		inst.queue_free()
		await process_frame

	# E. 主菜單與入口
	_check("run/main_scene is MainMenu", String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/MainMenu.tscn")
	var menu_packed: PackedScene = load("res://scenes/MainMenu.tscn")
	_check("MainMenu loads", menu_packed != null)
	var menu = menu_packed.instantiate()
	root.add_child(menu)
	await process_frame
	_check("MainMenu has new button", menu.get_node_or_null("Panel/VBox/BtnNew") != null)
	_check("MainMenu has continue button", menu.get_node_or_null("Panel/VBox/BtnContinue") != null)
	menu.queue_free()
	await process_frame

	manager.reset_after_test()
	print("FLOW_SELFTEST fails=", fails.size(), " -> ", fails)
	quit(0 if fails.is_empty() else 1)
