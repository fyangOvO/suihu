extends Node2D
## 刀光 / 酒氣獨立特效層（純程序繪製，不依賴額外貼圖）
##
## 刀光：雙層 Line2D（核心亮線＋外圈輝光），依招式種類取不同弧度／寬度／色溫
## 酒氣：Sprite2D 徑向輝光（Super 金脈衝 / 滿氣柔和呼吸 / 醉打酒紅）
## 酒霧：CPUParticles2D 上升粒子，僅醉打期間發射
##
## 生命週期以 _physics_process 的 delta 手動推進（不用 Tween），headless 可斷言；
## 本層只讀 _state / _frame / wine_gauge，不回寫任何戰鬥數值，也不碰判定盒。

const ARC_SAMPLES: int = 26
const PIVOT_Y: float = -150.0        # 刀光圓心（胸口高度，角色原點在腳底）

const ARC_KINDS := {
	"light": {"radius": 112.0, "from": -30.0, "to": 36.0, "width": 5.0, "life": 0.18,
		"core": Color(0.93, 0.97, 1.0), "halo": Color(0.55, 0.78, 1.0)},
	"heavy": {"radius": 128.0, "from": -54.0, "to": 40.0, "width": 8.0, "life": 0.24,
		"core": Color(1.0, 0.95, 0.84), "halo": Color(1.0, 0.72, 0.32)},
	"rising": {"radius": 126.0, "from": -66.0, "to": 60.0, "width": 7.0, "life": 0.26,
		"core": Color(1.0, 0.99, 0.94), "halo": Color(1.0, 0.80, 0.42)},
	"low": {"radius": 100.0, "from": -20.0, "to": 22.0, "width": 5.0, "life": 0.18,
		"core": Color(0.90, 0.95, 1.0), "halo": Color(0.52, 0.74, 1.0)},
	"air": {"radius": 114.0, "from": -78.0, "to": 10.0, "width": 6.0, "life": 0.22,
		"core": Color(0.88, 0.95, 1.0), "halo": Color(0.50, 0.76, 1.0)},
	"drunk": {"radius": 140.0, "from": -66.0, "to": 66.0, "width": 9.0, "life": 0.32,
		"core": Color(1.0, 0.92, 0.70), "halo": Color(0.95, 0.52, 0.30)},
}

var _life: float = 0.0
var _total: float = 0.0
var _t: float = 0.0
var _logic_frame: int = 0
var _aura_mode: String = "none"
var _aura_scale: Vector2 = Vector2.ONE
var _pending_kind: String = ""
var _pending_face: float = 1.0
var _delay: float = 0.0        # 待發延遲（= 招式 startup 幀數 / 60），到點才真正出刀


func _ready() -> void:
	var aura := get_node_or_null("Aura") as Sprite2D
	if aura != null:
		_aura_scale = aura.scale
	_ensure_width_curve("SlashCore")
	_ensure_width_curve("SlashHalo")
	reset()


## 兩端收尖的刀光寬度曲線（中段最厚，尾部快速收細）
func _ensure_width_curve(node_name: String) -> void:
	var ln := get_node_or_null(node_name) as Line2D
	if ln == null or ln.width_curve != null:
		return
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.22))
	c.add_point(Vector2(0.24, 1.0))
	c.add_point(Vector2(0.72, 0.82))
	c.add_point(Vector2(1.0, 0.08))
	ln.width_curve = c


## 回到「無任何特效」的靜止態（自測與狀態切換用）
func reset() -> void:
	_life = 0.0
	_total = 0.0
	_pending_kind = ""
	_delay = 0.0
	for n in ["SlashCore", "SlashHalo"]:
		var ln := get_node_or_null(n) as Line2D
		if ln != null:
			ln.visible = false
			ln.modulate = Color(1, 1, 1, 0)
	var aura := get_node_or_null("Aura") as Sprite2D
	if aura != null:
		aura.visible = false
		aura.modulate = Color(1, 1, 1, 0)
	var vap := get_node_or_null("DrunkVapor") as CPUParticles2D
	if vap != null:
		vap.emitting = false


## 觸發一刀刀光；face 為朝向（1 右 / -1 左）
## delay > 0 時先掛起，等 startup 走完（= 進入 active 命中窗口）才亮，讓刀光與判定盒同步
func strike(kind: String, face: float, delay: float = 0.0) -> void:
	if delay > 0.0:
		_pending_kind = kind
		_pending_face = face
		_delay = delay
		_total = 0.0
		_life = 0.0
		for n in ["SlashCore", "SlashHalo"]:
			var ln := get_node_or_null(n) as Line2D
			if ln != null:
				ln.visible = false
				ln.modulate = Color(1, 1, 1, 0)
		return
	_arm(kind, face)


