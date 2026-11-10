extends Node2D
## 伥鬼遠程技「扔石頭」（docs/04 §2 特殊技：慢、可閃）
## 純腳本弧線飛行＋矩形重疊判定：不用 Area2D／body space，無頭環境與物理回調裡都可靠。
## 由 rigged_fighter 的 AI 呼叫 setup() 後掛進舞台父節點。

const GRAVITY: float = 520.0
const RADIUS: float = 34.0
const FLOOR_Y: float = 850.0       # 地面頂面（MainRigged Ground y=870、高 40）
const STAGE_LEFT: float = 0.0
const STAGE_RIGHT: float = 1920.0
const TARGET_HURT_SIZE: Vector2 = Vector2(64.0, 180.0)
const TARGET_HURT_OFFSET: Vector2 = Vector2(0.0, -90.0)
const EXTRA_LIFE: float = 1.2      # 預定落點後再多飛一點，避免邊緣誤刪

var damage: int = 75
var target = null
var from_dir: float = 1.0
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var flight_time: float = 1.0

## 設定投擲參數：起點、方向、傷害與目標；弧線按距離算飛行時間，落點正好壓在對手身上
func setup(p_target, p_dir: float, p_damage: int, p_from: Vector2) -> void:
	position = p_from
	target = p_target
	from_dir = p_dir
	damage = p_damage
	# 慢弧：距離越遠飛得越久（可視為「可閃」的窗口）
	var dist: float = 430.0
	if p_target != null and is_instance_valid(p_target):
		dist = absf(p_target.global_position.x - p_from.x)
	flight_time = clampf(dist / 430.0, 0.55, 1.5)
	velocity = Vector2(p_dir * dist / flight_time, -0.5 * GRAVITY * flight_time)

func _ready() -> void:
	z_index = 3
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation += 7.0 * delta
	queue_redraw()
	if _hits_target():
		_apply_hit()
		queue_free()
		return
	if position.y >= FLOOR_Y - RADIUS or position.x < STAGE_LEFT or position.x > STAGE_RIGHT:
		queue_free()       # 落地／撞邊界即碎，不留殘骸
		return
	if age >= flight_time + EXTRA_LIFE:
		queue_free()

func _hits_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var tpos: Vector2 = target.global_position
	var box := Rect2(tpos + TARGET_HURT_OFFSET - TARGET_HURT_SIZE * 0.5, TARGET_HURT_SIZE)
	return box.grow(RADIUS).has_point(global_position)

func _apply_hit() -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.is_blocking:
		target.on_blocked(damage, from_dir, 0.0)
	else:
		target.take_damage(damage, from_dir, 0.0)

func _draw() -> void:
	# 一塊不規則灰石（純程序繪製，不引入新貼圖）
	var pts := PackedVector2Array([
		Vector2(-31.0, -13.0), Vector2(-13.0, -31.0), Vector2(14.0, -27.0),
		Vector2(31.0, -7.0), Vector2(25.0, 21.0), Vector2(0.0, 31.0),
		Vector2(-24.0, 21.0),
	])
	draw_colored_polygon(pts, Color(0.38, 0.35, 0.31))
	draw_polyline(pts, Color(0.64, 0.60, 0.54), 2.5)
	draw_circle(Vector2(-8.0, -10.0), 6.5, Color(0.52, 0.49, 0.44))
