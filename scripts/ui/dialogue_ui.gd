extends CanvasLayer
## FLOW-02：逐字對話框。一次只播一行，打字中按鍵先補滿，再按下一句。
## 對話期間由場景凍結玩家；本節點只負責顯示與接收確認鍵。

signal finished

const CHARS_PER_SECOND: float = 34.0
const UI_STYLE := preload("res://scripts/ui/ui_style.gd")
const AUDIO := preload("res://scripts/audio/game_audio.gd")

var _lines: Array = []
var _index: int = -1
var _typing: bool = false
var _chars: float = 0.0
var _active: bool = false
var _callback: Callable = Callable()
var _body: String = ""           # 當前整句快取，避免逐幀從字典重取字串
var _typing_tick: int = 0        # 上次打字音的顯示字數，每 3 字響一次

@onready var _box: ColorRect = $Box
@onready var _name: Label = $Box/Name
@onready var _text: Label = $Box/Text
@onready var _hint: Label = $Box/Hint

func _ready() -> void:
	visible = false
	set_process(false)
	UI_STYLE.apply_label(_name, 30, UI_STYLE.GOLD, true)
	UI_STYLE.apply_label(_text, 28, UI_STYLE.PAPER)
	UI_STYLE.apply_label(_hint, 14, UI_STYLE.PAPER_DIM)
	UI_STYLE.add_paper(_box, 0.04)
	UI_STYLE.add_corner_marks(_box, 26.0, 10.0)

func play(lines: Array, on_finished: Callable = Callable()) -> void:
	_lines = lines.duplicate(true)
	_index = -1
	_callback = on_finished
	_active = true
	visible = true
	set_process(true)
	AUDIO.duck_dialogue(true)
	AUDIO.play_sfx("sfx_dialog_open", -8.0)
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
	AUDIO.duck_dialogue(false)
	var cb: Callable = _callback
	_callback = Callable()
	if cb.is_valid():
		cb.call()

func _start_line(line) -> void:
	var speaker: String = ""
	var body: String = ""
	var voice: String = ""
	if typeof(line) == TYPE_DICTIONARY:
		speaker = String(line.get("speaker", ""))
		body = String(line.get("text", ""))
		voice = String(line.get("voice", ""))
	else:
		body = String(line)
	_name.text = speaker
	_name.visible = speaker != ""
	_body = body
	_typing_tick = 0
	_text.text = ""
	_chars = 0.0
	_typing = true
	_hint.text = "任意攻擊鍵 / Enter：顯示全文"
	if voice != "":
		AUDIO.play_voice(voice, -2.0)

func _finish_typing() -> void:
	if _index < 0 or _index >= _lines.size():
		return
	_text.text = _body
	_chars = float(_body.length())
	_typing = false
	_hint.text = "任意攻擊鍵 / Enter：繼續"

func _process(delta: float) -> void:
	if not _active or not _typing:
		return
	_chars += CHARS_PER_SECOND * delta
	var shown: int = int(_chars)
	if shown >= _body.length():
		_finish_typing()
		return
	if shown >= _typing_tick + 3:
		_typing_tick = shown
		AUDIO.play_sfx("sfx_typing", -18.0, 0.96 + 0.02 * float(shown % 5))
	_text.text = _body.substr(0, shown)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("p1_light") or event.is_action_pressed("p1_heavy"):
		get_viewport().set_input_as_handled()
		next()
