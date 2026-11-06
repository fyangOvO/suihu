extends Node2D

var _battle_over: bool = false
var _result_timer: float = 0.0
var _result_label: Label

func _ready():
	$P1.opponent = $P2
	$P2.opponent = $P1
	_result_label = Label.new()
	_result_label.set_anchors_preset(Control.PRESET_CENTER)
	_result_label.add_theme_font_size_override("font_size", 48)
	_result_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_result_label.visible = false
	add_child(_result_label)

func _process(delta):
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

func _show_result(text: String):
	_battle_over = true
	_result_timer = 2.0
	_result_label.text = text
	_result_label.visible = true
