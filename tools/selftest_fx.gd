extends SceneTree
## 刀光／酒氣特效層無頭自測：
##  A. 節點與靜止態（預設全隱藏）
##  B. 刀光幾何：點數、朝向鏡像、上下弧方向、雙層寬度
##  C. 刀光生命週期：觸發可見 → 到期自動隱藏
##  D. 酒氣模式：Super 金脈衝 / 滿氣呼吸 / 醉打酒紅，退出即熄
##  E. 酒霧：僅醉打期間 emitting
## 用法：godot --headless --path <game> --script res://tools/selftest_fx.gd
## PASS 退出 0；FAIL 退出 1。

var a: CharacterBody2D
var fx: Node2D
var n: int = 0
var fails: Array = []

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	a = load("res://scenes/RiggedFighter.tscn").instantiate()
	root.add_child(a)
	a.set_physics_process(false)   # 斷言期間凍結控制器物理，僅手動同步特效
	physics_frame.connect(_on_frame)

func _advance(seconds: float) -> void:
	# 手動推進特效層時鐘，等價於 seconds 秒的物理幀
	var steps: int = int(round(seconds / (1.0 / 60.0)))
	for i in steps:
		fx._physics_process(1.0 / 60.0)

func _on_frame() -> void:
	n += 1
	if n != 2:
		return

	fx = a.get_node_or_null("Fx")
	_check("Fx node exists", fx != null)
	var core: Line2D = a.get_node_or_null("Fx/SlashCore")
	var halo: Line2D = a.get_node_or_null("Fx/SlashHalo")
	var aura: Sprite2D = a.get_node_or_null("Fx/Aura")
	var vapor: CPUParticles2D = a.get_node_or_null("Fx/DrunkVapor")
	_check("SlashCore exists", core != null)
	_check("SlashHalo exists", halo != null)
	_check("Aura exists", aura != null)
	_check("DrunkVapor exists", vapor != null)
	_check("slash hidden at rest", core.visible == false and halo.visible == false)
	_check("aura hidden at rest", aura.visible == false)
	_check("vapor off at rest", vapor.emitting == false)
	_check("slash width curve tapered", core.width_curve != null)
	_check("aura sits behind body", aura.z_index < 0)
	_check("slash sits in front of body", core.z_index > 0 and halo.z_index > 0)

	# ---- B. 刀光幾何：朝右輕拳 ----
	a.face_direction = 1.0
	a.change_state("Light1")
	_check("strike makes slash visible", core.visible == true and halo.visible == true)
	_check("arc has 26 samples", core.points.size() == 26)
	var all_forward: bool = true
	var nan_free: bool = true
	for p in core.points:
		if p.x <= 0.0:
			all_forward = false
		if is_nan(p.x) or is_nan(p.y):
			nan_free = false
	_check("arc on facing side (right)", all_forward)
	_check("arc points finite", nan_free)
	var light_width: float = core.width
	_check("halo thicker than core", halo.width > core.width)
	_check("core colored pale blue", core.default_color.b >= core.default_color.r)

	# ---- C. 生命週期 ----
	_advance(0.05)
	_check("slash visible mid-life", core.visible == true and core.modulate.a > 0.1)
	_advance(0.30)
	_check("slash auto-hides after life", core.visible == false and halo.visible == false)

	# ---- B2. 朝向鏡像 ----
	a.change_state("Idle")
	a.face_direction = -1.0
	a.change_state("Light1")
	var all_left: bool = true
	for p in core.points:
		if p.x >= 0.0:
			all_left = false
	_check("arc mirrors to left when facing -1", all_left)

	# ---- B3. 昇龍由下往上 ----
	a.change_state("Idle")
	a.face_direction = 1.0
	a.change_state("CmdUp")
	var first: Vector2 = core.points[0]
	var last: Vector2 = core.points[core.points.size() - 1]
	_check("rising arc sweeps upward (last y above first)", last.y < first.y - 40.0)

	# ---- D. 酒氣模式 ----
	a.change_state("Idle")
	a.wine_gauge = 0.0
	a._fx_sync()
	fx._physics_process(0.016)
	_check("aura off in plain idle", aura.visible == false)

	a.wine_gauge = 100.0
	a._fx_sync()
	fx._physics_process(0.016)
	_check("awaken idle shows soft aura", aura.visible == true and aura.modulate.a > 0.05)
	_check("awaken aura is warm gold", aura.modulate.r > aura.modulate.g and aura.modulate.g > aura.modulate.b)

	a.change_state("Super")
	a.wine_gauge = 100.0
	a._fx_sync()
	fx._physics_process(0.016)
	_check("Super aura visible", aura.visible == true)
	_check("Super aura strong alpha", aura.modulate.a >= 0.28)

	a.change_state("Idle")
	a.wine_gauge = 0.0
	a._fx_sync()
	fx._physics_process(0.016)
	_check("aura off after Super ends", aura.visible == false)

	# ---- E. 醉打酒紅與酒霧 ----
	a.wine_gauge = 50.0
	a.change_state("CmdDrunk")
	a._fx_sync()
	fx._physics_process(0.016)
	_check("drunk aura visible", aura.visible == true)
	_check("drunk aura is wine red", aura.modulate.r > aura.modulate.g and aura.modulate.r > aura.modulate.b)
	_check("drunk vapor emitting", vapor.emitting == true)
	_check("drunk strike uses wider arc", core.width > light_width * 1.4)

	a.change_state("Idle")
	a._fx_sync()
	fx._physics_process(0.016)
	_check("drunk vapor stops on exit", vapor.emitting == false)

	if fails.is_empty():
		print("FX_SELFTEST result=PASS")
		quit(0)
	else:
		print("FX_SELFTEST FAIL count=", fails.size(), " -> ", fails)
		quit(1)
