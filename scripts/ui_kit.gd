class_name UiKit
extends RefCounted
## One theme for every screen: navy glass panels with a cyan rim, orange action buttons,
## Russo One headings, Rubik body text (both cover Cyrillic).

const NAVY := Color(0.03, 0.09, 0.15, 0.86)
const CYAN := Color(0.3, 0.95, 1.0)
const ORANGE := Color(1.0, 0.45, 0.1)
const RED := Color(1.0, 0.3, 0.22)
const TEXT := Color(0.93, 0.97, 1.0)

static var _theme: Theme
static var head_font: Font
static var body_font: Font


static func theme() -> Theme:
	if _theme:
		return _theme
	head_font = load("res://assets/fonts/RussoOne-Regular.ttf")
	var rubik: FontFile = load("res://assets/fonts/Rubik.ttf")
	var fv := FontVariation.new()
	fv.base_font = rubik
	fv.variation_opentype = {"wght": 500}
	body_font = fv
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button_box(state))
	t.set_font("font", "Button", head_font)
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.65, 0.7))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0.03, 0.06, 0.9))
	t.set_constant("outline_size", "Label", 6)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.0, 0.05, 0.1, 0.9)
	le.border_color = CYAN
	le.set_border_width_all(2)
	le.set_corner_radius_all(10)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_font_size("font_size", "LineEdit", 26)
	var grab := StyleBoxFlat.new()
	grab.bg_color = ORANGE
	grab.set_corner_radius_all(8)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.1, 0.2, 0.28)
	sl.set_corner_radius_all(6)
	sl.content_margin_top = 6
	sl.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", sl)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t


static func panel_box(alpha := 0.86) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(NAVY.r, NAVY.g, NAVY.b, alpha)
	s.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.55)
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 14
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


static func button_box(state: String, accent := ORANGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var base := accent
	match state:
		"hover":
			base = accent.lightened(0.15)
		"pressed":
			base = accent.darkened(0.2)
		"disabled":
			base = Color(0.25, 0.3, 0.35)
		"focus":
			s.draw_center = false
			s.border_color = Color(1, 1, 1, 0.7)
			s.set_border_width_all(2)
			s.set_corner_radius_all(14)
			return s
	s.bg_color = base
	s.border_color = base.lightened(0.35)
	s.border_width_top = 2
	s.border_width_bottom = 4
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_color = base.darkened(0.35)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	return s


static func button(text: String, cb: Callable, accent := ORANGE, min_w := 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 58)
	if accent != ORANGE:
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, button_box(state, accent))
	b.pressed.connect(func():
		Sfx.play("click", 0.6)
		cb.call()
	)
	b.mouse_entered.connect(func(): Sfx.play("hover", 0.25))
	return b


static func toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := button(text, cb, CYAN.darkened(0.45) if not on else ORANGE, 150)
	b.custom_minimum_size = Vector2(150, 50)
	b.add_theme_font_size_override("font_size", 20)
	return b


static func label(text: String, size := 22, color := TEXT, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heading:
		theme()
		l.add_theme_font_override("font", head_font)
	return l


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	return p


## Anchor a control to a preset with a margin (offsets, not .position: survives resizes).
static func place(c: Control, preset: int, margin := Vector2.ZERO) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT]:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER]:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	match preset:
		Control.PRESET_TOP_LEFT:
			c.offset_left += margin.x
			c.offset_top += margin.y
			c.offset_right += margin.x
			c.offset_bottom += margin.y
		Control.PRESET_TOP_RIGHT:
			c.offset_left -= margin.x
			c.offset_right -= margin.x
			c.offset_top += margin.y
			c.offset_bottom += margin.y
		Control.PRESET_BOTTOM_LEFT:
			c.offset_left += margin.x
			c.offset_right += margin.x
			c.offset_top -= margin.y
			c.offset_bottom -= margin.y
		Control.PRESET_BOTTOM_RIGHT:
			c.offset_left -= margin.x
			c.offset_right -= margin.x
			c.offset_top -= margin.y
			c.offset_bottom -= margin.y
		Control.PRESET_CENTER_TOP:
			c.offset_top += margin.y
			c.offset_bottom += margin.y
		Control.PRESET_CENTER_BOTTOM:
			c.offset_top -= margin.y
			c.offset_bottom -= margin.y
