extends "res://scripts/chapters/stage_base.gd"
## SCN-05 崗頂：B6 虎眼亮相 → B7 猛虎 Boss 三階段。

func scene_id() -> String:
	return "SCN-05"

func scene_title() -> String:
	return "崗頂"

func first_beat() -> String:
	return "B6"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return "res://scenes/Boss.tscn"

func opponent_display_name() -> String:
	return "景陽岡猛虎"

func _on_stage_start() -> void:
	if p2 != null:
		p2.set_physics_process(false)
	if _cm().current_beat == "B6":
		show_banner("霧裡，兩點青白先亮。", 2.6)
		await get_tree().create_timer(2.6).timeout
		_cm().mark_clear("B6")
		_cm().set_beat("B7")
	if p2 != null and not p2._death_done:
		p2.set_physics_process(true)
	show_banner("", 0.0)

func _tick_stage(_delta: float) -> void:
	if p2 != null and p2.current_hp <= 0 and p2._death_done:
		_cm().mark_clear("B7")
		_finish_to("B8", 3.4, "")
