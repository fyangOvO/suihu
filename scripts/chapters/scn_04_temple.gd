extends "res://scripts/chapters/stage_base.gd"
## SCN-04 山神廟：B4 山神問路，存檔後上山。

func scene_id() -> String:
	return "SCN-04"

func scene_title() -> String:
	return "山神廟"

func first_beat() -> String:
	return "B4"

func background_color() -> Color:
	return Color(0.055, 0.06, 0.075)

func _on_stage_start() -> void:
	show_banner("山神廟。燭火壓得很低。", 2.0)
	_say(STORY.lines("B4"), Callable(self, "_after_b4"))

func _after_b4() -> void:
	_cm().mark_clear("B4")
	var ok: bool = _cm().save_checkpoint("B4", p1.current_hp)
	if ok:
		show_banner("已於山神廟存檔。", 1.8)
	else:
		show_banner("存檔失敗：%s" % _cm().last_checkpoint_error, 2.2)
	await get_tree().create_timer(1.8).timeout
	_cm().goto_beat("B5")
