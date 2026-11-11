extends SceneTree
## BOS-06 首版自测：Boss 数据、66%/33% 阶段转场、削韧 320 破防、腹部 ×2 窗口、
## 三阶段决策池、尾巴/撲擊實跑命中、召小虎上限、死亡收尾。
## 用法：godot --headless --path <game> --script res://tools/selftest_boss.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
const BOSS_PLANS: Array = ["approach", "retreat", "wait", "pounce", "tail", "rear", "roar", "summon", "iron", "death", "rib"]

var fails: Array = []
var boss: CharacterBody2D
var player: CharacterBody2D
var floor_body: StaticBody2D

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(900.0, 900.0)
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2600.0, 40.0)
	shape.shape = rect
	floor_body.add_child(shape)
	root.add_child(floor_body)

	var player_packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	var boss_packed: PackedScene = load("res://scenes/Boss.tscn")
	player = player_packed.instantiate()
	boss = boss_packed.instantiate()
	root.add_child(player)
	root.add_child(boss)
	player.position = Vector2(1040.0, 880.0)
	boss.position = Vector2(900.0, 880.0)
	player.is_player1 = true
	boss.is_player1 = false
	player.opponent = boss
	boss.opponent = player
	player.set_physics_process(false)
	boss.opponent = null
	boss.set_physics_process(true)
	await physics_frame
	player.set_physics_process(false)   # 假人凍結必須在首幀後再調一次
	boss.set_physics_process(false)
	await physics_frame
	boss._physics_process(1.0 / 60.0)   # 先跑一次 _boss_boot，避免後續血量被 boot 重置
	# ---- A. 數據 ----
	_check("boss max_hp 1200 / current 1200", boss.max_hp == 1200 and boss.current_hp == 1200)
	_check("boss starts BossIdle", boss._state == "BossIdle")
	# BOS-10 觀感：Visual 必須蓋過 110×240 受擊盒，且腳底落在原點附近。
	var visual: Sprite2D = boss.get_node("Visual")
	var body_col: CollisionShape2D = boss.get_node("Collision")
	var body_rect: RectangleShape2D = body_col.shape
	var idle_img := Image.new()
	var idle_ok := idle_img.load("res://assets/anim/boss/boss-idle.png") == OK
	var used := idle_img.get_used_rect()
	var visible_h: float = float(used.size.y) * visual.scale.y if idle_ok else 0.0
	var feet_y: float = visual.position.y + (720.0 - 768.0 * 0.5) * visual.scale.y
	_check("Boss collision 110x240", body_rect.size == Vector2(110, 240))
	_check("Boss visual scale 0.72", absf(visual.scale.x - 0.72) < 0.001 and absf(visual.scale.y - 0.72) < 0.001)
	_check("Boss visual feet at ground", absf(feet_y) <= 2.0)
	_check("Boss visual covers hurtbox height", visible_h >= 240.0 * 1.15)
	_check("BossPounce 200/82f", int(boss._spec("BossPounce").get("damage", 0)) == 200
		and DATA.total_frames(boss._spec("BossPounce")) == 82)
	_check("BossTail 140/48f", int(boss._spec("BossTail").get("damage", 0)) == 140
		and DATA.total_frames(boss._spec("BossTail")) == 48)
	_check("BossRearUp 220/66f", int(boss._spec("BossRearUp").get("damage", 0)) == 220
		and DATA.total_frames(boss._spec("BossRearUp")) == 66)
	_check("BossIronTail 180/60f low+unblockable",
		int(boss._spec("BossIronTail").get("damage", 0)) == 180
		and DATA.total_frames(boss._spec("BossIronTail")) == 60
		and bool(boss._spec("BossIronTail").get("low", false))
		and bool(boss._spec("BossIronTail").get("unblockable", false)))
	_check("BossDeathPounce 800/98f once", int(boss._spec("BossDeathPounce").get("damage", 0)) == 800
		and DATA.total_frames(boss._spec("BossDeathPounce")) == 98
		and bool(boss._spec("BossDeathPounce").get("once_per_phase", false)))

	# ---- A2. BOS-10 擊殺演出：3 秒時間軸 + 可跳 ----
	var cine: CanvasLayer = boss.get_node("BossDeathCine")
	var cine_finished: Array = [false]
	cine.finished.connect(func(): cine_finished[0] = true)
	cine.set_process(false)
	cine.play()
	cine._process(1.5)
	_check("death cine 1.5s -> 水潭", "水潭" in cine._title.text)
	cine._process(1.3)
	_check("death cine 2.8s -> 虎氣自洩", "自洩" in cine._title.text)
	cine.skip()
	_check("death cine skippable", cine_finished[0] and not cine.visible)

	# ---- B. 階段轉場 ----
	boss._ai_cd = 999.0
	boss.opponent = null
	boss.take_damage(410, 1.0)
	_check("410 -> phase window", boss.current_hp == 790 and boss._state == "BossPhase")
	_check("phase transition 1.2s", is_equal_approx(boss.boss_transition_t, 1.2))
	var hp_during: int = boss.current_hp
	boss.take_damage(100, 1.0)
	_check("phase transition invulnerable", boss.current_hp == hp_during)
	for i in 80:
		boss._physics_process(1.0 / 60.0)
	_check("transition ends -> phase 2", boss.boss_phase == 2 and boss._state == "BossIdle")
	boss.take_damage(400, 1.0)
	_check("400 -> phase 3 window", boss.current_hp == 390 and boss._state == "BossPhase")
	for i in 80:
		boss._physics_process(1.0 / 60.0)
	_check("transition ends -> phase 3", boss.boss_phase == 3 and boss._state == "BossIdle")

	# ---- C. 削韌破防 vs 霸體 ----
	boss.current_hp = 1000
	boss.boss_poise = 300
	boss.take_damage(40, 1.0)
	_check("poise 300 + 40 -> BossHurt", boss._state == "BossHurt" and boss.current_hp == 960)
	boss.current_hp = 1000
	boss.boss_poise = 0
	boss.change_state("BossIdle")
	boss.take_damage(100, 1.0)
	_check("poise 50 -> armor, stays idle", boss._state == "BossIdle" and boss.boss_poise == 50)

	# ---- D. 腹部 ×2 僅倒地窗口 ----
	boss.change_state("BossKnockdown")
	await process_frame
	_check("BellyShape opens on knockdown", not boss.get_node("BellyBox/BellyShape").disabled)
	boss.change_state("BossIdle")
	await process_frame
	_check("BellyShape closes on idle", boss.get_node("BellyBox/BellyShape").disabled)

	# ---- E. 三階段決策池 ----
	_check("P1 close -> pounce/tail", boss.boss_plan(120.0, 1, 0.1, 0.0, 0.0, 0.0) == "pounce")
	_check("P1 mid -> tail", boss.boss_plan(120.0, 1, 0.7, 0.0, 0.0, 0.0) == "tail")
	_check("P2 summon window", boss.boss_plan(120.0, 2, 0.1, 0.0, 0.0, 0.0) == "summon")
	_check("P2 roar", boss.boss_plan(120.0, 2, 0.55, 0.0, 0.0, 0.0) == "roar")
	_check("P3 no summon/retreat", boss.boss_plan(120.0, 3, 0.1, 0.0, 0.0, 0.0) == "iron")
	_check("P3 death pounce", boss.boss_plan(120.0, 3, 0.5, 0.0, 0.0, 0.0) == "death")
	var legal: bool = true
	for phase in [1, 2, 3]:
		for d in [90.0, 200.0, 380.0, 560.0]:
			for i in 100:
				if not (boss.boss_plan(d, phase, float(i) / 100.0, 0.0, 0.0, 0.0) in BOSS_PLANS):
					legal = false
	_check("100 rolls x 3 phases legal", legal)

	# ---- F. 實跑命中：尾掃與撲擊 ----
	boss.opponent = null
	boss._ai_cd = 999.0
	boss.set_physics_process(true)
	boss.change_state("BossIdle")
	player.current_hp = 800
	player.position = Vector2(1000.0, 880.0)
	player.face_direction = -1.0
	boss.face_direction = 1.0
	boss.change_state("BossTail")
	for i in 50:
		await physics_frame
	_check("BossTail hits 140", player.current_hp == 660)
	boss.change_state("BossIdle")
	player.current_hp = 800
	player.position = Vector2(1040.0, 880.0)
	boss.change_state("BossPounce")
	for i in 90:
		await physics_frame
	_check("BossPounce hits 200", player.current_hp == 600)
	boss.change_state("BossIdle")

	# ---- G. 咆哮硬直 ----
	boss.opponent = player
	boss._ai_cd = 0.0
	player.position = Vector2(760.0, 880.0)
	player.face_direction = -1.0   # 背向 Boss（Boss 在右）
	player.change_state("Idle")
	boss.face_direction = 1.0
	boss.change_state("BossRoar")
	for i in 24:
		await physics_frame
	_check("BossRoar back-turn -> StunShort", player._state == "StunShort")
	# 正面咆哮 -> 30 幀
	player.change_state("Idle")
	player.face_direction = 1.0
	boss.change_state("BossRoar")
	for i in 24:
		await physics_frame
	_check("BossRoar frontal -> Stun", player._state == "Stun")
	boss.opponent = null
	boss.change_state("BossIdle")

	# ---- H. 可擋但推遠：RearUp 只吃 25% ----
	boss.opponent = null
	boss._ai_cd = 999.0
	player.current_hp = 800
	player.position = Vector2(1040.0, 880.0)
	player.face_direction = -1.0
	player.change_state("Block")
	boss.face_direction = 1.0
	boss.change_state("BossRearUp")
	for i in 70:
		await physics_frame
	_check("BossRearUp blocked 25% -> 55", player.current_hp == 745)
	_check("blocked RearUp pushed 220", absf(player.velocity.x) >= 200.0)
	player.change_state("Idle")
	boss.change_state("BossIdle")
	boss.set_physics_process(false)   # 後面的倍率測試改為純手動，避免 AI 把姿態打回 Idle

	# ---- I. 多 HurtBox 倍率：頭 1.5、倒地肚 2.0 ----
	boss.opponent = player
	player.opponent = boss
	boss.current_hp = 1200
	boss.change_state("BossIdle")
	boss.position = Vector2(1040.0, 1050.0)   # 把頭盒抬到 P1 攻擊盒高度
	player.position = Vector2(900.0, 880.0)
	player.face_direction = 1.0
	player.set_physics_process(true)
	player.change_state("Light1")
	for i in 22:
		await physics_frame
	_check("HeadBox x1.5 -> 60 dmg", boss.current_hp == 1140)
	player.set_physics_process(false)

	boss.position = Vector2(1040.0, 880.0)
	boss.change_state("BossKnockdown")
	await process_frame
	player.position = Vector2(900.0, 880.0)
	player.face_direction = 1.0
	player.current_hp = 800
	player.set_physics_process(true)
	player.change_state("Light1")
	for i in 22:
		await physics_frame
	_check("BellyBox x2.0 -> 80 dmg", boss.current_hp == 1060)
	player.set_physics_process(false)
	boss.change_state("BossIdle")
	boss.current_hp = 1200

	# ---- J. 召小虎上限 2 ----
	boss.opponent = player
	boss._ai_cd = 0.0
	boss.change_state("BossSummon")
	boss._frame = 19
	boss._physics_process(1.0 / 60.0)
	boss._physics_process(1.0 / 60.0)
	_check("BossSummon spawns 2 tigers", boss.boss_summoned.size() == 2)

	# ---- H. 死亡收尾 ----
	boss.opponent = null
	boss.current_hp = 50
	boss.take_damage(200, 1.0)
	_check("lethal -> BossDeath + dying", boss._state == "BossDeath" and boss._dying)
	for i in 100:
		boss._physics_process(1.0 / 60.0)
	await process_frame
	_check("death finished", boss._death_done and not boss.get_node("Visual").visible)
	_check("hurt boxes disabled on death",
		not boss.get_node("HurtBox").monitorable and not boss.get_node("HeadBox").monitorable)

	print("SELFTEST BOSS fails=", fails.size(), " -> ", fails)
	quit(0 if fails.is_empty() else 1)
