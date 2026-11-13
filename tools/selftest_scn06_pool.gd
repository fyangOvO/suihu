extends SceneTree
## SCN-06 水潭倒影與虎屍剪影自測。

const SCN06 := "res://scenes/chapters/SCN_06_Pool.tscn"

var main: Node
var fails: Array[String] = []
var frame: int = 0
var surface_alpha_before: float = 0.0
var mist_x_before: float = 0.0
var mirror_alpha_before: float = 0.0

func _check(label: String, ok: bool) -> void:
	if not ok:
		fails.append(label)
	print("CHECK ", label, " = ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	root.size = Vector2i(1, 1)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var cm = load("res://scripts/chapter_manager.gd").new()
	cm.name = "ChapterManager"
	root.add_child(cm)
	cm.set_beat("B8")
	main = load(SCN06).instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if frame == 5:
		var bg := main.get_node_or_null("Background")
		_check("Background exists", bg != null)
		if bg == null:
			quit(0)
			return true
		_check("Water exists", bg.get_node_or_null("Water") != null)
		_check("water surface/deep bands exist", bg.get_node_or_null("WaterSurface") != null and bg.get_node_or_null("WaterDeep") != null)
		_check("Moon exists", bg.get_node_or_null("Moon") != null)
		_check("moon reflection exists", bg.get_node_or_null("MoonReflection0") != null)
		_check("moon reflection is broken into nine strips", bg.get_node_or_null("MoonReflection8") != null)
		_check("wide moon reflection exists", bg.get_node_or_null("MoonReflectionWide") != null)
		_check("moon reflection glow exists", bg.get_node_or_null("MoonReflectionGlow") != null)
		_check("far ridge and pool mist exist", bg.get_node_or_null("FarRidge") != null and bg.get_node_or_null("PoolMist") != null)
		_check("tiger body exists", bg.get_node_or_null("TigerBody") != null)
		_check("tiger head exists", bg.get_node_or_null("TigerHead") != null)
		_check("tiger tail exists", bg.get_node_or_null("TigerTail") != null)
		_check("tiger spine/head rim exist", bg.get_node_or_null("TigerSpine") != null and bg.get_node_or_null("TigerHeadRim") != null)
		_check("tiger legs and paws exist", bg.get_node_or_null("TigerLeg42") != null and bg.get_node_or_null("TigerPaw202") != null)
		_check("tiger ribs and blood exist", bg.get_node_or_null("TigerRib0") != null and bg.get_node_or_null("TigerBlood") != null)
		_check("tiger face details exist", bg.get_node_or_null("TigerNose") != null and bg.get_node_or_null("TigerFang278") != null)
		_check("tiger stripes exist", bg.get_node_or_null("TigerStripe120") != null and bg.get_node_or_null("TigerStripe168") != null)
		_check("tiger reflection exists", bg.get_node_or_null("TigerReflection") != null)
		_check("tiger reflection has body", bg.get_node_or_null("TigerReflection/RBody") != null)
		_check("tiger reflection has rim", bg.get_node_or_null("TigerReflection/RHeadRim") != null)
		_check("tiger reflection has legs", bg.get_node_or_null("TigerReflection/RLeg42") != null and bg.get_node_or_null("TigerReflection/RPaw202") != null)
		_check("tiger reflection ripples exist", bg.get_node_or_null("TigerReflectionRipple0") != null and bg.get_node_or_null("TigerReflectionRipple3") != null)
		var mirror := bg.get_node_or_null("TigerReflection") as Node2D
		_check("reflection is flattened", mirror != null and mirror.scale.y <= -0.40)
		var mirror_body := bg.get_node_or_null("TigerReflection/RBody") as Polygon2D
		_check("reflection body is readable", mirror_body != null and mirror_body.color.a >= 0.50)
		var pool_reflection := bg.get_node_or_null("PoolReflection") as Node2D
		_check("player reflection exists", pool_reflection != null)
		_check("player reflection starts human", pool_reflection != null and bg.get_node_or_null("PoolReflection/PlayerHumanReflection").visible and not bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection").visible)
		_check("white tiger reflection is built", bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection/WhiteTigerBody") != null and bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection/WhiteRobe") != null and bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection/WhiteTigerPaw") != null)
		_check("white tiger reflection has head rim", bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection/WhiteTigerHeadRim") != null)
		_check("reflection flash exists", bg.get_node_or_null("ReflectionFlash") != null)
		main._reveal_white_tiger_reflection()
		_check("reflection switches to white tiger", main._reflection_changed and not bg.get_node_or_null("PoolReflection/PlayerHumanReflection").visible and bg.get_node_or_null("PoolReflection/PlayerWhiteTigerReflection").visible)
		main._reveal_white_tiger_reflection()
		_check("reflection switch is idempotent", main._reflection_changed)
		var surface := bg.get_node_or_null("WaterSurface") as ColorRect
		var mist := bg.get_node_or_null("PoolMist") as Node2D
		var mirror_alpha_root := bg.get_node_or_null("TigerReflection") as Node2D
		main._tick_stage(0.25)
		surface_alpha_before = surface.modulate.a if surface != null else 0.0
		mist_x_before = mist.position.x if mist != null else 0.0
		mirror_alpha_before = mirror_alpha_root.modulate.a if mirror_alpha_root != null else 0.0
		main._tick_stage(0.70)
		_check("water surface alpha breathes", surface != null and absf(surface.modulate.a - surface_alpha_before) > 0.0005)
		_check("pool mist drifts", mist != null and absf(mist.position.x - mist_x_before) > 0.001)
		_check("tiger reflection alpha breathes", mirror_alpha_root != null and absf(mirror_alpha_root.modulate.a - mirror_alpha_before) > 0.0005)
		print("SCN06_POOL_SELFTEST result=", "PASS" if fails.is_empty() else "FAIL", " fails=", fails)
		quit(0)
		return true
	return false
