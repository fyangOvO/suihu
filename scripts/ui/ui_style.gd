extends RefCounted
## 1.0 Lite 共用 UI 樣式：暗墨底、殘金線、朱砂血條。
## 所有場景只取這裡的顏色／字體／StyleBox，不在各處硬寫一套。

const FONT_BODY: FontFile = preload("res://assets/fonts/LXGWWenKaiLite-Regular.ttf")
const FONT_TITLE: FontFile = preload("res://assets/fonts/MaShanZheng-Regular.ttf")

const INK := Color(0.030, 0.026, 0.022)
const INK_SOFT := Color(0.070, 0.060, 0.050)
const PAPER := Color(0.855, 0.800, 0.690)
const PAPER_DIM := Color(0.560, 0.510, 0.420)
const GOLD := Color(0.720, 0.560, 0.320)
const GOLD_DIM := Color(0.480, 0.390, 0.250)
const BLOOD := Color(0.520, 0.160, 0.125)
const BLOOD_LIGHT := Color(0.720, 0.255, 0.190)
const STEEL := Color(0.300, 0.360, 0.400)
const CINNABAR := Color(0.620, 0.180, 0.130)

static func panel_style(alpha: float = 0.84, border: Color = GOLD_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	s.border_color = Color(border.r, border.g, border.b, 0.55)
	s.set_border_width_all(1)
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	return s

static func clear_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(INK.r, INK.g, INK.b, 0.80)
	s.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	s.set_border_width_all(1)
	return s

static func add_paper(parent: Control, alpha: float = 0.055) -> void:
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	tex.noise = noise
	var grain := TextureRect.new()
	grain.name = "PaperGrain"
	grain.position = Vector2.ZERO
	grain.size = parent.size
	grain.texture = tex
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate = Color(1.0, 0.93, 0.78, alpha)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grain)
	parent.move_child(grain, 0)

static func add_corner_marks(parent: Control, length: float = 22.0, inset: float = 8.0, thickness: float = 1.0) -> void:
	var w: float = parent.size.x
	var h: float = parent.size.y
	for corner in [Vector2(inset, inset), Vector2(w - inset - length, inset), Vector2(inset, h - inset - length), Vector2(w - inset - length, h - inset - length)]:
		var horizontal := ColorRect.new()
		horizontal.position = Vector2(corner.x, corner.y)
		horizontal.size = Vector2(length, thickness)
		horizontal.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.58)
		parent.add_child(horizontal)
		var vertical := ColorRect.new()
		vertical.position = Vector2(corner.x, corner.y)
		vertical.size = Vector2(thickness, length)
		vertical.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.58)
		parent.add_child(vertical)

static func add_nine_patch(parent: Control, alpha: float = 0.44) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color(GOLD.r, GOLD.g, GOLD.b, alpha)
	for x in range(32):
		img.set_pixel(x, 0, gold)
		img.set_pixel(x, 31, gold)
		img.set_pixel(x, 3, Color(0.02, 0.018, 0.016, 0.35))
	for y in range(32):
		img.set_pixel(0, y, gold)
		img.set_pixel(31, y, gold)
		img.set_pixel(3, y, Color(0.02, 0.018, 0.016, 0.35))
	for corner in [Vector2(0, 0), Vector2(27, 0), Vector2(0, 27), Vector2(27, 27)]:
		for dx in range(5):
			for dy in range(5):
				var p := Vector2(corner.x + dx, corner.y + dy)
				if dx < 2 or dy < 2:
					img.set_pixel(int(p.x), int(p.y), Color(GOLD.r, GOLD.g, GOLD.b, minf(alpha + 0.18, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	var frame := NinePatchRect.new()
	frame.name = "NinePatchFrame"
	frame.texture = tex
	frame.patch_margin_left = 8
	frame.patch_margin_top = 8
	frame.patch_margin_right = 8
	frame.patch_margin_bottom = 8
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func bar_background() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.045, 0.040, 0.034, 0.96)
	s.border_color = Color(0.34, 0.28, 0.20, 0.62)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 1
	s.corner_radius_top_right = 1
	s.corner_radius_bottom_left = 1
	s.corner_radius_bottom_right = 1
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 2
	return s

static func bar_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(1, 0.72, 0.58, 0.34)
	s.border_width_top = 1
	s.corner_radius_top_left = 1
	s.corner_radius_top_right = 1
	s.corner_radius_bottom_left = 1
	s.corner_radius_bottom_right = 1
	return s

static func apply_label(l: Label, size: int, color: Color, title: bool = false) -> void:
	l.add_theme_font_override("font", FONT_TITLE if title else FONT_BODY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 2)

static func apply_bar(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", bar_background())
	bar.add_theme_stylebox_override("fill", bar_fill(fill))
	bar.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

static func text_rule(width: float, color: Color = GOLD_DIM) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, 0.55)
	r.size = Vector2(width, 1)
	return r

static func menu_button_styles(btn: Button, icon_kind: String = "") -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.022, 0.020, 0.62)
	normal.border_color = Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.55)
	normal.border_width_left = 2
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.content_margin_left = 52.0 if icon_kind != "" else 26.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.34, 0.085, 0.065, 0.88)
	hover.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95)

	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.20, 0.055, 0.045, 0.95)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.08, 0.065, 0.050, 0.92)
	focus.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.95)

	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.02, 0.018, 0.45)
	disabled.border_color = Color(0.26, 0.24, 0.20, 0.5)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", PAPER)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.78))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.93, 0.78))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if icon_kind != "":
		if not btn.has_node("MenuIcon"):
			add_button_icon(btn, icon_kind)
		return
	if not btn.has_node("MenuMark"):
		var mark := ColorRect.new()
		mark.name = "MenuMark"
		mark.position = Vector2(12, btn.size.y * 0.5 - 2)
		mark.size = Vector2(4, 4)
		mark.rotation = PI * 0.25
		mark.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(mark)

