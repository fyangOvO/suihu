extends "res://scripts/chapters/stage_base.gd"
## SCN-03 亂林：B5 吊睛小虎精英戰。
## 三層霧（遠／中／近）＋林影，全部程序化生成，直接掛在背景下，保證在角色之前、HUD 之後。

const FOREST_INK := Color(0.035, 0.050, 0.043, 0.88)
const FOREST_INK_2 := Color(0.050, 0.072, 0.060, 0.78)

const FOG_TRAVEL := 480.0

var _fog_layers: Array[TextureRect] = []
var _fog_speeds: Array[float] = []

func scene_id() -> String:
	return "SCN-03"

func scene_title() -> String:
	return "亂林"

func first_beat() -> String:
	return "B5"

func background_texture_path() -> String:
	return "res://assets/stage-jingyang.png"

func opponent_scene_path() -> String:
	return "res://scenes/Tiger.tscn"

func opponent_display_name() -> String:
	return "吊睛小虎"

func _on_stage_start() -> void:
	_build_fog()
	show_banner("霧裡，低吼。", 2.0)

func _tick_stage(_delta: float) -> void:
	for i in range(_fog_layers.size()):
		var layer := _fog_layers[i]
		if not is_instance_valid(layer):
			continue
		layer.position.x -= _fog_speeds[i] * _delta
		if layer.position.x <= -FOG_TRAVEL:
			layer.position.x = 0.0
	if p2 != null and p2.current_hp <= 0 and p2._death_done:
		_finish_to("B6", 2.0, "小虎倒了，霧散了。")

func _build_fog() -> void:
	var bg := get_node_or_null("Background")
	if bg == null:
		return
	if bg.get_node_or_null("FogFar") != null:
		return

	# 林影：先壓暗背景，再用邊緣樹幹與頂部枝冠把「山道」變成「亂林」。
	if bg is CanvasItem:
		(bg as CanvasItem).modulate = Color(0.68, 0.74, 0.68, 1.0)
	_add_trunks(bg)
	_add_canopy(bg)

	# 遠／中／近三層霧：不同噪聲與速度，形成真正的霧帶，而不是平鋪方塊。
	_add_fog_layer(bg, "FogFar", 0.006, 30.0, 180.0, 240.0, Color(0.62, 0.70, 0.66, 0.34))
	_add_fog_layer(bg, "FogMid", 0.010, 55.0, 390.0, 280.0, Color(0.64, 0.72, 0.68, 0.28))
	_add_fog_layer(bg, "FogNear", 0.016, 86.0, 650.0, 320.0, Color(0.68, 0.76, 0.72, 0.22))

func _add_fog_layer(parent: Node, node_name: String, frequency: float, speed: float, y: float, height: float, tint: Color) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(speed * 13.0 + frequency * 1000.0)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var img := Image.create(512, 128, false, Image.FORMAT_RGBA8)
	for py in range(128):
		var envelope: float = 1.0 - abs(float(py) / 127.0 * 2.0 - 1.0)
		envelope = clampf(envelope * 1.5, 0.0, 1.0)
		for px in range(512):
			var n := noise.get_noise_2d(px, py)
			var a := clampf((n + 0.55) * 0.9, 0.0, 1.0)
			img.set_pixel(px, py, Color(tint.r, tint.g, tint.b, a * envelope * 0.72))
	var tex := ImageTexture.create_from_image(img)

	var layer := TextureRect.new()
	layer.name = node_name
	layer.position = Vector2(-80, y)
	layer.size = Vector2(2400, height)
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.modulate = Color(1.0, 1.0, 1.0, tint.a)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	_fog_layers.append(layer)
	_fog_speeds.append(speed)

func _add_trunks(parent: Node) -> void:
	for item in [
		Vector2(92, 0), Vector2(210, 0), Vector2(1710, 0), Vector2(1830, 0),
		Vector2(360, 0), Vector2(1560, 0),
	]:
		var trunk := Polygon2D.new()
		trunk.name = "Trunk%d" % int(item.x)
		trunk.polygon = PackedVector2Array([
			Vector2(item.x, 900), Vector2(item.x + 34, 900),
			Vector2(item.x + 26, 310), Vector2(item.x + 12, 210),
			Vector2(item.x - 4, 310),
		])
		trunk.color = FOREST_INK
		parent.add_child(trunk)

func _add_canopy(parent: Node) -> void:
	for item in [
		Vector2(0, 0), Vector2(280, 0), Vector2(570, 0),
		Vector2(1390, 0), Vector2(1670, 0), Vector2(1910, 0),
	]:
		var crown := Polygon2D.new()
		crown.name = "Crown%d" % int(item.x)
		crown.polygon = PackedVector2Array([
			Vector2(item.x - 90, 0), Vector2(item.x + 120, 0),
			Vector2(item.x + 86, 52), Vector2(item.x + 42, 88),
			Vector2(item.x - 12, 60), Vector2(item.x - 58, 104),
			Vector2(item.x - 122, 44),
		])
		crown.color = FOREST_INK_2
		parent.add_child(crown)
