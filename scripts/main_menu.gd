extends Control
## 1.0 Lite 主菜單：開始新局 / 從山神廟檢查點續玩 / 離開。

const STORY := preload("res://data/story_beats.gd")
const FIRST_SCENE := "res://scenes/chapters/SCN_01_Inn.tscn"
const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _panel: Panel = $Panel
@onready var _footer: Label = $Footer
@onready var _btn_new: Button = $Panel/VBox/BtnNew
@onready var _btn_continue: Button = $Panel/VBox/BtnContinue
@onready var _btn_quit: Button = $Panel/VBox/BtnQuit
@onready var _save_hint: Label = $Panel/SaveHint

var _buttons: Array[Button] = []

func _ready() -> void:
	_buttons = [_btn_new, _btn_continue, _btn_quit]
	_btn_new.pressed.connect(_start_new)
	_btn_continue.pressed.connect(_continue_game)
	_btn_quit.pressed.connect(func(): get_tree().quit())

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
	var has_save: bool = cm != null and cm.has_checkpoint()
	_btn_continue.disabled = not has_save
	_save_hint.text = "檢查點：山神廟" if has_save else "尚無檢查點"
	_btn_new.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
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

func _start_new() -> void:
	var cm = get_node_or_null("/root/ChapterManager")
	if cm != null:
		cm.start_new_game()
	get_tree().change_scene_to_file(FIRST_SCENE)

func _continue_game() -> void:
	var cm = get_node_or_null("/root/ChapterManager")
	if cm == null or not cm.load_checkpoint():
		_save_hint.text = "讀檔失敗"
		return
	var path: String = cm.current_scene_path()
	if path == "":
		return
	get_tree().change_scene_to_file(path)
