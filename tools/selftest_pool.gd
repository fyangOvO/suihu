extends SceneTree
## OPT-04 物件池無頭自測：
##  A. 池基本行為：首次新建、歸還入池、再次取用復用同一個實例、統計計數
##  B. 容量上限：同時歸還超過上限時多餘的真的釋放（dropped）
##  C. 石頭：setup 歸零、落地回收而非 queue_free、無池時退回直接釋放
##  D. 青煙：SpriteFrames 全場只建一次（跨實例共用）、節點每具敵人固定一格、收起後可重播
## 用法：godot --headless --path <game> --script res://tools/selftest_pool.gd
## PASS 退出 0；FAIL 退出 1。

const POOL_SCRIPT := preload("res://scripts/object_pool.gd")
const ROCK_SCRIPT := preload("res://scripts/rock_projectile.gd")
const FIGHTER_SCENE := preload("res://scenes/RiggedFighter.tscn")
const FIGHTER_SCRIPT := preload("res://scripts/rigged_fighter.gd")

var fails: Array = []
var checks: int = 0
var stage: int = 0
var frame: int = 0

var world: Node2D
var pool: Node
var rock: Node2D
var rock_id: int = 0
var f1: Node
var f2: Node

func _check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails.append(name)
	print("CHECK ", name, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	world = Node2D.new()
	world.name = "World"
	root.add_child(world)
	pool = Node.new()
	pool.name = "ObjectPool"
	pool.set_script(POOL_SCRIPT)
	world.add_child(pool)
	rock = pool.acquire("rock", func() -> Node: return ROCK_SCRIPT.new(), world)
	rock_id = rock.get_instance_id()

func _process(_delta: float) -> bool:
	frame += 1
	match stage:
		0:
			if frame >= 3:
				_check_pool_basic()
				_check_pool_capacity()
				_check_rock()
				f1 = FIGHTER_SCENE.instantiate()
				f1.name = "F1"
				world.add_child(f1)
				f2 = FIGHTER_SCENE.instantiate()
				f2.name = "F2"
				world.add_child(f2)
				stage = 1
				frame = 0
		1:
			if frame >= 3:
				_check_mist()
				_finish()
				return true
	return false

# --- A. 池基本行為 ---

func _check_pool_basic() -> void:
	var st: Dictionary = pool.stats("rock")
	_check("pool script loaded", pool.get_script() == POOL_SCRIPT)
	_check("first acquire creates one", int(st["created"]) == 1)
	_check("first acquire live 1", int(st["live"]) == 1)
	_check("first acquire reused 0", int(st["reused"]) == 0)
	_check("acquired rock parented to world", rock.get_parent() == world)
	_check("acquired rock visible", rock.visible)

	pool.release("rock", rock)
	var after: Dictionary = pool.stats("rock")
	_check("release counts once", int(after["released"]) == 1)
	_check("release live 0", int(after["live"]) == 0)
	_check("release parks one idle", pool.idle_count("rock") == 1)
	_check("released rock parented to pool", rock.get_parent() == pool)
	_check("released rock hidden", not rock.visible)

	var again: Node2D = pool.acquire("rock", func() -> Node: return ROCK_SCRIPT.new(), world)
	_check("second acquire reuses instance", again.get_instance_id() == rock_id)
	_check("second acquire creates nothing", int(pool.stats("rock")["created"]) == 1)
	_check("second acquire counts reuse", int(pool.stats("rock")["reused"]) == 1)
	_check("reused rock visible", again.visible)
	_check("reused rock back on world", again.get_parent() == world)

	for i in 20:
		pool.release("rock", again)
		again = pool.acquire("rock", func() -> Node: return ROCK_SCRIPT.new(), world)
	var loop: Dictionary = pool.stats("rock")
	_check("20 cycles create only one node", int(loop["created"]) == 1)
	_check("20 cycles all reuse", int(loop["reused"]) == 21)
	pool.release("rock", again)

# --- B. 容量上限 ---

func _check_pool_capacity() -> void:
	var batch: Array = []
	for i in 5:
		batch.append(pool.acquire("cap", func() -> Node: return Node2D.new(), world))
	for n in batch:
		pool.release("cap", n)
	var st: Dictionary = pool.stats("cap")
	_check("idle capped at 3", pool.idle_count("cap") == POOL_SCRIPT.MAX_IDLE_PER_KEY)
	_check("created 5 for cap probe", int(st["created"]) == 5)
	_check("released 3 kept", int(st["released"]) == 3)
	_check("overflow dropped 2", int(st["dropped"]) == 2)

# --- C. 石頭回收 ---

func _check_rock() -> void:
	var r: Node2D = pool.acquire("rock", func() -> Node: return ROCK_SCRIPT.new(), world)
	r.setup(null, -1.0, 75, Vector2(700.0, 500.0))
	_check("setup resets age", is_equal_approx(r.age, 0.0))
	_check("setup sets flight time in range", r.flight_time >= 0.55 and r.flight_time <= 1.5)
	_check("setup throws toward dir", r.velocity.x < 0.0)
	_check("setup places rock", r.position == Vector2(700.0, 500.0))

	# 手動推進一段，確認 age 會累加但圖形不必逐幀重繪
	r._physics_process(0.5)
	_check("rock ages while flying", r.age > 0.45)
	# 丟到地上：應回收進池，而不是 queue_free
	r.position.y = ROCK_SCRIPT.FLOOR_Y - ROCK_SCRIPT.RADIUS + 40.0
	r._physics_process(0.0)
	var st: Dictionary = pool.stats("rock")
	_check("floor hit releases instead of freeing", not r.is_queued_for_deletion())
	_check("floor hit parks in pool", r.get_parent() == pool)
	_check("floor hit live drops", int(st["live"]) == 0)
	_check("floor hit hidden", not r.visible)

	r = pool.acquire("rock", func() -> Node: return ROCK_SCRIPT.new(), world)
	r.setup(null, 1.0, 75, Vector2(300.0, 500.0))
	_check("reused rock starts fresh", is_equal_approx(r.age, 0.0) and is_equal_approx(r.rotation, 0.0))

	# 無池退回：直接 new 的石頭收尾時真的排隊刪除
	var lone: Node2D = ROCK_SCRIPT.new()
	world.add_child(lone)
	lone.setup(null, 1.0, 75, Vector2(300.0, 500.0))
	lone.position.y = ROCK_SCRIPT.FLOOR_Y - ROCK_SCRIPT.RADIUS + 40.0
	lone._physics_process(0.0)
	_check("no pool falls back to queue_free", lone.is_queued_for_deletion())
	pool.release("rock", r)

# --- D. 青煙快取與重用 ---

func _check_mist() -> void:
	_check("mist absent before death", f1._mist_node == null)
	f1._spawn_death_mist()
	var mist: AnimatedSprite2D = f1._mist_node
	_check("mist node created once", mist != null and mist.get_parent() == f1)
	_check("mist frames 6", mist.sprite_frames.get_frame_count("mist") == 6)
	_check("mist 9fps non looping",
		is_equal_approx(mist.sprite_frames.get_animation_speed("mist"), 9.0)
		and not mist.sprite_frames.get_animation_loop("mist"))
	_check("mist anchored above feet", mist.position == Vector2(0.0, -288.0))
	_check("mist behind body", mist.z_index == 1)

	var first_frames: SpriteFrames = mist.sprite_frames
	f1._free_mist()
	_check("mist hides instead of freeing", not mist.is_queued_for_deletion() and is_instance_valid(mist))
	_check("mist hidden after collect", not mist.visible)

	f1._spawn_death_mist()
	_check("mist reused on next death", f1._mist_node.get_instance_id() == mist.get_instance_id())
	_check("mist visible again", mist.visible)

	f2._spawn_death_mist()
	_check("second fighter shares frames", f2._mist_node.sprite_frames == first_frames)
	_check("second fighter gets own node", f2._mist_node.get_instance_id() != mist.get_instance_id())
	_check("frames cache single instance", FIGHTER_SCRIPT._mist_sprite_frames() == first_frames)

# --- 收尾 ---

func _finish() -> void:
	if fails.is_empty():
		print("POOL_SELFTEST result=PASS fails=[] checks=", checks)
		quit(0)
	else:
		print("POOL_SELFTEST result=FAIL fails=", fails, " checks=", checks)
		quit(1)
