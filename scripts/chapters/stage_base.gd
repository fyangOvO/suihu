extends Node2D
## 六場景共用骨架：背景／地面／牆／武松／可選敵人／HUD／對話／勝敗切換。
## 子類只覆寫 scene_id、title、背景、敵人與 _on_stage_start/_tick_stage。

const FIGHTER := preload("res://scenes/RiggedFighter.tscn")
const DIALOGUE_SCENE := preload("res://scenes/ui/DialogueUI.tscn")
const STORY := preload("res://data/story_beats.gd")

const GROUND_Y: float = 870.0
const SPAWN_P1 := Vector2(600.0, 820.0)
const SPAWN_P2 := Vector2(1320.0, 820.0)

var p1: CharacterBody2D
var p2: CharacterBody2D = null
var camera: Camera2D
var dialogue: CanvasLayer
var hud: CanvasLayer
var _p1hp: ProgressBar
var _p1wine: ProgressBar
var _p2hp: ProgressBar
var _p2name: Label
var _p1name: Label
var _loot: Label
var _title: Label
var _banner: Label
var _result: Label
var _hint: Label

var _stage_over: bool = false
var _clear_timer: float = -1.0
var _pending_next: String = ""
var _banner_timer: float = 0.0
var _pickup_timer: float = 0.0
var _dialogue_active: bool = false

# --- 子類可覆寫的設定 ---
func scene_id() -> String:
	return "SCN-00"

func scene_title() -> String:
	return ""

func first_beat() -> String:
	return "B1"

func background_color() -> Color:
	return Color(0.06, 0.06, 0.075)

func background_texture_path() -> String:
	return ""

func opponent_scene_path() -> String:
	return ""

func opponent_display_name() -> String:
	return "伥鬼"

func allow_super_cinematic() -> bool:
	return false

func _ready() -> void:
	_build_world()
	if _cm().current_beat == "" or String(STORY.beat(_cm().current_beat).get("scene", "")) != scene_id():
		_cm().set_beat(first_beat())
	call_deferred("_deferred_start")

func _cm():
	return get_node_or_null("/root/ChapterManager")

func _deferred_start() -> void:
	_on_stage_start()

func _on_stage_start() -> void:
	pass

func _tick_stage(_delta: float) -> void:
	pass

# --- 世界搭建 ---
func _build_world() -> void:
	_build_background()
	_build_ground()
	_build_player()
	_build_opponent()
	_build_camera()
	_build_hud()
	_build_dialogue()

