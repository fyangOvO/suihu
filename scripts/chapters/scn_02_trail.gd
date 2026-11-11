extends "res://scripts/chapters/stage_base.gd"
## SCN-02 山道：B2 旁白 + B3 伥鬼教學（目前為教學提示骨架，伥鬼美術待補）。

var _tutorial_step: int = 0
var _tutorial_t: float = 0.0

func scene_id() -> String:
	return "SCN-02"

func scene_title() -> String:
	return "山道"

func first_beat() -> String:
	return "B2"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func _on_stage_start() -> void:
	if _cm().current_beat == "B2":
		_say(STORY.lines("B2"), Callable(self, "_after_b2"))
	else:
		_start_tutorial()

func _after_b2() -> void:
	_cm().mark_clear("B2")
	_cm().set_beat("B3")
	_start_tutorial()

func _start_tutorial() -> void:
	_tutorial_step = 0
	_tutorial_t = 0.0
	show_banner("山道：雾里有人影挡路（伥鬼战待素材）", 2.4)

func _tick_stage(delta: float) -> void:
	_tutorial_t += delta
	if _tutorial_step == 0 and _tutorial_t >= 2.4:
		_tutorial_step = 1
		show_banner("J 輕擊 / K 重擊：先打斷它，再走。", 2.4)
	elif _tutorial_step == 1 and _tutorial_t >= 4.8:
		_tutorial_step = 2
		show_banner("L 站防；下段招式要蹲防（S + L）。", 2.4)
	elif _tutorial_step == 2 and _tutorial_t >= 7.2:
		_tutorial_step = 3
		show_banner("被擊倒時按 J + 方向起身。", 2.4)
	elif _tutorial_step == 3 and _tutorial_t >= 9.6:
		_tutorial_step = 4
		_cm().mark_clear("B3")
		_finish_to("B4", 1.4, "山道通了。")
