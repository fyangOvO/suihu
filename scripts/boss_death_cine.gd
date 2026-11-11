extends CanvasLayer
## BOS-10 擊殺演出：倒地 → 騎背 → 水潭 → 黑霧 → 字幕。
## 3 秒全屏過場，任意攻擊鍵可跳過；不依賴 Boss 內部狀態，方便主場景換 Boss 時直接接。

signal finished

const DURATION: float = 3.0

var active: bool = false
var elapsed: float = 0.0
var _phase: int = -1
var _built: bool = false
var _dim: ColorRect
var _title: Label
var _sub: Label

const PHASES: Array = [
	[0.0, "虎倒了。"],
	[0.65, "他騎上去，把虎頭按進泥裡。"],
	[1.45, "水潭邊，月亮碎了一片。"],
	[2.10, "黑霧從虎口裡退出來。"],
	[2.65, "那虎氣性自洩了。"],
]

func _ready() -> void:
	if _built:
		return
	_built = true
	layer = 3
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_sub = Label.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_sub.offset_bottom = -110.0
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(0.62, 0.60, 0.55))
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)

func play() -> void:
	if not _built:
		_ready()
	active = true
	visible = true
	elapsed = 0.0
	_phase = -1
	_set_phase(0)
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)

func skip() -> void:
	if not active:
		return
	active = false
	visible = false
	finished.emit()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var t: float = elapsed
	# 0–0.55 淡入；0.55–2.55 保持；2.55–3.0 淡出
	var alpha: float = clampf(t / 0.55, 0.0, 1.0) * (1.0 - clampf((t - 2.55) / 0.45, 0.0, 1.0))
	_dim.color = Color(0.0, 0.0, 0.0, 0.78 * alpha)
	_title.modulate = Color(1.0, 1.0, 1.0, alpha)
	_sub.modulate = Color(1.0, 1.0, 1.0, alpha * 0.8)
	for i in range(PHASES.size() - 1, -1, -1):
		if t >= float(PHASES[i][0]):
			_set_phase(i)
			break
	if t >= DURATION:
		skip()

func _set_phase(index: int) -> void:
	if index == _phase:
		return
	_phase = index
	_title.text = str(PHASES[index][1])
	_sub.text = "（任意攻擊鍵跳過）"

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("p1_light") or event.is_action_pressed("p1_heavy") \
		or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		skip()
