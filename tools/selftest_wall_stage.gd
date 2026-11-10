extends SceneTree
## 主場景邊界牆端到端自測：直接實例化 MainRigged.tscn，把 P1/P2 推向左右邊界，
## 驗證牆真的擋得住（不只驗節點存在）。
## 注意：場景必須在 _initialize 內 add_child，不能在 physics_frame 回調裡掛——
##       物理幀中新增的 CollisionObject2D 不會進入 physics space（body->get_space() == null），
##       test_move / move_and_collide 會直接報錯。
## 用法：godot --headless --path <game> --script res://tools/selftest_wall_stage.gd
## PASS 退出 0；FAIL 退出 1。

var fails: Array = []
var live: Node
var p1: CharacterBody2D
var p2: CharacterBody2D
var n: int = 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	live = load("res://scenes/MainRigged.tscn").instantiate()
	root.add_child(live)
	p1 = live.get_node("P1")
	p2 = live.get_node("P2")
	p2.is_player1 = true        # 關掉 P2 的 AI，避免它自己去撞牆干擾判定
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	n += 1
	if n < 6:
		return
	# 左邊界：牆面 x=0；角色半身 30px，最多推到 x=30
	p1.set_physics_process(false)
	p1._state = "Idle"
	p1.velocity = Vector2.ZERO
	p1.position = Vector2(60.0, 820.0)
	var hit_left: KinematicCollision2D = p1.move_and_collide(Vector2(-80.0, 0.0))
	_check("left wall reports collision", hit_left != null)
	_check("left wall stops at x>=30", p1.position.x >= 29.9)
	# 右邊界：牆面 x=1920；最多推到 x=1890
	p2.set_physics_process(false)
	p2._state = "Idle"
	p2.velocity = Vector2.ZERO
	p2.position = Vector2(1860.0, 820.0)
	var hit_right: KinematicCollision2D = p2.move_and_collide(Vector2(80.0, 0.0))
	_check("right wall reports collision", hit_right != null)
	_check("right wall stops at x<=1890", p2.position.x <= 1890.1)
	# 牆旁探針：貼牆時 _wall_on_side 指向牆為 true、背向牆為 false
	_check("probe sees left wall", p1._wall_on_side(-1.0))
	_check("probe ignores open side", not p1._wall_on_side(1.0))
	print("SELFTEST stage p1x=", p1.position.x, " p2x=", p2.position.x, " fails=", fails.size())
	quit(0 if fails.is_empty() else 1)
