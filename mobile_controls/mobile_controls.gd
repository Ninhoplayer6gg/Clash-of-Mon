class_name MobileControls
extends Control
## Touch controls drawn in a single Control (no per-button nodes):
##  - left: floating virtual joystick (appears where the thumb lands)
##  - right: basic attack, 3 skills, ultimate, dash (+ mega when available)
## Skills support three aim styles at once:
##  - tap: quick cast with auto-aim (nearest enemy / facing)
##  - drag from the button: manual aim with a world preview, cast on release
##    (drag back to the centre to cancel)
##  - basic attack: hold to keep firing, drag to fire in a direction
## Multi-touch is tracked per finger index. With no touchscreen, the mouse
## emulates one finger so the layout can be tested on desktop.

signal pause_pressed

const JOY_RADIUS := 70.0
const DRAG_DEADZONE := 18.0
const AIM_MAX := 90.0

var fighter: Fighter
## Outputs read by PlayerController each physics tick.
var move_vector := Vector2.ZERO
var requests: Array = []  # [slot, aim_vec, strength]
var dash_requested := false
var mega_requested := false
var aim_slot := ""
var aim_vector := Vector2.ZERO
var aim_strength := 1.0
var basic_held := false
var basic_aim := Vector2.ZERO

var _buttons: Array = []  # {slot, center, radius}
var _joy_touch := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _joy_rest := Vector2.ZERO
var _touches := {}  # index -> {slot, start, pos, dragged}
var _font: Font
var _scale := 1.0
var _use_mouse := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_use_mouse = not DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(_layout)
	_layout()


func _layout() -> void:
	_scale = Settings.controls_scale
	var vs := get_viewport_rect().size
	var s := _scale
	var a := Vector2(vs.x - 128.0 * s, vs.y - 112.0 * s)
	_buttons = [
		{"slot": "basic", "center": a, "radius": 54.0 * s},
		{"slot": "skill1", "center": a + Vector2.from_angle(deg_to_rad(182)) * 116.0 * s, "radius": 38.0 * s},
		{"slot": "skill2", "center": a + Vector2.from_angle(deg_to_rad(226)) * 116.0 * s, "radius": 38.0 * s},
		{"slot": "skill3", "center": a + Vector2.from_angle(deg_to_rad(270)) * 116.0 * s, "radius": 38.0 * s},
		{"slot": "ult", "center": a + Vector2.from_angle(deg_to_rad(206)) * 205.0 * s, "radius": 42.0 * s},
		{"slot": "dash", "center": a + Vector2.from_angle(deg_to_rad(318)) * 104.0 * s, "radius": 32.0 * s},
		{"slot": "mega", "center": a + Vector2.from_angle(deg_to_rad(246)) * 215.0 * s, "radius": 28.0 * s},
	]
	_joy_rest = Vector2(150.0 * s, vs.y - 140.0 * s)
	if _joy_touch < 0:
		_joy_base = _joy_rest
		_joy_knob = _joy_rest
	queue_redraw()


func reset_state() -> void:
	_touches.clear()
	_joy_touch = -1
	move_vector = Vector2.ZERO
	aim_slot = ""
	basic_held = false
	requests.clear()
	_joy_base = _joy_rest
	_joy_knob = _joy_rest


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif _use_mouse and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_down(0, event.position)
		else:
			_touch_up(0, event.position)
	elif _use_mouse and event is InputEventMouseMotion and (_touches.has(0) or _joy_touch == 0):
		_touch_move(0, event.position)


func _button_at(p: Vector2) -> Dictionary:
	for b in _buttons:
		if not _button_enabled(b["slot"]):
			continue
		# Generous hit area: thumbs are imprecise.
		if p.distance_to(b["center"]) <= b["radius"] * 1.18:
			return b
	return {}


func _button_enabled(slot: String) -> bool:
	if slot == "mega":
		return fighter != null and fighter.mega_enabled and not fighter.mega_used
	return true


