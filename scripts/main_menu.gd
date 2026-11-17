extends Control
## 1.0 Lite 主菜單：開始新局 / 從山神廟檢查點續玩 / 離開。

const STORY := preload("res://data/story_beats.gd")
const FIRST_SCENE := "res://scenes/chapters/SCN_01_Inn.tscn"
const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const SETTINGS := preload("res://scripts/ui/user_settings.gd")
const AUDIO := preload("res://scripts/audio/game_audio.gd")
const PRELOADER := preload("res://scripts/scene_preloader.gd")

@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _panel: Panel = $Panel
@onready var _footer: Label = $Footer
@onready var _btn_new: Button = $Panel/VBox/BtnNew
@onready var _btn_continue: Button = $Panel/VBox/BtnContinue
@onready var _btn_quit: Button = $Panel/VBox/BtnQuit
@onready var _save_hint: Label = $Panel/SaveHint

var _buttons: Array[Button] = []
var _onboard: Panel
var _onboard_mode: Button
var _onboard_mode_value: String = "windowed"
var _onboard_master: HSlider
var _onboard_master_value: Label
var _onboard_deadzone: HSlider
var _onboard_deadzone_value: Label
var _onboard_confirm: Button
var _onboard_controls: Array[Control] = []
var _onboarding: bool = false

func _ready() -> void:
	SETTINGS.apply_display_mode()
	SETTINGS.apply_deadzone()
	AUDIO.play_bgm("bgm_menu")
	# OPT-04：菜單一出來就線程預載第一幕，玩家點「開始新局」時不必再等資源載入
	PRELOADER.request(FIRST_SCENE)
	_buttons = [_btn_new, _btn_continue, _btn_quit]
	_btn_new.pressed.connect(_start_new)
	_btn_continue.pressed.connect(_continue_game)
	_btn_quit.pressed.connect(func(): get_tree().quit())
	for btn in _buttons:
		btn.focus_entered.connect(func(): AUDIO.play_sfx("sfx_ui_move", -11.0))

	UI_STYLE.apply_label(_title, 96, UI_STYLE.PAPER, true)
	UI_STYLE.apply_label(_subtitle, 18, UI_STYLE.PAPER_DIM)
	UI_STYLE.apply_label(_footer, 13, UI_STYLE.GOLD_DIM)
	UI_STYLE.apply_label(_save_hint, 14, UI_STYLE.PAPER_DIM)
	var panel_style: StyleBoxFlat = UI_STYLE.panel_style(0.88)
	panel_style.border_width_left = 3
	panel_style.border_color = Color(UI_STYLE.GOLD.r, UI_STYLE.GOLD.g, UI_STYLE.GOLD.b, 0.68)
	_panel.add_theme_stylebox_override("panel", panel_style)
	UI_STYLE.add_paper(_panel)
	UI_STYLE.add_nine_patch(_panel)
	UI_STYLE.add_corner_marks(_panel, 22.0, 9.0)
	for btn in _buttons:
		UI_STYLE.menu_button_styles(btn)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var cm = get_node_or_null("/root/ChapterManager")
	var state: String = "none" if cm == null else String(cm.checkpoint_state())
	var has_save: bool = state == "ok" or state == "backup"
	_btn_continue.disabled = not has_save
	match state:
		"ok":
			_save_hint.text = "檢查點：山神廟"
		"backup":
			_save_hint.text = "存檔損壞，已備份"
		"corrupt":
			_save_hint.text = "存檔損壞，請開新局"
		_:
			_save_hint.text = "尚無檢查點"

	_build_onboard()
	if SETTINGS.is_first_run():
		_show_onboard()
	else:
		_btn_new.grab_focus()

## 離開菜單時把未完成的預載收乾，避免線程請求懸空到程式退出
func _exit_tree() -> void:
	PRELOADER.settle_pending()

