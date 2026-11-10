extends Node2D
## 掉落物：碎銀 / 伥鬼的木牌（docs/04 §2）
## 純程序繪製，不引入新貼圖；玩家走過去即拾取，並通知主場景彈提示。

const COLLECT_BOX: Vector2 = Vector2(64.0, 180.0)
const COLLECT_OFFSET: Vector2 = Vector2(0.0, -90.0)
const RADIUS: float = 20.0

var target = null
var item_name: String = "碎銀"
var base_y: float = 0.0
var age: float = 0.0
var is_tag: bool = false

func setup(p_target, p_item: String, p_pos: Vector2) -> void:
	target = p_target
	item_name = p_item
	position = p_pos
	base_y = p_pos.y
	is_tag = p_item.contains("木牌")

func _ready() -> void:
	z_index = 2
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	position.y = base_y - 4.0 * sin(age * 3.0)
	queue_redraw()
	if _touches_target():
		_collect()

## 與玩家受擊框（64×180）重疊即算拾取
func _touches_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var box := Rect2(target.global_position + COLLECT_OFFSET - COLLECT_BOX * 0.5, COLLECT_BOX)
	return box.grow(RADIUS).has_point(global_position)

func _collect() -> void:
	if is_queued_for_deletion():
		return
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("_on_pickup_collected"):
		parent_node._on_pickup_collected(item_name)
	queue_free()

func _draw() -> void:
	if is_tag:
		# 木牌：小木片 + 掛繩
		draw_rect(Rect2(Vector2(-11.0, -16.0), Vector2(22.0, 32.0)), Color(0.46, 0.33, 0.20))
		draw_rect(Rect2(Vector2(-11.0, -16.0), Vector2(22.0, 32.0)), Color(0.62, 0.46, 0.28), false, 2.0)
		draw_line(Vector2(0.0, -16.0), Vector2(0.0, -26.0), Color(0.55, 0.45, 0.32), 2.0)
		draw_rect(Rect2(Vector2(-6.0, -6.0), Vector2(12.0, 4.0)), Color(0.30, 0.21, 0.12))
		draw_rect(Rect2(Vector2(-6.0, 2.0), Vector2(12.0, 4.0)), Color(0.30, 0.21, 0.12))
	else:
		# 碎銀：不規則銀塊 + 一道高光
		var pts := PackedVector2Array([
			Vector2(-12.0, -4.0), Vector2(-5.0, -12.0), Vector2(6.0, -11.0),
			Vector2(12.0, -2.0), Vector2(8.0, 9.0), Vector2(-4.0, 11.0),
			Vector2(-11.0, 5.0),
		])
		draw_colored_polygon(pts, Color(0.72, 0.74, 0.70))
		draw_polyline(pts, Color(0.88, 0.90, 0.86), 2.0)
		draw_line(Vector2(-6.0, -6.0), Vector2(2.0, -8.0), Color(1.0, 1.0, 0.96), 2.0)