func _touch_down(index: int, p: Vector2) -> void:
	var vs := get_viewport_rect().size
	var b := _button_at(p)
	if not b.is_empty():
		var slot: String = b["slot"]
		if slot == "dash":
			dash_requested = true
			_touches[index] = {"slot": "dash", "start": b["center"], "pos": p, "dragged": false}
		elif slot == "mega":
			mega_requested = true
			_touches[index] = {"slot": "mega", "start": b["center"], "pos": p, "dragged": false}
		else:
			_touches[index] = {"slot": slot, "start": b["center"], "pos": p, "dragged": false}
			if slot == "basic":
				basic_held = true
				basic_aim = Vector2.ZERO
				requests.append(["basic", Vector2.ZERO, 1.0])
		accept_event_safe()
		queue_redraw()
		return
	# Joystick zone: left part of the screen, below the HUD strip.
	if _joy_touch < 0 and p.x < vs.x * 0.48 and p.y > vs.y * 0.22:
		_joy_touch = index
		_joy_base = p
		_joy_knob = p
		move_vector = Vector2.ZERO
		accept_event_safe()
		queue_redraw()


func _touch_move(index: int, p: Vector2) -> void:
	if index == _joy_touch:
		var d := p - _joy_base
		var r := JOY_RADIUS * _scale
		if d.length() > r:
			# Joystick follows the thumb when dragged past its edge.
			_joy_base = p - d.normalized() * r
			d = p - _joy_base
		_joy_knob = _joy_base + d
		move_vector = d / r
		if move_vector.length() < 0.12:
			move_vector = Vector2.ZERO
		queue_redraw()
		return
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	t["pos"] = p
	var d: Vector2 = p - t["start"]
	if d.length() > DRAG_DEADZONE * _scale:
		t["dragged"] = true
	var slot: String = t["slot"]
	if slot == "dash" or slot == "mega":
		return
	if t["dragged"]:
		var v := d / (AIM_MAX * _scale)
		if slot == "basic":
			basic_aim = v.normalized() if v.length() > 0.05 else Vector2.ZERO
			aim_slot = "basic"
			aim_vector = basic_aim
			aim_strength = 1.0
		else:
			aim_slot = slot
			aim_vector = v.limit_length(1.0)
			aim_strength = clampf(v.length(), 0.0, 1.0)
	queue_redraw()


func _touch_up(index: int, p: Vector2) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		move_vector = Vector2.ZERO
		_joy_base = _joy_rest
		_joy_knob = _joy_rest
		queue_redraw()
		return
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	_touches.erase(index)
	var slot: String = t["slot"]
	match slot:
		"basic":
			basic_held = false
			basic_aim = Vector2.ZERO
		"dash", "mega":
			pass
		_:
			var d: Vector2 = p - t["start"]
			if not t["dragged"]:
				requests.append([slot, Vector2.ZERO, 1.0])
			elif d.length() > DRAG_DEADZONE * _scale:
				var v := d / (AIM_MAX * _scale)
				requests.append([slot, v.normalized(), clampf(v.length(), 0.0, 1.0)])
			# else: dragged out and back to the centre = cancel
	if aim_slot == slot:
		aim_slot = ""
		aim_vector = Vector2.ZERO
	queue_redraw()


func accept_event_safe() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func pop_requests() -> Array:
	var r := requests.duplicate()
	requests.clear()
	return r


# ---------------------------------------------------------------- drawing

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var op := Settings.controls_opacity
	# Joystick
	var jr := JOY_RADIUS * _scale
	var active := _joy_touch >= 0
	draw_circle(_joy_base, jr, Color(0, 0, 0, 0.22 * op if active else 0.12 * op))
	draw_arc(_joy_base, jr, 0, TAU, 40, Color(1, 1, 1, 0.45 * op if active else 0.22 * op), 2.0)
	draw_circle(_joy_knob, jr * 0.42, Color(1, 1, 1, 0.55 * op if active else 0.25 * op))
	if fighter == null:
		return
	for b in _buttons:
		_draw_button(b, op)


