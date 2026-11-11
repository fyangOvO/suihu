extends "res://scripts/chapters/stage_base.gd"
## SCN-06 水潭：B8 倒影字幕 → B9 下山 → 製作名單 → 主菜單。

var _credits: Label

func scene_id() -> String:
	return "SCN-06"

func scene_title() -> String:
	return "水潭"

func first_beat() -> String:
	return "B8"

func background_color() -> Color:
	return Color(0.035, 0.05, 0.075)

func _on_stage_start() -> void:
	_build_water()
	if _cm().current_beat == "B9":
		_play_ending()
	else:
		_say(STORY.lines("B8"), Callable(self, "_after_b8"))

func _build_water() -> void:
	var glow := _disc(Vector2(960, 220), 118.0, Color(0.42, 0.5, 0.56, 0.06))
	add_child(glow)
	var moon := _disc(Vector2(960, 220), 82.0, Color(0.88, 0.92, 0.96, 0.82))
	add_child(moon)
	var water := ColorRect.new()
	water.position = Vector2(0, 900)
	water.size = Vector2(1920, 180)
	water.color = Color(0.05, 0.08, 0.11, 1)
	add_child(water)

func _disc(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(48):
		var a: float = TAU * float(i) / 48.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	p.color = color
	return p

func _after_b8() -> void:
	_cm().mark_clear("B8")
	_cm().set_beat("B9")
	_play_ending()

func _play_ending() -> void:
	_say(STORY.lines("B9"), Callable(self, "_after_b9"))

func _after_b9() -> void:
	_cm().mark_clear("B9")
	_credits = Label.new()
	_credits.position = Vector2(460, 260)
	_credits.size = Vector2(1000, 460)
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.add_theme_font_size_override("font_size", 28)
	_credits.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	_credits.text = "水滸：妖魔劫\n\n1.0 Lite\n\n武松 — 打虎\n酒肆老闆 — 看不見的東西\n山神 — 回頭，還是上去\n\n景陽岡沒有虎了。\n但武松的影子，從此是四隻。"
	add_child(_credits)
	await get_tree().create_timer(9.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
