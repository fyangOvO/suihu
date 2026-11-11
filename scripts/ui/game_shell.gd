extends CanvasLayer
## 1.0 Lite 共用遊戲殼層：暫停、設置、死亡重開、章末結算。
## 只由章節場景掛載；暫停時以 PROCESS_MODE_ALWAYS 保持按鈕可操作。

signal retry_requested
signal checkpoint_requested
signal menu_requested
signal new_game_requested

const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

var _dim: ColorRect
var _root: Control
var _pause: Panel
var _settings: Panel
var _death: Panel
var _summary: Panel
var _pause_btn: Button
var _settings_btn: Button
var _settings_mode: Button
var _death_retry: Button
var _death_checkpoint: Button
var _summary_new: Button
var _summary_stats: Label
var _death_hint: Label
var _page: String = ""

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	_dim = ColorRect.new()
	_dim.name = "ShellDim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.008, 0.008, 0.010, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

	_root = Control.new()
	_root.name = "ShellRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	add_child(_root)

	_build_pause()
	_build_settings()
	_build_death()
	_build_summary()

func _panel(node_name: String, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.name = node_name
	p.position = pos
	p.size = size
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.add_theme_stylebox_override("panel", UI_STYLE.panel_style(0.93))
	UI_STYLE.add_paper(p)
	UI_STYLE.add_corner_marks(p)
	_root.add_child(p)
	p.visible = false
	return p

func _label(parent: Control, node_name: String, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.position = pos
	l.size = size
	UI_STYLE.apply_label(l, font_size, color, title)
	parent.add_child(l)
	return l

func _button(parent: Control, node_name: String, text: String, y: float, callback: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.position = Vector2(64, y)
	b.size = Vector2(592, 54)
	UI_STYLE.menu_button_styles(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_pause() -> void:
	_pause = _panel("PausePanel", Vector2(600, 250), Vector2(720, 560))
	_label(_pause, "PauseTitle", "暫停", Vector2(60, 24), Vector2(500, 70), 56, UI_STYLE.PAPER, true)
	_label(_pause, "PauseSubtitle", "酒還溫著。", Vector2(64, 96), Vector2(500, 24), 16, UI_STYLE.PAPER_DIM)
	_pause_btn = _button(_pause, "PauseResume", "繼續", 166, _on_resume)
	_settings_btn = _button(_pause, "PauseSettings", "設置", 232, _on_settings)
	_button(_pause, "PauseMenu", "回到主菜單", 298, _on_menu)
	_button(_pause, "PauseQuit", "離開遊戲", 364, _on_quit)
	_label(_pause, "PauseHint", "Esc 返回遊戲　·　手柄 Start 可呼出", Vector2(64, 508), Vector2(590, 22), 13, UI_STYLE.PAPER_DIM)

func _build_settings() -> void:
	_settings = _panel("SettingsPanel", Vector2(600, 270), Vector2(720, 520))
	_label(_settings, "SettingsTitle", "設置", Vector2(60, 24), Vector2(500, 70), 56, UI_STYLE.PAPER, true)
	_label(_settings, "SettingsSubtitle", "先把畫面調順，再談別的。", Vector2(64, 96), Vector2(590, 24), 16, UI_STYLE.PAPER_DIM)
	_settings_mode = _button(_settings, "SettingsMode", "顯示：全屏", 174, _toggle_display)
	_settings_mode.size = Vector2(592, 58)
	_button(_settings, "SettingsBack", "返回暫停", 254, _on_settings_back)
	_label(_settings, "SettingsHint", "音量、手柄死區、打擊停頓等項待音頻／輸入批次接入；本輪只落顯示模式。", Vector2(64, 340), Vector2(590, 50), 13, UI_STYLE.PAPER_DIM)

func _build_death() -> void:
	_death = _panel("DeathPanel", Vector2(540, 290), Vector2(840, 500))
	_label(_death, "DeathTitle", "倒下了", Vector2(60, 26), Vector2(700, 90), 72, UI_STYLE.BLOOD_LIGHT, true)
	_label(_death, "DeathSubtitle", "景陽岡不等人。", Vector2(64, 120), Vector2(700, 26), 16, UI_STYLE.PAPER_DIM)
	_death_hint = _label(_death, "DeathHint", "檢查點：山神廟", Vector2(64, 164), Vector2(700, 24), 15, UI_STYLE.GOLD_DIM)
	_death_retry = _button(_death, "DeathRetry", "重試本段", 206, _on_death_retry)
	_death_checkpoint = _button(_death, "DeathCheckpoint", "回山神廟", 272, _on_death_checkpoint)
	_button(_death, "DeathMenu", "回到主菜單", 338, _on_menu)
	_label(_death, "DeathHintBottom", "重試會從本場景起點重來；回山神廟會讀最近檢查點。", Vector2(64, 432), Vector2(720, 24), 13, UI_STYLE.PAPER_DIM)

func _build_summary() -> void:
	_summary = _panel("SummaryPanel", Vector2(480, 220), Vector2(960, 620))
	_label(_summary, "SummaryTitle", "章末 · 景陽岡", Vector2(60, 26), Vector2(840, 72), 52, UI_STYLE.PAPER, true)
	_label(_summary, "SummarySubtitle", "下山。", Vector2(64, 104), Vector2(840, 30), 18, UI_STYLE.PAPER_DIM)
	_label(_summary, "SummaryRule", "", Vector2(64, 160), Vector2(832, 30), 1, UI_STYLE.GOLD)
	_summary_stats = _label(_summary, "SummaryStats", "", Vector2(64, 190), Vector2(832, 230), 22, UI_STYLE.PAPER)
	_summary_stats.add_theme_constant_override("line_spacing", 12)
	_summary_new = _button(_summary, "SummaryNew", "重新開始", 454, _on_summary_new)
	_button(_summary, "SummaryMenu", "回到主菜單", 520, _on_menu)
	_label(_summary, "SummaryHint", "景陽岡沒有虎了。但武松的影子，從此是四隻。", Vector2(64, 580), Vector2(832, 24), 14, UI_STYLE.GOLD_DIM)

func _show_panel(panel: Panel, page: String, focus: Control) -> void:
	_page = page
	_pause.visible = false
	_settings.visible = false
	_death.visible = false
	_summary.visible = false
	panel.visible = true
	_root.visible = true
	_dim.visible = true
	get_tree().paused = true
	if focus != null:
		focus.grab_focus()

func _close_all(resume: bool = true) -> void:
	_page = ""
	_root.visible = false
	_dim.visible = false
	if resume:
		get_tree().paused = false

func show_pause() -> void:
	_show_panel(_pause, "pause", _pause_btn)

func show_death(has_checkpoint: bool) -> void:
	_death_hint.text = "檢查點：山神廟" if has_checkpoint else "尚無檢查點，只能重試本段"
	_death_checkpoint.disabled = not has_checkpoint
	_show_panel(_death, "death", _death_retry)

func show_summary(stats: Dictionary) -> void:
	var silver: int = int(stats.get("碎銀", 0))
	var claw: int = int(stats.get("小虎爪", 0))
	var tag: int = int(stats.get("伥鬼的木牌", 0))
	_summary_stats.text = "碎銀　%d\n小虎爪　%d\n伥鬼木牌　%d\n\n章節　B1 — B9　完成\n景陽岡　猛虎已伏" % [silver, claw, tag]
	_show_panel(_summary, "summary", _summary_new)

func current_page() -> String:
	return _page

func is_open() -> bool:
	return _page != ""

func _on_resume() -> void:
	_close_all(true)

func _on_settings() -> void:
	_pause.visible = false
	_settings.visible = true
	_page = "settings"
	_update_mode_text()
	_settings_mode.grab_focus()

func _on_settings_back() -> void:
	_settings.visible = false
	_pause.visible = true
	_page = "pause"
	_settings_btn.grab_focus()

func _toggle_display() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_mode_text()

func _update_mode_text() -> void:
	_settings_mode.text = "顯示：全屏" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "顯示：視窗"

func _on_death_retry() -> void:
	_close_all(true)
	retry_requested.emit()

func _on_death_checkpoint() -> void:
	if _death_checkpoint.disabled:
		return
	_close_all(true)
	checkpoint_requested.emit()

func _on_summary_new() -> void:
	_close_all(true)
	new_game_requested.emit()

func _on_menu() -> void:
	_close_all(true)
	menu_requested.emit()

func _on_quit() -> void:
	_close_all(true)
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _page == "settings":
		_on_settings_back()
		get_viewport().set_input_as_handled()
	elif _page == "pause":
		_on_resume()
		get_viewport().set_input_as_handled()
