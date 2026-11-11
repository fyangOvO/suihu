extends CanvasLayer
## FLOW-02：逐字對話框。一次只播一行，打字中按鍵先補滿，再按下一句。
## 對話期間由場景凍結玩家；本節點只負責顯示與接收確認鍵。

signal finished

const CHARS_PER_SECOND: float = 34.0
const UI_STYLE := preload("res://scripts/ui/ui_style.gd")

var _lines: Array = []
var _index: int = -1
var _typing: bool = false
var _chars: float = 0.0
var _active: bool = false
var _callback: Callable = Callable()

@onready var _name: Label = $Box/Name
@onready var _text: Label = $Box/Text
@onready var _hint: Label = $Box/Hint

func _ready() -> void:
	visible = false
	set_process(false)
	UI_STYLE.apply_label(_name, 30, UI_STYLE.GOLD, true)
	UI_STYLE.apply_label(_text, 28, UI_STYLE.PAPER)
	UI_STYLE.apply_label(_hint, 14, UI_STYLE.PAPER_DIM)

func play(lines: Array, on_finished: Callable = Callable()) -> void:
	_lines = lines.duplicate(true)
	_index = -1
	_callback = on_finished
	_active = true
	visible = true
	set_process(true)
	_advance_line()

func _advance_line() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
		return
	_start_line(_lines[_index])

func is_active() -> bool:
	return _active

func current_text() -> String:
	return _text.text if _text != null else ""

func current_speaker() -> String:
	return _name.text if _name != null else ""

func next() -> void:
	if not _active:
		return
	if _typing:
		_finish_typing()
		return
	_advance_line()

func close() -> void:
	if not _active:
		return
	_active = false
	_typing = false
	visible = false
	set_process(false)
	var cb: Callable = _callback
	_callback = Callable()
	if cb.is_valid():
		cb.call()

func _start_line(line) -> void:
	var speaker: String = ""
	var body: String = ""
	if typeof(line) == TYPE_DICTIONARY:
		speaker = String(line.get("speaker", ""))
		body = String(line.get("text", ""))
	else:
		body = String(line)
	_name.text = speaker
	_name.visible = speaker != ""
	_text.text = ""
	_chars = 0.0
	_typing = true
	_hint.text = "任意攻擊鍵 / Enter：顯示全文"

func _finish_typing() -> void:
	if _index < 0 or _index >= _lines.size():
		return
	var line = _lines[_index]
	var body: String = String(line.get("text", "")) if typeof(line) == TYPE_DICTIONARY else String(line)
	_text.text = body
	_chars = float(body.length())
	_typing = false
	_hint.text = "任意攻擊鍵 / Enter：繼續"

func _process(delta: float) -> void:
	if not _active or not _typing:
		return
	_chars += CHARS_PER_SECOND * delta
	if _index < 0 or _index >= _lines.size():
		return
	var line = _lines[_index]
	var body: String = String(line.get("text", "")) if typeof(line) == TYPE_DICTIONARY else String(line)
	var shown: int = int(_chars)
	if shown >= body.length():
		_finish_typing()
		return
	_text.text = body.substr(0, shown)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("p1_light") or event.is_action_pressed("p1_heavy"):
		get_viewport().set_input_as_handled()
		next()