func _unhandled_input(event: InputEvent) -> void:
	if _onboarding:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_move_onboard_focus(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_move_onboard_focus(-1)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()

func _move_focus(dir: int) -> void:
	var current: int = 0
	for i in range(_buttons.size()):
		if _buttons[i].has_focus():
			current = i
			break
	var next_i: int = current
	for _i in range(_buttons.size()):
		next_i = (next_i + dir + _buttons.size()) % _buttons.size()
		if not _buttons[next_i].disabled:
			break
	_buttons[next_i].grab_focus()
	AUDIO.play_sfx("sfx_ui_move", -11.0)

func _start_new() -> void:
	AUDIO.play_sfx("sfx_ui_confirm", -7.0)
	var cm = get_node_or_null("/root/ChapterManager")
	if cm != null:
		cm.start_new_game()
	_switch_scene(FIRST_SCENE)

func _continue_game() -> void:
	AUDIO.play_sfx("sfx_ui_confirm", -7.0)
	var cm = get_node_or_null("/root/ChapterManager")
	if cm == null or not cm.load_checkpoint():
		_save_hint.text = "讀檔失敗"
		return
	var path: String = cm.current_scene_path()
	if path == "":
		return
	_switch_scene(path)

## 預載好了就直接吃現成 PackedScene，沒好（或壞了）退回同步載入
func _switch_scene(path: String) -> void:
	var packed: PackedScene = PRELOADER.ready_scene(path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)

# --- 首次啟動引導（TUT-02）：顯示模式、主音量、手柄死區，一次設置成功 ---

func _build_onboard() -> void:
	_onboard = Panel.new()
	_onboard.name = "OnboardPanel"
	_onboard.position = Vector2(600, 240)
	_onboard.size = Vector2(720, 600)
	_onboard.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.94))
	_onboard.visible = false
	add_child(_onboard)
	UI_STYLE.add_paper(_onboard, 0.045)
	UI_STYLE.add_nine_patch(_onboard, 0.42)
	UI_STYLE.add_corner_marks(_onboard, 22.0, 8.0, 2.0)

	_onboard_label("OnboardTitle", "初次進山", Vector2(60, 20), Vector2(500, 70), 52, UI_STYLE.PAPER, true)
	_onboard_label("OnboardSubtitle", "先把畫面和手感調順；之後可在暫停 → 設置再改。", Vector2(64, 92), Vector2(590, 24), 16, UI_STYLE.PAPER_DIM)
	var rule := UI_STYLE.text_rule(592.0)
	rule.name = "OnboardRule"
	rule.position = Vector2(64, 130)
	_onboard.add_child(rule)

	_onboard_mode_value = SETTINGS.load_display_mode()
	_onboard_mode = _onboard_button("OnboardMode", _onboard_mode_text(), 150, _toggle_onboard_display, "screen")

	_onboard_label("OnboardAudioSection", "主音量", Vector2(64, 220), Vector2(590, 20), 13, UI_STYLE.GOLD_DIM)
	var audio_rule := UI_STYLE.text_rule(592.0)
	audio_rule.name = "OnboardAudioRule"
	audio_rule.position = Vector2(64, 244)
	_onboard.add_child(audio_rule)
	_onboard_master = _onboard_slider("OnboardMaster", 258.0, 1.0, roundf(AUDIO.get_volume("master") * 100.0))
	_onboard_label("OnboardMasterLabel", "音量", Vector2(64, 263.0), Vector2(104, 24), 19, UI_STYLE.PAPER)
	_onboard_master_value = _onboard_label("OnboardMasterValue", "%d" % int(_onboard_master.value), Vector2(514, 262.0), Vector2(64, 24), 18, UI_STYLE.GOLD_DIM)
	_onboard_master_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_onboard_master.value_changed.connect(_on_master_changed)

	_onboard_label("OnboardInputSection", "手柄死區", Vector2(64, 306), Vector2(590, 20), 13, UI_STYLE.GOLD_DIM)
	var input_rule := UI_STYLE.text_rule(592.0)
	input_rule.name = "OnboardInputRule"
	input_rule.position = Vector2(64, 330)
	_onboard.add_child(input_rule)
	_onboard_deadzone = _onboard_slider("OnboardDeadzone", 344.0, 5.0, roundf(SETTINGS.load_deadzone() * 100.0))
	_onboard_label("OnboardDeadzoneLabel", "死區", Vector2(64, 349.0), Vector2(104, 24), 19, UI_STYLE.PAPER)
	_onboard_deadzone_value = _onboard_label("OnboardDeadzoneValue", "%d" % int(_onboard_deadzone.value), Vector2(514, 348.0), Vector2(64, 24), 18, UI_STYLE.GOLD_DIM)
	_onboard_deadzone_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_onboard_deadzone.value_changed.connect(_on_deadzone_changed)
	_onboard_label("OnboardInputHint", "死區越大，搖桿要推得更多才算方向；鍵盤操作不受影響。", Vector2(64, 396), Vector2(590, 24), 13, UI_STYLE.PAPER_DIM)

	_onboard_confirm = _onboard_button("OnboardConfirm", "進山", 448, _onboard_confirm_pressed, "play")
	_onboard_label("OnboardHint", "確認後記住這組設定，本頁不再出現。", Vector2(64, 518), Vector2(590, 24), 13, UI_STYLE.PAPER_DIM)

	_onboard_controls = [_onboard_mode, _onboard_master, _onboard_deadzone, _onboard_confirm]
	_link_onboard_focus()