func _build_background() -> void:
	var tex_path: String = background_texture_path()
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.z_index = -2
		bg.size = Vector2(1920, 1080)
		bg.texture = load(tex_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
	else:
		var bg := ColorRect.new()
		bg.name = "Background"
		bg.z_index = -2
		bg.size = Vector2(1920, 1080)
		bg.color = background_color()
		add_child(bg)

func _build_ground() -> void:
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(960, GROUND_Y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 40)
	var col := CollisionShape2D.new()
	col.shape = shape
	ground.add_child(col)
	add_child(ground)
	for side in [-1, 1]:
		var wall := StaticBody2D.new()
		wall.name = "WallLeft" if side < 0 else "WallRight"
		wall.position = Vector2(-20 if side < 0 else 1940, 480)
		var ws := RectangleShape2D.new()
		ws.size = Vector2(40, 1200)
		var wc := CollisionShape2D.new()
		wc.shape = ws
		wall.add_child(wc)
		add_child(wall)

func _build_player() -> void:
	p1 = FIGHTER.instantiate()
	p1.name = "P1"
	p1.position = SPAWN_P1
	add_child(p1)
	if _cm().player_hp > 0:
		p1.current_hp = clampi(_cm().player_hp, 1, p1.max_hp)

func _build_opponent() -> void:
	var path: String = opponent_scene_path()
	if path == "" or not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	p2 = packed.instantiate()
	p2.name = "P2"
	p2.position = SPAWN_P2
	add_child(p2)
	p2.opponent = p1
	p1.opponent = p2

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "BattleCam"
	camera.position = Vector2(960, 540)
	camera.enabled = true
	add_child(camera)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 1
	add_child(hud)

	_p1name = _label("P1Name", Vector2(60, 5), Vector2(300, 20), 18, Color(0.9, 0.88, 0.8))
	_p1name.text = "武松"
	_p1hp = _bar("P1HP", Vector2(60, 30), Vector2(500, 20), 800.0, Color(0.55, 0.24, 0.2))
	_p1hp.value = 800.0
	_p1wine = _bar("P1Wine", Vector2(60, 56), Vector2(320, 12), 100.0, Color(0.75, 0.66, 0.35))
	_p1wine.value = 0.0
	_p1wine.show_percentage = false
	_hint = _label("Hint", Vector2(60, 74), Vector2(420, 18), 13, Color(0.78, 0.76, 0.66))
	_hint.text = "J 輕 / K 重 / L 防 / Space 跳 / U 醉打 / O 覺醒"

	_loot = _label("LootLabel", Vector2(60, 98), Vector2(500, 20), 14, Color(0.78, 0.72, 0.55))
	_title = _label("StageTitle", Vector2(760, 10), Vector2(400, 28), 22, Color(0.85, 0.78, 0.62))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = scene_title()

	_p2hp = _bar("P2HP", Vector2(1360, 30), Vector2(500, 20), 350.0, Color(0.38, 0.44, 0.5))
	_p2name = _label("P2Name", Vector2(1560, 5), Vector2(300, 20), 18, Color(0.85, 0.82, 0.75))
	_p2name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if p2 == null:
		_p2hp.visible = false
		_p2name.visible = false
	else:
		_p2name.text = opponent_display_name()
		_p2hp.max_value = p2.max_hp
		_p2hp.value = p2.current_hp

	_banner = _label("Banner", Vector2(460, 200), Vector2(1000, 44), 30, Color(0.95, 0.86, 0.55))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false

	_result = _label("Result", Vector2(460, 470), Vector2(1000, 64), 48, Color(1, 0.9, 0.3))
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.visible = false

	_refresh_loot()

func _label(node_name: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	hud.add_child(l)
	return l

func _bar(node_name: String, pos: Vector2, size: Vector2, max_v: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.name = node_name
	b.position = pos
	b.size = size
	b.max_value = max_v
	b.value = max_v
	b.show_percentage = false
	b.modulate = color
	hud.add_child(b)
	return b

func _build_dialogue() -> void:
	dialogue = DIALOGUE_SCENE.instantiate()
	add_child(dialogue)

# --- 執行 ---
func _process(delta: float) -> void:
	_tick_overlay(delta)
	if p1 == null:
		return
	_update_hud()
	if _dialogue_active:
		return
	if _stage_over:
		_tick_clear(delta)
		return
	if p1.current_hp <= 0:
		_fail()
		return
	_tick_stage(delta)

func _tick_overlay(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner.visible = false
	if _pickup_timer > 0.0:
		_pickup_timer -= delta
		if _pickup_timer <= 0.0 and _hint != null:
			_hint.text = "J 輕 / K 重 / L 防 / Space 跳 / U 醉打 / O 覺醒"

func _update_hud() -> void:
	if _p1hp != null:
		_p1hp.max_value = p1.max_hp
		_p1hp.value = p1.current_hp
	if _p1wine != null:
		_p1wine.value = p1.wine_gauge
	if p2 != null and _p2hp != null:
		_p2hp.max_value = p2.max_hp
		_p2hp.value = p2.current_hp

func _say(lines: Array, on_done: Callable = Callable()) -> void:
	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_dialogue_active = true
	_freeze_fighters(true)
	dialogue.play(lines, func():
		_dialogue_active = false
		_freeze_fighters(false)
		if on_done.is_valid():
			on_done.call()
	)

func _freeze_fighters(frozen: bool) -> void:
	if p1 != null:
		p1.set_physics_process(not frozen)
	if p2 != null and not p2._death_done:
		p2.set_physics_process(not frozen)

func show_banner(text: String, seconds: float = 2.0) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_timer = seconds

func _finish_to(next_beat: String, delay: float = 1.2, banner_text: String = "前路已清") -> void:
	if _stage_over:
		return
	_stage_over = true
	_pending_next = next_beat
	_clear_timer = delay
	_cm().mark_clear()
	if banner_text != "":
		show_banner(banner_text, delay)
	if p2 != null:
		p2.set_physics_process(false)

func _tick_clear(delta: float) -> void:
	if _clear_timer < 0.0:
		return
	_clear_timer -= delta
	if _clear_timer <= 0.0:
		_clear_timer = -1.0
		if _pending_next == "__checkpoint__":
			_restart_after_death()
		elif _pending_next != "":
			_cm().goto_beat(_pending_next)

func _fail() -> void:
	if _stage_over:
		return
	_stage_over = true
	_result.text = "你敗了…"
	_result.visible = true
	_clear_timer = 2.0
	_pending_next = "__checkpoint__"
	show_banner("", 0.0)

# 死亡後：有檢查點回山神廟，否則重開本場景
func _restart_after_death() -> void:
	if _cm().has_checkpoint():
		_cm().goto_checkpoint()
	else:
		get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if not _stage_over or _pending_next != "__checkpoint__":
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("p1_light"):
		_clear_timer = 0.0

# --- 戰利品與提示 ---
func _on_pickup_collected(item_name: String) -> void:
	_cm().add_loot(item_name, 1)
	_refresh_loot()
	if _hint != null:
		_hint.text = "拾得：%s" % item_name
	_pickup_timer = 2.0

func _refresh_loot() -> void:
	if _loot == null:
		return
	_loot.text = "碎銀 %d　小虎爪 %d　木牌 %d" % [
		int(_cm().loot_counts.get("碎銀", 0)),
		int(_cm().loot_counts.get("小虎爪", 0)),
		int(_cm().loot_counts.get("伥鬼的木牌", 0)),
	]

func _add_opponent(name: String, path: String) -> void:
	# 預留給子類在 _on_stage_start 追加召喚物；Boss 的小虎由 Boss 自己生成
	var packed: PackedScene = load(path)
	var extra = packed.instantiate()
	extra.name = name
	extra.position = Vector2(1500, 820)
	add_child(extra)
	extra.opponent = p1
	extra.set_physics_process(false)
	extra.set_physics_process(true)
