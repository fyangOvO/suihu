extends "res://scripts/chapters/stage_base.gd"
## SCN-01 酒肆：B1 三段對話，燈滅後出門。

func scene_id() -> String:
	return "SCN-01"

func scene_title() -> String:
	return "酒肆"

func first_beat() -> String:
	return "B1"

func background_color() -> Color:
	return Color(0.11, 0.085, 0.065)

func _on_stage_start() -> void:
	show_banner("景陽岡下，酒肆。", 2.0)
	_say(STORY.lines("B1"), Callable(self, "_after_b1"))

func _after_b1() -> void:
	show_banner("燈滅了。店家的影子，多了一條尾巴。", 2.2)
	await get_tree().create_timer(2.2).timeout
	_cm().mark_clear("B1")
	_cm().goto_beat("B2")