func _draw_button(b: Dictionary, op: float) -> void:
	var slot: String = b["slot"]
	if not _button_enabled(slot):
		return
	var c: Vector2 = b["center"]
	var r: float = b["radius"]
	var pressed := false
	for t in _touches.values():
		if t["slot"] == slot:
			pressed = true
	var base := Color(0.08, 0.1, 0.14, 0.55 * op)
	var ring := Color(1, 1, 1, 0.7 * op)
	var label := ""
	var ready := true
	var cd := 0.0
	var ab: AbilityDef = null
	match slot:
		"dash":
			label = "»"
			cd = fighter.dash_cd / maxf(fighter._dash_cfg("cooldown", 0.55), 0.01)
			ready = fighter.dash_cd <= 0.0 and fighter.energy >= fighter._dash_cfg("energy_cost", 30.0)
			ring = Color(0.6, 0.95, 1.0, 0.8 * op)
		"mega":
			label = "M"
			ready = fighter.can_mega()
			ring = Color(0.6, 1.0, 0.9, 0.9 * op)
			cd = 1.0 - fighter.mega_charge / 100.0
		_:
			ab = fighter.ability(slot)
			if ab == null:
				return
			label = ab.icon
			ring = GameData.type_color(ab.move_type)
			ring.a = 0.9 * op
			cd = fighter.cooldown_ratio(slot)
			ready = fighter.is_ready(slot)
	if pressed:
		base = Color(0.25, 0.3, 0.4, 0.75 * op)
	draw_circle(c, r, base)
	if slot == "ult":
		var charge := fighter.ult_charge / 100.0
		draw_arc(c, r + 3.0, -PI / 2, -PI / 2 + TAU * charge, 40, Color(1.0, 0.85, 0.2, 0.95 * op), 4.0)
		if charge >= 1.0:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_circle(c, r, Color(1.0, 0.85, 0.2, 0.18 * pulse * op))
	if cd > 0.0 and slot != "ult":
		_draw_pie(c, r, cd, Color(0, 0, 0, 0.55 * op))
	draw_arc(c, r, 0, TAU, 40, ring if ready else Color(0.6, 0.6, 0.6, 0.5 * op), 2.5)
	var fs := int(r * 0.62)
	var col := Color(1, 1, 1, op) if ready else Color(0.7, 0.7, 0.7, 0.6 * op)
	# v0.2 polish: procedural skill icon tinted by move type (text = fallback).
	var shape := _icon_shape(slot, ab)
	if shape != "":
		var ic := Color(0.75, 0.97, 1.0) if slot == "dash" else SkillIcons.icon_color(ab.move_type)
		ic = Color(ic, op) if ready else Color(ic.lerp(Color(0.55, 0.55, 0.58), 0.65), 0.7 * op)
		SkillIcons.draw_icon(self, shape, c, r * (0.98 if slot == "basic" else 1.12), ic)
	else:
		var sz := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(_font, c + Vector2(-sz.x * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * op))
		draw_string(_font, c + Vector2(-sz.x * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if ab and slot != "basic":
		var secs: float = fighter.cooldowns.get(slot, 0.0)
		if secs > 0.0:
			var txt := "%.1f" % secs if secs < 1.0 else str(int(ceil(secs)))
			var fs2 := int(r * 0.42)
			draw_string_outline(_font, c + Vector2(-r * 0.3, r * 0.95), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 3, Color.BLACK)
			draw_string(_font, c + Vector2(-r * 0.3, r * 0.95), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, op))
		elif ab.energy > fighter.energy:
			draw_arc(c, r - 4.0, 0, TAU, 32, Color(0.3, 0.7, 1.0, 0.7 * op), 2.0)
	# Drag aim feedback on the button itself
	for t in _touches.values():
		if t["slot"] == slot and t["dragged"] and slot != "dash" and slot != "mega":
			var d: Vector2 = t["pos"] - c
			var lim := d.limit_length(AIM_MAX * _scale)
			draw_line(c, c + lim, Color(1, 1, 1, 0.6 * op), 3.0)
			draw_circle(c + lim, 10.0 * _scale, Color(1, 1, 1, 0.8 * op))
			if lim.length() < DRAG_DEADZONE * _scale:
				draw_string(_font, c + Vector2(-r, -r - 8.0), "cancelar", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _scale), Color(1, 0.6, 0.6, op))


## v0.2 polish: icon shape for a button ("" = draw the text label).
func _icon_shape(slot: String, ab: AbilityDef) -> String:
	if slot == "dash":
		return "dodge"
	if ab == null or fighter == null:
		return ""
	return SkillIcons.shape_for(ab, fighter.form)


func _draw_pie(c: Vector2, r: float, frac: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var steps := 24
	var start := -PI / 2.0
	for i in steps + 1:
		var a := start + TAU * frac * float(i) / steps
		pts.append(c + Vector2.from_angle(a) * r)
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)