func _onboard_label(node_name: String, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.position = pos
	l.size = size
	UI_STYLE.apply_label(l, font_size, color, title)
	_onboard.add_child(l)
	return l

func _onboard_button(node_name: String, text: String, y: float, callback: Callable, icon_kind: String = "") -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.position = Vector2(64, y)
	b.size = Vector2(592, 54)
	UI_STYLE.menu_button_styles(b, icon_kind)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): AUDIO.play_sfx("sfx_ui_confirm", -7.0))
	b.focus_entered.connect(func(): AUDIO.play_sfx("sfx_ui_move", -11.0))
	b.pressed.connect(callback)
	_onboard.add_child(b)
	return b

func _onboard_slider(node_name: String, y: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.position = Vector2(172, y)
	slider.size = Vector2(330, 26)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = value
	UI_STYLE.style_slider(slider)
	_onboard.add_child(slider)
	return slider

func _link_onboard_focus() -> void:
	var count: int = _onboard_controls.size()
	if count < 2:
		return
	for i in range(count):
		var c: Control = _onboard_controls[i]
		var next: Control = _onboard_controls[(i + 1) % count]
		var prev: Control = _onboard_controls[(i - 1 + count) % count]
		c.focus_next = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_left = c.get_path_to(next)
		c.focus_neighbor_right = c.get_path_to(prev)

func _onboard_mode_text() -> String:
	return "顯示：全屏" if _onboard_mode_value == "fullscreen" else "顯示：視窗"

func _toggle_onboard_display() -> void:
	_onboard_mode_value = "windowed" if _onboard_mode_value == "fullscreen" else "fullscreen"
	_onboard_mode.text = _onboard_mode_text()
	SETTINGS.apply_display_mode(_onboard_mode_value)

func _on_master_changed(value: float) -> void:
	AUDIO.set_volume("master", clampf(value / 100.0, 0.0, 1.0))
	if _onboard_master_value != null:
		_onboard_master_value.text = "%d" % int(round(value))

func _on_deadzone_changed(value: float) -> void:
	if _onboard_deadzone_value != null:
		_onboard_deadzone_value.text = "%d" % int(round(value))

func _show_onboard() -> void:
	if _onboard == null:
		return
	_onboarding = true
	_panel.visible = false
	_onboard_mode_value = SETTINGS.load_display_mode()
	_onboard_mode.text = _onboard_mode_text()
	_onboard_master.set_value_no_signal(roundf(AUDIO.get_volume("master") * 100.0))
	if _onboard_master_value != null:
		_onboard_master_value.text = "%d" % int(round(_onboard_master.value))
	_onboard_deadzone.set_value_no_signal(roundf(SETTINGS.load_deadzone() * 100.0))
	if _onboard_deadzone_value != null:
		_onboard_deadzone_value.text = "%d" % int(round(_onboard_deadzone.value))
	_onboard.visible = true
	_onboard_mode.grab_focus()

func _onboard_confirm_pressed() -> void:
	SETTINGS.save_display_mode(_onboard_mode_value)
	SETTINGS.apply_display_mode(_onboard_mode_value)
	SETTINGS.save_volume("master", clampf(_onboard_master.value / 100.0, 0.0, 1.0))
	var deadzone: float = clampf(_onboard_deadzone.value / 100.0, 0.0, 1.0)
	SETTINGS.save_deadzone(deadzone)
	SETTINGS.apply_deadzone(deadzone)
	SETTINGS.mark_onboarded()
	_onboarding = false
	_onboard.visible = false
	_panel.visible = true
	_btn_new.grab_focus()

func _move_onboard_focus(dir: int) -> void:
	if _onboard_controls.is_empty():
		return
	var current: int = 0
	for i in range(_onboard_controls.size()):
		if _onboard_controls[i].has_focus():
			current = i
			break
	var next: int = (current + dir + _onboard_controls.size()) % _onboard_controls.size()
	_onboard_controls[next].grab_focus()
	AUDIO.play_sfx("sfx_ui_move", -11.0)

func is_onboarding() -> bool:
	return _onboarding
