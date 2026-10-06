class_name UITheme
extends RefCounted
## Builds the shared UI theme in code (no external fonts or images).

const BG := Color(0.07, 0.09, 0.12)
const PANEL := Color(0.11, 0.14, 0.19, 0.94)
const ACCENT := Color(1.0, 0.8, 0.25)
const ACCENT2 := Color(0.35, 0.75, 1.0)
const TEXT := Color(0.95, 0.96, 0.98)
const MUTED := Color(0.65, 0.7, 0.78)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 3)
	t.set_stylebox("normal", "Button", _box(Color(0.16, 0.2, 0.27), Color(0.3, 0.38, 0.5)))
	t.set_stylebox("hover", "Button", _box(Color(0.2, 0.26, 0.35), ACCENT2))
	t.set_stylebox("pressed", "Button", _box(Color(0.28, 0.24, 0.12), ACCENT))
	t.set_stylebox("focus", "Button", _box(Color(0.2, 0.26, 0.35, 0.0), ACCENT, 3))
	t.set_stylebox("disabled", "Button", _box(Color(0.12, 0.13, 0.15), Color(0.22, 0.24, 0.28)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.5))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.7))
	t.set_constant("outline_size", "Button", 3)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.25, 0.3, 0.4), 2, 14))
	t.set_stylebox("panel", "Panel", _box(PANEL, Color(0.25, 0.3, 0.4), 2, 14))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.1, 0.12, 0.16), Color(0.3, 0.36, 0.46)))
	var grabber := _box(ACCENT, ACCENT, 0, 10)
	t.set_stylebox("slider", "HSlider", _box(Color(0.18, 0.2, 0.26), Color(0.18, 0.2, 0.26), 0, 6))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT2, ACCENT2, 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color(0.25, 0.3, 0.4), 2, 10))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "OptionButton", _box(Color(0.16, 0.2, 0.27), Color(0.3, 0.38, 0.5)))
	t.set_stylebox("hover", "OptionButton", _box(Color(0.2, 0.26, 0.35), ACCENT2))
	t.set_stylebox("pressed", "OptionButton", _box(Color(0.28, 0.24, 0.12), ACCENT))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", TEXT)
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int = 2, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


static func make_button(text: String, min_size: Vector2 = Vector2(280, 64), font_size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func(): Audio.play("ui"))
	return b


static func make_label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func portrait_texture(def: PokemonDef, form_id: String = "") -> Texture2D:
	var f := def.get_form(form_id)
	if f and f.portrait != "" and ResourceLoader.exists(f.portrait):
		return load(f.portrait)
	return null


## Root control filling the screen with the background colour.
static func screen_root(owner_control: Control) -> void:
	owner_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner_control.theme = get_theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_control.add_child(bg)
