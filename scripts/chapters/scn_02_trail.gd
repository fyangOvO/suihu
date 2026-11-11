extends "res://scripts/chapters/stage_base.gd"
## SCN-02 山道：B2 旁白 → B3 老虎伥鬼实体教学战。
## 敌人死亡后写 B3 完成并进入 B4；教程提示只负责教学，不再用计时器自动推进。

const CORPSE_GHOST_SCENE := "res://scenes/CorpseGhost.tscn"

var _tutorial_step: int = 0
var _tutorial_t: float = 0.0
var _enemy_down: bool = false

func scene_id() -> String:
	return "SCN-02"

func scene_title() -> String:
	return "山道"

func first_beat() -> String:
	return "B2"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return CORPSE_GHOST_SCENE

func opponent_display_name() -> String:
	return "老虎伥鬼"

func _on_stage_start() -> void:
	if p2 != null:
		p2.position.x = 1120.0
		p2.set_physics_process(false)
	if _cm().current_beat == "B2":
		_say(STORY.lines("B2"), Callable(self, "_after_b2"))
	else:
		_start_fight()

func _after_b2() -> void:
	_cm().mark_clear("B2")
	_cm().set_beat("B3")
	_start_fight()

func _start_fight() -> void:
	_tutorial_step = 0
	_tutorial_t = 0.0
	_enemy_down = false
	if p2 != null:
		p2.set_physics_process(true)
	show_banner("山道：霧裡有人影擋路。", 2.0)

func _tick_stage(delta: float) -> void:
	_tutorial_t += delta
	# 只要伥鬼青煙散完，這場就結束；不依賴教程計時
	if not _enemy_down and p2 != null and p2.current_hp <= 0 and p2._death_done:
		_enemy_down = true
		_cm().mark_clear("B3")
		_finish_to("B4", 1.6, "山道通了。")
		return
	if _enemy_down:
		return
	if _tutorial_step == 0 and _tutorial_t >= 2.2:
		_tutorial_step = 1
		show_banner("J 輕擊 / K 重擊：木棍很長，貼身前先看起手。", 2.4)
	elif _tutorial_step == 1 and _tutorial_t >= 5.2:
		_tutorial_step = 2
		show_banner("L 站防；它會站著擋，不會蹲防。", 2.4)
	elif _tutorial_step == 2 and _tutorial_t >= 8.2:
		_tutorial_step = 3
		show_banner("它揮棍前搖長，看準收招再打。", 2.4)
