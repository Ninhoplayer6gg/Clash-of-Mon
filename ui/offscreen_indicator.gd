class_name OffscreenIndicator
extends Control
## Screen-edge marker for the active enemy while it is outside the camera
## view: a disc with the enemy portrait and an HP ring in its team colour,
## plus an arrow pointing at it. Farther enemies are drawn fainter. Hidden
## (vanish/underground) or fainted enemies are never revealed.

const RADIUS := 25.0
## Distance from each screen edge (top leaves room for the HUD cards).
const INSET := Vector2(40.0, 40.0)
const INSET_TOP := 172.0  # below the HUD cards and the 3v3 bench row

var match_node: Node
var _portrait: Texture2D
var _portrait_owner: Fighter
var _portrait_form := ""
var _arrow := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _arrow_col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
var _no_uvs := PackedVector2Array()
var _font: Font
## Last computed marker state (read by tests / debug).
var showing := false
var marker_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


## Point where the segment from the centre of `rect` to `target` leaves
## `rect` (target itself when it is inside).
static func edge_point(rect: Rect2, target: Vector2) -> Vector2:
	var c := rect.get_center()
	var d := target - c
	if d == Vector2.ZERO:
		return c
	var half := rect.size * 0.5
	var t := 1.0
	if absf(d.x) > 0.0001:
		t = minf(t, half.x / absf(d.x))
	if absf(d.y) > 0.0001:
		t = minf(t, half.y / absf(d.y))
	return c + d * t


## Screen rect where markers live (inset from the viewport edges).
static func marker_rect(view_size: Vector2) -> Rect2:
	var r := Rect2(Vector2(INSET.x, INSET_TOP), view_size - Vector2(INSET.x * 2.0, INSET_TOP + INSET.y))
	if r.size.x < 1.0 or r.size.y < 1.0:
		r = Rect2(Vector2.ZERO, view_size).grow(-4.0)
	return r


## 1.0 right outside the view, fading to 0.45 for far away enemies.
static func distance_alpha(outside_px: float) -> float:
	return lerpf(1.0, 0.45, clampf(outside_px / 700.0, 0.0, 1.0))


func _process(_delta: float) -> void:
	var was := showing
	_update_marker()
	if showing or was:
		queue_redraw()


func _enemy() -> Fighter:
	if match_node == null or not is_instance_valid(match_node) or match_node.teams.size() < 2:
		return null
	var f: Fighter = match_node.teams[1].active_fighter()
	if f == null or not f.is_alive() or f.hidden_mode != "" or not f.is_inside_tree():
		return null
	return f


func _update_marker() -> void:
	showing = false
	var f := _enemy()
	if f == null:
		return
	var vs := get_viewport_rect().size
	var sp: Vector2 = get_viewport().get_canvas_transform() * (f.global_position + Vector2(0, -f.body_height * 0.5))
	var view := Rect2(Vector2.ZERO, vs)
	if view.grow(-6.0).has_point(sp):
		return
	showing = true
	marker_pos = edge_point(marker_rect(vs), sp)


func _draw() -> void:
	if not showing:
		return
	var f := _enemy()
	if f == null:
		return
	var vs := get_viewport_rect().size
	var sp: Vector2 = get_viewport().get_canvas_transform() * (f.global_position + Vector2(0, -f.body_height * 0.5))
	var outside := sp.distance_to(edge_point(Rect2(Vector2.ZERO, vs), sp))
	var a := distance_alpha(outside)
	var c := marker_pos
	var team_col: Color = f.team_color
	var dir := (sp - c).normalized()
	# Arrow (one primitive, arrays reused)
	var tip := c + dir * (RADIUS + 19.0)
	var base := c + dir * (RADIUS + 3.0)
	var n := dir.orthogonal() * 12.0
	_arrow[0] = tip
	_arrow[1] = base + n
	_arrow[2] = base - n
	for i in 3:
		_arrow_col[i] = Color(team_col, a)
	draw_primitive(_arrow, _arrow_col, _no_uvs)
	# Disc + portrait + HP ring
	draw_circle(c, RADIUS + 3.0, Color(0, 0, 0, 0.55 * a))
	draw_circle(c, RADIUS, Color(0.08, 0.1, 0.14, 0.85 * a))
	var tex := _portrait_for(f)
	if tex:
		var s := RADIUS * 1.5
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
	draw_arc(c, RADIUS, 0, TAU, 32, Color(0.2, 0.2, 0.24, 0.9 * a), 4.0)
	var hp := f.hp_ratio()
	var hp_col := team_col if hp > 0.3 else Color(1.0, 0.35, 0.3)
	if hp > 0.0:
		draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * hp, 32, Color(hp_col, a), 4.0)


func _portrait_for(f: Fighter) -> Texture2D:
	if f != _portrait_owner or f.form.id != _portrait_form:
		_portrait_owner = f
		_portrait_form = f.form.id
		_portrait = UITheme.portrait_texture(f.species, f.form.id)
	return _portrait
