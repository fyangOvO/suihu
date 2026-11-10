extends SceneTree
## 牆族（牆邊連段獎勵）無頭自測：
##  A. 擊退方向就是牆的方向 → 額外傷害 + 進 WallStick
##  B. 黏牆 30 幀內完全定身（不受重力下沉），第 30 幀末彈回轉 HurtAir
##  C. 彈回速度朝遠離牆的一側，且上拋（可再追打）
##  D. 中場無牆 → 一般受擊 HurtStand，不誤觸發
##  E. 貼身對手身體不算牆（探針只認 StaticBody2D）
## 用法：godot --headless --path <game> --script res://tools/selftest_wall.gd
## PASS 退出 0；FAIL 退出 1。

const DATA := preload("res://data/action_frame_data.gd")
const WALL_X: float = 900.0

var fails: Array = []
var a: CharacterBody2D
var b: CharacterBody2D
var wall: StaticBody2D
var n: int = 0
var phase: int = 0
var stuck_n: int = 0
var hp_after_wall: int = 0
var pinned_ok: bool = true
var start_y: float = 0.0
var bounce_state: String = ""
var bounce_vx: float = 0.0
var bounce_vy: float = 0.0
var scene: Node = null

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	wall = StaticBody2D.new()
	wall.position = Vector2(WALL_X, 600.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 800.0)
	cs.shape = rect
	wall.add_child(cs)
	root.add_child(wall)

	var packed: PackedScene = load("res://scenes/RiggedFighter.tscn")
	a = packed.instantiate()
	b = packed.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	b.is_player1 = true        # 關 P2 AI
	b._ai_cd = 9999.0
	b.set_physics_process(false)                      # 手動步進，時序可控
	b.position = Vector2(WALL_X - 60.0, 600.0)        # 背貼右牆（身體右緣 870，牆面 880）
	a.position = Vector2(WALL_X - 300.0, 600.0)
	physics_frame.connect(_on_physics)

func _on_physics() -> void:
	n += 1
	match phase:
		0:
			if n >= 2:
				# ---- A. 貼牆受擊：額外 25% 傷害 + 進黏牆 ----
				b.current_hp = 1000
				b.change_state("Idle")
				b._frame = 0
				b.take_damage(100, 1.0, 0.0)
				hp_after_wall = b.current_hp
				_check("wall hit enters WallStick", b._state == "WallStick")
				_check("wall bonus 25% (125 total)", hp_after_wall == 1000 - 125)
				_check("wall bonus recorded 25", b._wall_bonus_last == 25)
				_check("wall side is +1", b._wall_side > 0.0)
				_check("WallStick spec total 30 frames", DATA.total_frames(DATA.spec("WallStick")) == 30)
				start_y = b.position.y
				b.set_physics_process(true)
				phase = 1
		1:
			# ---- B. 黏牆中定身：每幀不位移、不因重力沉下去 ----
			if n > 80:
				_check("wall hit enters WallStick", false)
				_check("stuck exactly 30 frames", false)
				quit(1)
				phase = 3
				return
			if b._state == "WallStick":
				stuck_n += 1
				if b.position.y != start_y or absf(b.velocity.x) > 0.01 or absf(b.velocity.y) > 0.01:
					pinned_ok = false
			if b._state != "WallStick" and stuck_n > 0:
				bounce_state = b._state
				bounce_vx = b.velocity.x
				bounce_vy = b.velocity.y
				_check("stuck 30 frames (incl. entry frame)", stuck_n + 1 == 30)
				_check("stays pinned (no drift, no gravity)", pinned_ok)
				_check("after stick -> HurtAir", bounce_state == "HurtAir")
				_check("bounce away from wall (vx<0)", bounce_vx < 0.0)
				_check("bounce launches up (vy<0)", bounce_vy < 0.0)
				phase = 2
				n = 0
		2:
			if n >= 3:
				# ---- D. 中場無牆 → 正常 HurtStand ----
				b.current_hp = 800
				b.change_state("Idle")
				b._frame = 0
				b.position = Vector2(400.0, 600.0)
				b.take_damage(100, 1.0, 0.0)
				_check("mid-field hit -> HurtStand", b._state == "HurtStand")
				_check("mid-field no wall bonus", b.current_hp == 700)
				# ---- E. 貼身對手不算牆 ----
				b.current_hp = 800
				b.change_state("Idle")
				b._frame = 0
				b.position = Vector2(400.0, 600.0)
				a.set_physics_process(false)
				a.position = Vector2(462.0, 600.0)
				b.take_damage(100, 1.0, 0.0)
				_check("adjacent fighter is not a wall", b._state == "HurtStand" and b.current_hp == 700)
				# ---- F. 主場景左右邊界牆節點（結構校驗；物理行為已由前面合成牆覆蓋）----
				scene = load("res://scenes/MainRigged.tscn").instantiate()
				_check("stage has WallLeft", scene.get_node_or_null("WallLeft") is StaticBody2D)
				_check("stage has WallRight", scene.get_node_or_null("WallRight") is StaticBody2D)
				var wl: StaticBody2D = scene.get_node("WallLeft")
				var wr: StaticBody2D = scene.get_node("WallRight")
				_check("left wall at x=-20", wl.position.x == -20.0)
				_check("right wall at x=1940", wr.position.x == 1940.0)
				_check("walls on fighter layer 1", wl.collision_layer == 1 and wr.collision_layer == 1)
				var shp: RectangleShape2D = wl.get_node("WallLeftCol").shape
				var shr: RectangleShape2D = wr.get_node("WallRightCol").shape
				_check("wall spans 40x1200", shp.size == Vector2(40.0, 1200.0) and shr.size == Vector2(40.0, 1200.0))
				# 邊界在畫面內：左右牆面 x=0 / 1920，角色半身 30px，鏡頭 1920x1080 剛好收在畫面邊
				_check("left wall face x=0", wl.position.x + 20.0 == 0.0)
				_check("right wall face x=1920", wr.position.x - 20.0 == 1920.0)
				scene.free()
				print("SELFTEST wall stuck_n=", stuck_n, " hp=", hp_after_wall,
					" bounce=", bounce_state, " vx=", bounce_vx, " vy=", bounce_vy,
					" fails=", fails.size())
				quit(0 if fails.is_empty() else 1)
				phase = 5