## 招式被打斷（切到非攻擊狀態）時，取消尚未出鞘的刀光與殘留弧
func cancel() -> void:
	_pending_kind = ""
	_delay = 0.0
	_total = 0.0
	_life = 0.0
	for n in ["SlashCore", "SlashHalo"]:
		var ln := get_node_or_null(n) as Line2D
		if ln != null:
			ln.visible = false
			ln.modulate = Color(1, 1, 1, 0)


## 尚未出刀的剩餘延遲（秒），0 表示已出刀或無待發
func pending_delay() -> float:
	return _delay


func _arm(kind: String, face: float) -> void:
	var cfg: Dictionary = ARC_KINDS.get(kind, ARC_KINDS["light"])
	var core := get_node_or_null("SlashCore") as Line2D
	var halo := get_node_or_null("SlashHalo") as Line2D
	if core == null or halo == null:
		return
	_build_arc(core, cfg, face, 1.0, 0.0, cfg["core"])
	_build_arc(halo, cfg, face, 1.04, 4.0, cfg["halo"])
	_total = float(cfg["life"])
	_life = _total
	_apply_alpha(0.0)


func _build_arc(ln: Line2D, cfg: Dictionary, face: float, r_scale: float,
		w_add: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var a0: float = deg_to_rad(float(cfg["from"]))
	var a1: float = deg_to_rad(float(cfg["to"]))
	var rad: float = float(cfg["radius"]) * r_scale
	for i in ARC_SAMPLES:
		var t: float = float(i) / float(ARC_SAMPLES - 1)
		var ang: float = lerpf(a0, a1, t)
		pts.append(Vector2(cos(ang) * face, -sin(ang)) * rad + Vector2(0.0, PIVOT_Y))
	ln.points = pts
	ln.width = float(cfg["width"]) + w_add
	ln.default_color = col
	ln.visible = true
	ln.modulate = Color(1, 1, 1, 0)


func _apply_alpha(a: float) -> void:
	var core := get_node_or_null("SlashCore") as Line2D
	if core != null:
		core.modulate = Color(1, 1, 1, clampf(a, 0.0, 1.0))
	var halo := get_node_or_null("SlashHalo") as Line2D
	if halo != null:
		halo.modulate = Color(1, 1, 1, clampf(a * 0.55, 0.0, 1.0))   # 外圈只留淡輝，避免糊成實心月牙


func _physics_process(delta: float) -> void:
	_t += delta
	if _delay > 0.0:
		_delay = maxf(0.0, _delay - delta)
		if _delay <= 0.0 and _pending_kind != "":
			var k: String = _pending_kind
			var f: float = _pending_face
			_pending_kind = ""
			_arm(k, f)
	if _total > 0.0:
		_life = maxf(0.0, _life - delta)
		var p: float = clampf(1.0 - _life / _total, 0.0, 1.0)
		_apply_alpha(sin(p * PI))            # 0 → 1 → 0 的快速涮亮
		if _life <= 0.0:
			for n in ["SlashCore", "SlashHalo"]:
				var ln := get_node_or_null(n) as Line2D
				if ln != null:
					ln.visible = false
	_update_aura()


## 由控制器每邏輯幀同步：只決定酒氣模式與酒霧開關
func sync(state: String, frame: int, wine: float) -> void:
	_logic_frame = frame
	if state == "Super":
		_aura_mode = "super"
	elif state == "CmdDrunk":
		_aura_mode = "drunk"
	elif state == "Idle" and wine >= 100.0:
		_aura_mode = "awaken"
	else:
		_aura_mode = "none"
	var vap := get_node_or_null("DrunkVapor") as CPUParticles2D
	if vap != null and vap.emitting != (state == "CmdDrunk"):
		vap.emitting = state == "CmdDrunk"


func _update_aura() -> void:
	var aura := get_node_or_null("Aura") as Sprite2D
	if aura == null:
		return
	if _aura_mode == "none":
		aura.visible = false
		aura.modulate = Color(1, 1, 1, 0)
		return
	aura.visible = true
	if _aura_mode == "super":
		var pulse: float = 0.5 + 0.5 * sin(float(_logic_frame) * 0.35)
		aura.modulate = Color(1.0, 0.72 + 0.12 * pulse, 0.28 + 0.14 * pulse, 0.40 + 0.30 * pulse)
		aura.scale = _aura_scale * (1.00 + 0.14 * pulse)
	elif _aura_mode == "awaken":
		var breath: float = 0.5 + 0.5 * sin(_t * 3.0)
		aura.modulate = Color(1.0, 0.86, 0.52, 0.14 + 0.16 * breath)
		aura.scale = _aura_scale * (1.00 + 0.05 * breath)
	else:  # drunk
		var wob: float = 0.5 + 0.5 * sin(_t * 4.0)
		aura.modulate = Color(0.95, 0.34, 0.26, 0.24 + 0.24 * wob)
		aura.scale = _aura_scale * (0.98 + 0.09 * wob)