static func add_button_icon(btn: Button, kind: String) -> void:
	var holder := Node2D.new()
	holder.name = "MenuIcon"
	holder.position = Vector2(24, 27)
	btn.add_child(holder)
	var gold := Color(GOLD.r, GOLD.g, GOLD.b, 0.84)
	var dim := Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	match kind:
		"play":
			_icon_poly(holder, PackedVector2Array([
				Vector2(-4, -7), Vector2(7, 0), Vector2(-4, 7),
			]), gold)
		"sliders":
			for y in [-5.0, 0.0, 5.0]:
				_icon_line(holder, PackedVector2Array([
					Vector2(-6, y), Vector2(6, y),
				]), dim)
			for p in [Vector2(-2, -5), Vector2(2, 0), Vector2(-1, 5)]:
				_icon_rect(holder, p, 3.0, gold)
		"screen":
			_icon_line(holder, PackedVector2Array([
				Vector2(-7, -6), Vector2(7, -6), Vector2(7, 4),
				Vector2(-7, 4), Vector2(-7, -6),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(-3, 7), Vector2(3, 7),
			]), dim)
		"home":
			_icon_line(holder, PackedVector2Array([
				Vector2(-7, -1), Vector2(0, -8), Vector2(7, -1),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(-5, -1), Vector2(-5, 6), Vector2(5, 6),
				Vector2(5, -1),
			]), dim)
		"gate":
			_icon_line(holder, PackedVector2Array([
				Vector2(-6, -6), Vector2(6, -6),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(-4, -3), Vector2(4, -3),
			]), dim)
			_icon_line(holder, PackedVector2Array([
				Vector2(-4, -6), Vector2(-4, 6),
			]), dim)
			_icon_line(holder, PackedVector2Array([
				Vector2(4, -6), Vector2(4, 6),
			]), dim)
		"retry":
			var arc := PackedVector2Array()
			for i in range(14):
				var a: float = -0.7 + 4.9 * float(i) / 13.0
				arc.append(Vector2(cos(a) * 6.0, sin(a) * 6.0))
			_icon_line(holder, arc, gold)
			_icon_poly(holder, PackedVector2Array([
				Vector2(4, -7), Vector2(9, -4), Vector2(4, -1),
			]), gold)
		"new":
			_icon_line(holder, PackedVector2Array([
				Vector2(-6, 0), Vector2(6, 0),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(0, -6), Vector2(0, 6),
			]), gold)
		"back":
			_icon_line(holder, PackedVector2Array([
				Vector2(-3, -6), Vector2(-8, 0), Vector2(-3, 6),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(-8, 0), Vector2(6, 0),
			]), dim)
		"quit":
			_icon_line(holder, PackedVector2Array([
				Vector2(-5, -5), Vector2(5, 5),
			]), gold)
			_icon_line(holder, PackedVector2Array([
				Vector2(5, -5), Vector2(-5, 5),
			]), gold)
		"skip":
			_icon_poly(holder, PackedVector2Array([
				Vector2(-6, -6), Vector2(1, 0), Vector2(-6, 6),
			]), dim)
			_icon_poly(holder, PackedVector2Array([
				Vector2(1, -6), Vector2(8, 0), Vector2(1, 6),
			]), gold)
		_:
			_icon_rect(holder, Vector2(-2, -2), 4.0, gold)

static func _icon_line(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = 1.6
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)

static func _icon_poly(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	parent.add_child(poly)

static func _icon_rect(parent: Node2D, center: Vector2, radius: float, color: Color) -> void:
	_icon_poly(parent, PackedVector2Array([
		center + Vector2(-radius, -radius),
		center + Vector2(radius, -radius),
		center + Vector2(radius, radius),
		center + Vector2(-radius, radius),
	]), color)
