extends Node2D

var _battle_over: bool = false
var _result_timer: float = 0.0
var _result_label: Label

# 覺醒過場演出（Super 觸發時：推鏡 + 暗角 + 刀光 + 定格白閃）
const CINE_DURATION: float = 2.0
const CAM_HOME := Vector2(960.0, 540.0)
const CAM_ZOOM_HOME := Vector2(1.0, 1.0)
var _cine_active: bool = false
var _cine_t: float = 0.0
var _cam: Camera2D = null
var _dim: ColorRect = null
var _slash: ColorRect = null
var _flash: ColorRect = null

func _ready():
	$P1.opponent = $P2
	$P2.opponent = $P1
	_result_label = Label.new()
	_result_label.set_anchors_preset(Control.PRESET_CENTER)
	_result_label.add_theme_font_size_override("font_size", 48)
	_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_result_label.visible = false
	add_child(_result_label)
	_cam = get_node_or_null("BattleCam")
	_dim = get_node_or_null("Cinematic/Dim")
	_slash = get_node_or_null("Cinematic/Slash")
	_flash = get_node_or_null("Cinematic/Flash")

func _process(delta):
	_update_cinematic(delta)
	if _battle_over:
		_result_timer -= delta
		if _result_timer <= 0:
			get_tree().change_scene_to_file("res://scenes/NodeMap.tscn")
		return

	$HUD/P1HP.value = $P1.current_hp
	$HUD/P2HP.value = $P2.current_hp

	# 酒氣條：滿氣 100 高亮並顯示覺醒提示（P2 為占位 AI，不繪製氣條）
	$HUD/P1Wine.value = $P1.wine_gauge
	var super_ready: bool = $P1.wine_gauge >= 100.0
	$HUD/P1Wine.modulate = Color(1.0, 0.85, 0.3) if super_ready else Color(0.8, 0.75, 0.55)
	$HUD/P1SuperHint.visible = super_ready

	if $P1.current_hp <= 0:
		_show_result("你敗了…")
	elif $P2.current_hp <= 0:
		_show_result("武松勝！")

## 演出推進：只在 P1 進入 Super 時啟動，離開 Super 或超時即復位
func _update_cinematic(delta: float) -> void:
	if not _cine_active:
		if $P1._state == "Super":
			_start_cinematic()
		return
	_cine_t += delta
	if $P1._state != "Super" or _cine_t >= CINE_DURATION:
		_end_cinematic()
		return

	var t: float = _cine_t
	# 0.00–0.30 推鏡 + 壓暗；0.30–0.55 刀光掃過 + 定格白閃；0.55–1.30 保持；1.30–2.00 復位
	var zoom_in: float = _ramp(t, 0.0, 0.30)
	var hold_out: float = _ramp(t, 1.30, 2.00)
	var zoom_k: float = zoom_in * (1.0 - hold_out)
	if _cam != null:
		_cam.zoom = CAM_ZOOM_HOME.lerp(Vector2(1.20, 1.20), zoom_k)
		var focus := Vector2($P1.global_position.x + 40.0 * $P1.face_direction, 560.0)
		_cam.position = CAM_HOME.lerp(focus, zoom_k)
	if _dim != null:
		_dim.modulate = Color(1.0, 1.0, 1.0, 0.55 * zoom_k)
	if _slash != null:
		var sweep: float = _ramp(t, 0.28, 0.36) * (1.0 - _ramp(t, 0.40, 0.55))
		_slash.modulate = Color(1.0, 1.0, 1.0, 0.9 * sweep)
		_slash.offset_left = 260.0 + 900.0 * sweep
		_slash.offset_right = _slash.offset_left + 1400.0
	if _flash != null:
		var flash: float = _ramp(t, 0.30, 0.33) * (1.0 - _ramp(t, 0.33, 0.48))
		_flash.modulate = Color(1.0, 1.0, 1.0, 0.75 * flash)

## 0→1 的線性斜坡（可當淡入/淡出使用）
func _ramp(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= to else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)

func _start_cinematic() -> void:
	_cine_active = true
	_cine_t = 0.0
	$P2.set_physics_process(false)   # 定格外對手，讓覺醒演出不受干擾

func _end_cinematic() -> void:
	_cine_active = false
	_cine_t = 0.0
	if _cam != null:
		_cam.zoom = CAM_ZOOM_HOME
		_cam.position = CAM_HOME
	if _dim != null:
		_dim.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _slash != null:
		_slash.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_slash.offset_left = 260.0
		_slash.offset_right = 1660.0
	if _flash != null:
		_flash.modulate = Color(1.0, 1.0, 1.0, 0.0)
	$P2.set_physics_process(true)

func _show_result(text: String):
	_battle_over = true
	_result_timer = 2.0
	_result_label.text = text
	_result_label.visible = true
