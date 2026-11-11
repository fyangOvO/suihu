extends "res://scripts/chapters/stage_base.gd"
## SCN-03 亂林：B5 吊睛小虎精英戰。

func scene_id() -> String:
	return "SCN-03"

func scene_title() -> String:
	return "亂林"

func first_beat() -> String:
	return "B5"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return "res://scenes/Tiger.tscn"

func opponent_display_name() -> String:
	return "吊睛小虎"

func _on_stage_start() -> void:
	show_banner("霧裡，低吼。", 2.0)

func _tick_stage(_delta: float) -> void:
	if p2 != null and p2.current_hp <= 0 and p2._death_done:
		_finish_to("B6", 2.0, "小虎倒了，霧散了。")
