extends SceneTree
## 高速技視覺幀率回歸自測（無頭）：
## 1) 揮擊/騰空技 visual.fps 達標；2) 邏輯幀窗口（startup/active/recovery）不受 fps 影響；
## 3) 待機/防禦/演出類維持 30fps。
## 用法：godot --headless --path <game> --script res://tools/check_visual_fps.gd

const DATA := preload("res://data/action_frame_data.gd")

func _initialize() -> void:
	var want := {"Light3": 40, "Heavy": 45, "AirLight": 50, "AirHeavy": 50,
		"CmdUp": 50, "CmdTiger": 45}
	var ok := true
	for act in want:
		var sp: Dictionary = DATA.spec(act)
		var f: int = int(sp.get("visual", {}).get("fps", 30))
		var ms: float = DATA.visual_frame_ms(sp)
		print(act, " fps=", f, " visual_ms=", ms,
			" logic_frames=", DATA.total_frames(sp),
			" visual_slots=", sp.get("visual", {}).get("frames", []).size())
		if f != want[act]:
			ok = false

	# 邏輯窗口不隨視覺 fps 變化（抽查總邏輯幀）
	if DATA.total_frames(DATA.spec("Light3")) != 36:
		ok = false
	if DATA.total_frames(DATA.spec("Heavy")) != 40:
		ok = false

	# 節奏類保持 30fps，避免待機/演出被切碎
	for keep in ["Idle", "Walk", "Block", "HurtStand", "Drink", "Super", "Dash"]:
		var kf: int = int(DATA.spec(keep).get("visual", {}).get("fps", 30))
		if kf != 30:
			print("WARN ", keep, " fps=", kf, " 應為 30")
			ok = false

	print("FPS_CHECK result=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
