extends SceneTree
## 死亡化青煙 + 掉落自測（無頭，不開視窗）
## 手動推進 P2 的 _physics_process 與 Main 的 _process，避免依賴真實時序。
##   godot --headless --path 'D:\水滸g\game' --script res://tools/selftest_death.gd

const PICKUP := preload("res://scripts/coin_pickup.gd")
const DT: float = 1.0 / 60.0

var main: Node2D
var p1: CharacterBody2D
var p2: CharacterBody2D
var n: int = 0
var fails: Array = []

func _initialize() -> void:
	main = load("res://scenes/MainRigged.tscn").instantiate()
	root.add_child(main)
	p1 = main.get_node("P1")
	p2 = main.get_node("P2")
	main.set_process(false)
	p1.set_physics_process(false)
	# P2 保留引擎物理推進（死亡演出靠它自己的 _physics_process 計時），只手動推 Main 的 _process
	physics_frame.connect(_on_physics)

func _check(name: String, ok: bool) -> void:
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")
	if not ok:
		fails.append(name)

func _pickups() -> Array:
	var out: Array = []
	for ch in main.get_children():
		if ch.get_script() == PICKUP:
			out.append(ch)
	return out

func _on_physics() -> void:
	n += 1
	if n == 2:
		p2.drop_chance = 0.0          # 先驗「碎銀必掉、木牌不一定」，木牌另外強制掉一次
		p2.take_damage(400, -1.0)
		_check("hp clamped to zero", p2.current_hp == 0)
		_check("death sequence started", p2._dying and not p2._death_done)
		_check("no victory before smoke", not main._battle_over)
		return

	# n=3..94 手動推進主場景判定（P2 的死亡計時由引擎物理幀自走）
	if n >= 3 and n <= 94:
		main._process(DT)

	if n == 8:
		_check("death plays knockdown", p2._state == "TigerKnockdown")
		_check("body still visible early", p2.get_node("Visual").visible)
		var mist = p2._mist_node
		_check("hand-drawn mist plays 6 frames",
			mist != null and mist.sprite_frames.get_frame_count("mist") == 6 and mist.is_playing())
	elif n == 35:
		var vis = p2.get_node("Visual")
		_check("body fading into mist", vis.visible and vis.modulate.a < 0.95)
		_check("still not finished mid-fade", not p2._death_done)
	elif n == 66:
		_check("death finished", p2._death_done)
		_check("body hidden after smoke", not p2.get_node("Visual").visible)
		_check("victory only after smoke", main._battle_over and main._result_label.text == "武松勝！")
	elif n == 70:
		_check("corpse collision disabled", p2.get_node("Collision").disabled)
		var drops: Array = _pickups()
		_check("silver always drops", drops.size() == 1 and drops[0].item_name == "碎銀")
		p2._spawn_drop(true)         # 強制掉木牌，驗證任務道具
		drops = _pickups()
		var has_tag: bool = false
		for d in drops:
			if d.item_name == "小虎爪":
				has_tag = true
		_check("tag drop when forced", drops.size() == 3 and has_tag)
		# 把武松挪到碎銀上，測拾取與提示
		var silver = drops[0]
		p1.position = Vector2(silver.position.x, 820.0)
	elif n == 84:
		var drops2: Array = _pickups()
		_check("pickup collected on touch", drops2.size() <= 2)
		_check("silver pickup counted", main.loot_counts["碎銀"] >= 1)
		_check("pickup toast shown", main._pickup_label.visible and main._pickup_label.text.contains("碎銀"))
		_check("loot label shows silver", main._loot_label.text.contains("碎銀"))
		var has_claw: bool = false
		for d in drops2:
			if d.item_name == "小虎爪":
				has_claw = true
				p1.position = Vector2(d.position.x, 820.0)
		_check("claw remains for pickup", has_claw)
	elif n == 90:
		_check("claw pickup counted", main.loot_counts["小虎爪"] == 1)
		_check("loot label shows claw", main._loot_label.text.contains("小虎爪 1"))
		_check("all drops collected", _pickups().is_empty())
	elif n == 94:
		print("SELFTEST death fails=", fails.size(), " drops_left=", _pickups().size(),
			" billboard=", p2._death_done)
		quit(0 if fails.is_empty() else 1)
