extends Node2D
## 六場景共用骨架：背景／地面／牆／武松／可選敵人／HUD／對話／勝敗切換。
## 子類只覆寫 scene_id、title、背景、敵人與 _on_stage_start/_tick_stage。

const FIGHTER := preload("res://scenes/RiggedFighter.tscn")
const DIALOGUE_SCENE := preload("res://scenes/ui/DialogueUI.tscn")
const GAME_SHELL := preload("res://scripts/ui/game_shell.gd")
const STORY := preload("res://data/story_beats.gd")
const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

const GROUND_Y: float = 870.0
const SPAWN_P1 := Vector2(600.0, 820.0)
const SPAWN_P2 := Vector2(1320.0, 820.0)

var p1: CharacterBody2D
var p2: CharacterBody2D = null
var camera: Camera2D
var dialogue: CanvasLayer
var hud: CanvasLayer
var _p1_panel: Panel
var _p1hp: ProgressBar
var _p1wine: ProgressBar
var _p1hp_text: Label
var _p1hp_overlay: Control
var _p2hp: ProgressBar
var _p2hp_text: Label
var _p2hp_overlay: Control
var _p2_panel: Panel
var _p2_ticks: Control
var _boss_panel: Panel
var _boss_hp: ProgressBar
var _boss_hp_text: Label
var _boss_phase: Label
var _boss_ticks: Control
var _boss_phase_pips: Array[ColorRect] = []
var _banner_tag: Label
var _boss_overlay: Control
var _is_boss: bool = false
var _shell: CanvasLayer
var _banner_panel: Panel
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
	_build_shell()

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

	_p1_panel = Panel.new()
	_p1_panel.name = "P1Panel"
	_p1_panel.position = Vector2(34, 26)
	_p1_panel.size = Vector2(430, 128)
	_p1_panel.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.84))
	hud.add_child(_p1_panel)
	UI_STYLE.add_paper(_p1_panel)
	UI_STYLE.add_nine_patch(_p1_panel)
	UI_STYLE.add_corner_marks(_p1_panel, 16.0, 6.0)

	_p1name = _label("P1Name", Vector2(54, 32), Vector2(260, 36), 28, UI_STYLE.PAPER, true)
	_p1name.text = "武松"

	var p1_hp_tag := _label("P1HPTag", Vector2(54, 62), Vector2(110, 18), 12, UI_STYLE.PAPER_DIM)
	p1_hp_tag.text = "氣血"
	_p1hp_text = _label("P1HPText", Vector2(318, 61), Vector2(108, 18), 13, UI_STYLE.PAPER_DIM)
	_p1hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p1hp_text.text = "800 / 800"

	_p1hp = _bar("P1HP", Vector2(54, 80), Vector2(372, 16), 800.0, UI_STYLE.BLOOD)
	_p1hp.value = 800.0
	_add_hp_icon(Vector2(8, 54), UI_STYLE.BLOOD_LIGHT, _p1_panel)
	_p1hp_overlay = _add_hp_overlay(_p1hp, UI_STYLE.BLOOD_LIGHT)
	_add_bar_ticks(_p1hp, 8)

	_p1wine = _bar("P1Wine", Vector2(54, 106), Vector2(250, 8), 100.0, UI_STYLE.GOLD)
	_p1wine.value = 0.0
	_p1wine.show_percentage = false
	_add_bar_ticks(_p1wine, 4)

	_hint = _label("Hint", Vector2(52, 956), Vector2(620, 20), 14, UI_STYLE.PAPER_DIM)
	_hint.text = "J 輕 / K 重 / L 防 / Space 跳 / U 醉打 / O 覺醒"

	_loot = _label("LootLabel", Vector2(52, 930), Vector2(620, 20), 15, UI_STYLE.GOLD_DIM)
	_loot.text = ""

	_title = _label("StageTitle", Vector2(660, 12), Vector2(600, 42), 32, UI_STYLE.PAPER, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = scene_title()

	var title_rule := ColorRect.new()
	title_rule.name = "TitleRule"
	title_rule.position = Vector2(820, 56)
	title_rule.size = Vector2(280, 1)
	title_rule.color = Color(UI_STYLE.GOLD_DIM.r, UI_STYLE.GOLD_DIM.g, UI_STYLE.GOLD_DIM.b, 0.45)
	hud.add_child(title_rule)

	_p2_panel = Panel.new()
	_p2_panel.name = "P2Panel"
	_p2_panel.position = Vector2(1456, 26)
	_p2_panel.size = Vector2(430, 128)
	_p2_panel.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.80, UI_STYLE.STEEL))
	hud.add_child(_p2_panel)
	UI_STYLE.add_paper(_p2_panel)
	UI_STYLE.add_nine_patch(_p2_panel)
	UI_STYLE.add_corner_marks(_p2_panel, 16.0, 6.0)

	_p2name = _label("P2Name", Vector2(1494, 32), Vector2(352, 36), 28, UI_STYLE.PAPER, true)
	_p2name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var p2_hp_tag := _label("P2HPTag", Vector2(1474, 62), Vector2(110, 18), 12, UI_STYLE.PAPER_DIM)
	p2_hp_tag.text = "氣血"
	_p2hp_text = _label("P2HPText", Vector2(1738, 61), Vector2(108, 18), 13, UI_STYLE.PAPER_DIM)
	_p2hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2hp_text.text = "350 / 350"

	_p2hp = _bar("P2HP", Vector2(1474, 80), Vector2(372, 16), 350.0, UI_STYLE.STEEL)
	_add_hp_icon(Vector2(6, 54), UI_STYLE.STEEL, _p2_panel)
	_p2hp_overlay = _add_hp_overlay(_p2hp, UI_STYLE.STEEL)
	_p2_ticks = _add_bar_ticks(_p2hp, 8)
	var p2_rule := ColorRect.new()
	p2_rule.name = "P2Rule"
	p2_rule.position = Vector2(18, 84)
	p2_rule.size = Vector2(372, 1)
	p2_rule.color = Color(UI_STYLE.STEEL.r, UI_STYLE.STEEL.g, UI_STYLE.STEEL.b, 0.42)
	_p2_panel.add_child(p2_rule)

	if p2 == null:
		_p2hp.visible = false
		_p2hp_text.visible = false
		_p2name.visible = false
		_p2_panel.visible = false
		_p2_ticks.visible = false
		_p2hp_overlay.visible = false
	else:
		_p2name.text = opponent_display_name()
		_p2hp.max_value = p2.max_hp
		_p2hp.value = p2.current_hp
		_p2hp_text.text = "%d / %d" % [int(p2.current_hp), int(p2.max_hp)]

	_is_boss = p2 != null and p2.has_method("_boss_boot")
	if _is_boss:
		_p2hp.visible = false
		_p2hp_text.visible = false
		_p2name.visible = false
		_p2_panel.visible = false
		_p2_ticks.visible = false
		_p2hp_overlay.visible = false
		_boss_panel = Panel.new()
		_boss_panel.name = "BossPanel"
		_boss_panel.position = Vector2(480, 64)
		_boss_panel.size = Vector2(960, 92)
		_boss_panel.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.90))
		hud.add_child(_boss_panel)
		UI_STYLE.add_paper(_boss_panel)
		UI_STYLE.add_nine_patch(_boss_panel)
		UI_STYLE.add_corner_marks(_boss_panel, 20.0, 7.0)
		_label("BossName", Vector2(504, 70), Vector2(640, 38), 30, UI_STYLE.PAPER, true).text = opponent_display_name()
		_boss_phase = _label("BossPhase", Vector2(1296, 70), Vector2(120, 24), 14, UI_STYLE.BLOOD_LIGHT)
		_boss_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_boss_phase.text = "一階段"
		_label("BossTag", Vector2(504, 101), Vector2(240, 18), 12, UI_STYLE.GOLD_DIM).text = "虎威"
		_boss_hp_text = _label("BossHPText", Vector2(1336, 99), Vector2(80, 18), 13, UI_STYLE.PAPER_DIM)
		_boss_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_boss_hp_text.text = "%d / %d" % [int(p2.current_hp), int(p2.max_hp)]
		for i in range(3):
			var pip := ColorRect.new()
			pip.name = "BossPhasePip%d" % i
			pip.position = Vector2(1296.0 + float(i) * 14.0, 102.0)
			pip.size = Vector2(7, 7)
			pip.rotation = PI * 0.25
			pip.color = Color(UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b, 0.2)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud.add_child(pip)
			_boss_phase_pips.append(pip)
		_boss_hp = _bar("BossHP", Vector2(504, 124), Vector2(912, 16), p2.max_hp, UI_STYLE.BLOOD)
		_add_hp_icon(Vector2(14, 58), UI_STYLE.BLOOD_LIGHT, _boss_panel)
		_boss_overlay = _add_hp_overlay(_boss_hp, UI_STYLE.BLOOD_LIGHT)
		_boss_ticks = _add_bar_ticks(_boss_hp, 3)

	_banner_panel = Panel.new()
	_banner_panel.name = "BannerPanel"
	_banner_panel.position = Vector2(480, 176)
	_banner_panel.size = Vector2(960, 64)
	_banner_panel.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.82))
	_banner_panel.visible = false
	hud.add_child(_banner_panel)
	UI_STYLE.add_paper(_banner_panel, 0.035)
	UI_STYLE.add_corner_marks(_banner_panel, 14.0, 5.0)

	var banner_top := ColorRect.new()
	banner_top.name = "BannerRuleTop"
	banner_top.position = Vector2(0, 0)
	banner_top.size = Vector2(960, 1)
	banner_top.color = Color(UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b, 0.55)
	_banner_panel.add_child(banner_top)
	var banner_bottom := ColorRect.new()
	banner_bottom.name = "BannerRuleBottom"
	banner_bottom.position = Vector2(0, 63)
	banner_bottom.size = Vector2(960, 1)
	banner_bottom.color = Color(UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b, 0.45)
	_banner_panel.add_child(banner_bottom)

	_banner = _label("Banner", Vector2(500, 184), Vector2(920, 48), 30, UI_STYLE.GOLD, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	_banner_tag = _label("BannerTag", Vector2(504, 190), Vector2(92, 28), 15, UI_STYLE.GOLD_DIM)
	_banner_tag.visible = false

	_result = _label("Result", Vector2(360, 452), Vector2(1200, 80), 56, UI_STYLE.GOLD, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.visible = false

	_refresh_loot()

func _label(node_name: String, pos: Vector2, size: Vector2, font_size: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.position = pos
	l.size = size
	UI_STYLE.apply_label(l, font_size, color, title)
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
	UI_STYLE.apply_bar(b, color)
	hud.add_child(b)
	return b

func _add_hp_icon(pos: Vector2, color: Color, parent: Control = null) -> ColorRect:
	var icon := ColorRect.new()
	icon.name = "HPIcon"
	icon.position = pos
	icon.size = Vector2(6, 16)
	icon.color = Color(color.r, color.g, color.b, 0.9)
	var host: Node = hud if parent == null else parent
	host.add_child(icon)
	return icon

func _add_hp_overlay(bar: ProgressBar, color: Color) -> Control:
	var root := Control.new()
	root.name = bar.name + "Overlay"
	root.position = bar.position
	root.size = bar.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var shine := ColorRect.new()
	shine.name = "Shine"
	shine.position = Vector2(1, 1)
	shine.size = Vector2(bar.size.x - 2, 2)
	shine.color = Color(1, 0.78, 0.62, 0.14)
	root.add_child(shine)

	var cap := ColorRect.new()
	cap.name = "Cap"
	cap.position = Vector2(bar.size.x - 3, 1)
	cap.size = Vector2(2, bar.size.y - 2)
	cap.color = Color(color.r, color.g, color.b, 0.9)
	root.add_child(cap)
	return root

func _update_hp_overlay(bar: ProgressBar, overlay: Control, max_v: float, value: float) -> void:
	if overlay == null or bar == null:
		return
	var ratio: float = clampf(value / maxf(max_v, 1.0), 0.0, 1.0)
	var shine := overlay.get_node_or_null("Shine") as ColorRect
	if shine != null:
		shine.size.x = maxf(0.0, bar.size.x * ratio - 2.0)
	var cap := overlay.get_node_or_null("Cap") as ColorRect
	if cap != null:
		cap.position.x = maxf(1.0, bar.size.x * ratio - 2.0)

func _add_bar_ticks(bar: ProgressBar, divisions: int) -> Control:
	var root := Control.new()
	root.name = bar.name + "Ticks"
	root.position = bar.position
	root.size = bar.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var shine := ColorRect.new()
	shine.position = Vector2(1, 1)
	shine.size = Vector2(bar.size.x - 2, 1)
	shine.color = Color(1, 0.78, 0.62, 0.13)
	root.add_child(shine)

	for i in range(1, divisions):
		var tick := ColorRect.new()
		tick.position = Vector2(bar.size.x * float(i) / float(divisions), 2)
		tick.size = Vector2(1, bar.size.y - 4)
		tick.color = Color(UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b, 0.16)
		root.add_child(tick)
	return root

func _build_dialogue() -> void:
	dialogue = DIALOGUE_SCENE.instantiate()
	add_child(dialogue)

func _build_shell() -> void:
	_shell = GAME_SHELL.new()
	_shell.name = "GameShell"
	add_child(_shell)
	_shell.retry_requested.connect(_on_shell_retry)
	_shell.checkpoint_requested.connect(_on_shell_checkpoint)
	_shell.menu_requested.connect(_on_shell_menu)
	_shell.new_game_requested.connect(_on_shell_new_game)

func _on_shell_retry() -> void:
	get_tree().reload_current_scene()

func _on_shell_checkpoint() -> void:
	if _cm().goto_checkpoint():
		return
	get_tree().reload_current_scene()

func _on_shell_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_shell_new_game() -> void:
	_cm().start_new_game()
	get_tree().change_scene_to_file("res://scenes/chapters/SCN_01_Inn.tscn")

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
			if _banner != null:
				_banner.visible = false
			if _banner_panel != null:
				_banner_panel.visible = false
			if _banner_tag != null:
				_banner_tag.visible = false
	if _pickup_timer > 0.0:
		_pickup_timer -= delta
		if _pickup_timer <= 0.0 and _hint != null:
			_hint.text = "J 輕 / K 重 / L 防 / Space 跳 / U 醉打 / O 覺醒"

func _update_hud() -> void:
	if _p1hp != null:
		_p1hp.max_value = p1.max_hp
		_p1hp.value = p1.current_hp
		if _p1hp_text != null:
			_p1hp_text.text = "%d / %d" % [int(p1.current_hp), int(p1.max_hp)]
		_update_hp_overlay(_p1hp, _p1hp_overlay, p1.max_hp, p1.current_hp)
	if _p1wine != null:
		_p1wine.value = p1.wine_gauge
	if p2 != null and _p2hp != null:
		_p2hp.max_value = p2.max_hp
		_p2hp.value = p2.current_hp
		if _p2hp_text != null:
			_p2hp_text.text = "%d / %d" % [int(p2.current_hp), int(p2.max_hp)]
		_update_hp_overlay(_p2hp, _p2hp_overlay, p2.max_hp, p2.current_hp)
	if _is_boss and _boss_hp != null:
		_boss_hp.max_value = p2.max_hp
		_boss_hp.value = p2.current_hp
		if _boss_hp_text != null:
			_boss_hp_text.text = "%d / %d" % [int(p2.current_hp), int(p2.max_hp)]
		if _boss_phase != null:
			var phase_index: int = clampi(int(p2.boss_phase), 1, 3)
			_boss_phase.text = ["一階段", "二階段", "三階段"][phase_index - 1]
			for i in range(_boss_phase_pips.size()):
				var lit: bool = i < phase_index
				_boss_phase_pips[i].color = Color(
					UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b,
					0.86 if lit else 0.16
				)
		_update_hp_overlay(_boss_hp, _boss_overlay, p2.max_hp, p2.current_hp)

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

func show_banner(text: String, seconds: float = 2.0, tag: String = "") -> void:
	if text.strip_edges() == "" or seconds <= 0.0:
		_banner.visible = false
		_banner_panel.visible = false
		if _banner_tag != null:
			_banner_tag.visible = false
		_banner_timer = 0.0
		return
	_banner.text = text
	_banner.visible = true
	_banner_panel.visible = true
	if _banner_tag != null:
		_banner_tag.text = tag
		_banner_tag.visible = tag != ""
	if tag != "":
		_banner.position = Vector2(600, 184)
		_banner.size = Vector2(820, 48)
		_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_theme_font_size_override("font_size", 28)
	else:
		_banner.position = Vector2(500, 184)
		_banner.size = Vector2(920, 48)
		_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_theme_font_size_override("font_size", 30)
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
	_result.visible = false
	show_banner("", 0.0)
	if _shell != null:
		_shell.show_death(_cm().has_checkpoint())

# 死亡後：有檢查點回山神廟，否則重開本場景
func _restart_after_death() -> void:
	if _cm().has_checkpoint():
		_cm().goto_checkpoint()
	else:
		get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
		if _shell != null and _shell.is_open():
			if _shell.handle_cancel():
				get_viewport().set_input_as_handled()
			return
		if not _stage_over:
			if _shell != null:
				_shell.show_pause()
				get_viewport().set_input_as_handled()
		return
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
