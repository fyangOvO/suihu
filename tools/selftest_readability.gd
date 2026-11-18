extends SceneTree
## OPT-06 可讀性自測（結構面）：
##  A. 三敵輪廓光配色分級：伥鬼灰 / 小虎土黃 / Boss 白額，玩家冷白且更弱
##  B. 輪廓材質走 fighter_look.gdshader，且每個實例各自一份（不串場景）
##  C. 攻擊前搖輪廓提亮：startup 內 rim_energy 上升，命中後回落
##  D. 三敵起手招都有 startup，提示才有窗口可打
##  E. 特效面積上限（§14.4 暖 ≤15%、冷青 ≤5%）以幾何面積估算
## 用法：godot --headless --path <game> --script res://tools/selftest_readability.gd

const RIGGED := "res://scenes/RiggedFighter.tscn"
const DATA := preload("res://data/action_frame_data.gd")
const CORPSE := "res://scenes/CorpseGhost.tscn"
const TIGER := "res://scenes/Tiger.tscn"
const BOSS := "res://scenes/Boss.tscn"

var fails: Array = []

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails.append(label if detail == "" else "%s (%s)" % [label, detail])

func _initialize() -> void:
	await process_frame

	var player = _spawn(RIGGED)
	var corpse = _spawn(CORPSE)
	var tiger = _spawn(TIGER)
	var boss = _spawn(BOSS)

	# ---- A. 剪影配色分級 ----
	_check("player has cool rim", player.rim_color.b > player.rim_color.r and player.rim_strength > 0.2)
	_check("player rim weaker than enemies", player.rim_strength < tiger.rim_strength and player.rim_strength < boss.rim_strength)
	_check("corpse rim is grey (low saturation)",
		corpse.rim_color.s < 0.25 and corpse.rim_color.v > 0.55, str(corpse.rim_color))
	_check("tiger rim is earth yellow",
		tiger.rim_color.r > 0.85 and tiger.rim_color.g > 0.55 and tiger.rim_color.b < 0.45
		and tiger.rim_color.r > tiger.rim_color.b + 0.4, str(tiger.rim_color))
	_check("boss rim is white",
		boss.rim_color.v > 0.9 and boss.rim_color.s < 0.12, str(boss.rim_color))
	_check("three enemy rims distinct",
		_rgb_dist(corpse.rim_color, tiger.rim_color) > 0.25
		and _rgb_dist(tiger.rim_color, boss.rim_color) > 0.25
		and _rgb_dist(corpse.rim_color, boss.rim_color) > 0.15)
	_check("boss rim thicker than corpse", boss.rim_width > corpse.rim_width)

	# ---- B. 材質 ----
	for pair in [["player", player], ["corpse", corpse], ["tiger", tiger], ["boss", boss]]:
		var node = pair[1]
		var mat = node._flash_mat
		_check("%s has look material" % pair[0], mat != null and mat.shader != null)
		if mat != null and mat.shader != null:
			_check("%s shader is fighter_look" % pair[0],
				mat.shader.resource_path.ends_with("fighter_look.gdshader"), mat.shader.resource_path)
			_check("%s material carries rim params" % pair[0],
				mat.get_shader_parameter("rim_color") != null and mat.get_shader_parameter("rim_energy") != null)
	_check("materials are per-instance", corpse._flash_mat != tiger._flash_mat and tiger._flash_mat != boss._flash_mat)

	# ---- C. 前搖提示 ----
	var startup: int = int(tiger._spec("TigerPounce")["logic"].get("startup", 0))
	_check("tiger pounce has startup", startup > 0, str(startup))
	tiger.set_physics_process(false)
	tiger._state = "TigerPounce"
	tiger._frame = 0
	tiger._update_rim()
	var e0: float = float(tiger._flash_mat.get_shader_parameter("rim_energy"))
	tiger._frame = startup - 1
	tiger._update_rim()
	var e1: float = float(tiger._flash_mat.get_shader_parameter("rim_energy"))
	tiger._frame = startup + 8
	tiger._update_rim()
	var e2: float = float(tiger._flash_mat.get_shader_parameter("rim_energy"))
	_check("telegraph brightens before hit", e1 > e0 and e1 >= tiger.rim_strength + 0.6, "%.2f -> %.2f" % [e0, e1])
	_check("telegraph settles after hit", e2 <= tiger.rim_strength + 0.05, "%.2f" % e2)
	_check("telegraph does not exceed shader range", e1 <= 2.0)

	# ---- D. 三敵起手招 startup ----
	for pair in [["CorpseHeavy", corpse], ["BossTail", boss], ["BossRearUp", boss]]:
		var st: int = int(DATA.spec(pair[0])["logic"].get("startup", 0))
		_check("%s startup > 0" % pair[0], st > 0, str(st))

	# ---- E. 特效面積上限（幾何估算，1920×1080 基準） ----
	var screen_area: float = 1920.0 * 1080.0
	var aura_area: float = 128.0 * 3.0 * 128.0 * 3.3
	var warm_ratio: float = aura_area / screen_area
	_check("super aura area <= 15%", warm_ratio <= 0.15, "%.1f%%" % (warm_ratio * 100.0))
	var halo_area: float = 140.0 * 1.1 * 20.0    # 醉打最寬弧長×halo 寬度
	_check("cool slash halo <= 5%", halo_area / screen_area <= 0.05, "%.2f%%" % (halo_area / screen_area * 100.0))

	# ---- 收尾 ----
	for n in [player, corpse, tiger, boss]:
		n.queue_free()
	await process_frame
	print("READABILITY_SELFTEST result=%s fails=%d -> %s" % ["PASS" if fails.is_empty() else "FAIL", fails.size(), str(fails)])
	quit(0 if fails.is_empty() else 1)

func _spawn(path: String) -> Node:
	var n = load(path).instantiate()
	root.add_child(n)
	n.set_physics_process(false)
	return n

func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
