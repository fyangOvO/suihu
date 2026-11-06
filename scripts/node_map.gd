extends Control

var buttons: Array[Button] = []
var selected_idx: int = 0

func _ready():
	buttons = [$BtnFight1, $BtnDrink1]
	_update_selection()

func _update_selection():
	for i in range(buttons.size()):
		if i == selected_idx:
			buttons[i].modulate = Color(1.5, 1.2, 0.5)
		else:
			buttons[i].modulate = Color(1, 1, 1)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			selected_idx = (selected_idx - 1 + buttons.size()) % buttons.size()
			_update_selection()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			selected_idx = (selected_idx + 1) % buttons.size()
			_update_selection()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_confirm()

func _confirm():
	match selected_idx:
		0:
			get_tree().change_scene_to_file("res://scenes/MainRigged.tscn")
		1:
			$BtnDrink1.disabled = true
			$BtnDrink1.text = "已喝酒 +50HP"
			$BtnFight2.disabled = false
			$BtnElite.disabled = false
			$BtnFight3.disabled = false
			buttons = [$BtnFight2, $BtnElite, $BtnFight3]
			selected_idx = 0
			_update_selection()
