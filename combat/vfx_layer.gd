class_name VfxLayer
extends Node2D
## Fixed-capacity particle system drawn from one canvas item. Capacity
## depends on the graphics quality setting; when full, new particles are
## simply dropped (never allocates during a match).

enum Kind { DOT, SPARK, RING, EMBER, DROP, ZAP, LEAF, SHARD, WISP, BUBBLE, DEBRIS, DUST, SMOKE, SPARKLE, SCALE, FEATHER, STREAK }

var capacity := 160
var count := 0
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _kind := PackedInt32Array()
var _seed := PackedFloat32Array()  # per-particle random phase (v0.2 kinds)
var _cheap := false  # low quality: soft puffs drawn as rects (no circle polygons)
# Afterimages (sprite ghosts for dashes / teleports)
const MAX_GHOSTS := 18
var _ghosts: Array = []  # [texture, region, pos, offset, life, max, color]


func _ready() -> void:
	z_index = 11
	configure(Settings.max_particles())


func configure(p_capacity: int) -> void:
	capacity = p_capacity
	# Packed arrays are values: resize each one explicitly.
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_max.resize(capacity)
	_size.resize(capacity)
	_col.resize(capacity)
	_kind.resize(capacity)
	_seed.resize(capacity)
	_cheap = Settings.quality == Settings.QUALITY_LOW
	count = 0


func _add(kind: int, p: Vector2, v: Vector2, life: float, size: float, c: Color) -> void:
	if count >= capacity:
		return
	_pos[count] = p
	_vel[count] = v
	_life[count] = life
	_max[count] = life
	_size[count] = size
	_col[count] = c
	_kind[count] = kind
	_seed[count] = randf()
	count += 1


func burst(p: Vector2, c: Color, n: int, speed: float, life: float, size: float) -> void:
	var real_n := maxi(1, int(round(n * Settings.particle_scale())))
	for i in real_n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0)
		_add(Kind.DOT, p, v, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.2), c)


func hit_spark(p: Vector2, c: Color, scale_k: float) -> void:
	var n := int(round(6 * scale_k * Settings.particle_scale())) + 2
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 150.0) * scale_k
		_add(Kind.SPARK, p, v, randf_range(0.12, 0.22), 1.5, c)
	_add(Kind.RING, p, Vector2.ZERO, 0.18, 8.0 * scale_k, Color(1, 1, 1, 0.9))


func ring(p: Vector2, c: Color, radius: float, life: float) -> void:
	_add(Kind.RING, p, Vector2.ZERO, life, radius, c)


func afterimage_from(f: Fighter, life: float) -> void:
	if f.animator == null or f.animator.texture == null:
		return
	if _ghosts.size() >= MAX_GHOSTS:
		_ghosts.pop_front()
	var col := Color(f.team_color.lightened(0.4), 0.55)
	_ghosts.append([f.animator.texture, f.animator.region_rect, f.position + f.animator.position, f.animator.offset, life, life, col])


func clear() -> void:
	count = 0
	_ghosts.clear()


func _process(delta: float) -> void:
	var i := 0
	while i < count:
		_life[i] -= delta
		if _life[i] <= 0.0:
			count -= 1
			_pos[i] = _pos[count]
			_vel[i] = _vel[count]
			_life[i] = _life[count]
			_max[i] = _max[count]
			_size[i] = _size[count]
			_col[i] = _col[count]
			_kind[i] = _kind[count]
			_seed[i] = _seed[count]
			continue
		_pos[i] += _vel[i] * delta
		if _kind[i] <= Kind.RING:
			_vel[i] *= 0.9
		else:
			_step_kind(i, delta)
		i += 1
	var g := _ghosts.size() - 1
	while g >= 0:
		_ghosts[g][4] -= delta
		if _ghosts[g][4] <= 0.0:
			_ghosts.remove_at(g)
		g -= 1
	if count > 0 or not _ghosts.is_empty():
		queue_redraw()
	elif get_meta("dirty", false):
		set_meta("dirty", false)
		queue_redraw()


func _draw() -> void:
	for gh in _ghosts:
		var k: float = gh[4] / gh[5]
		var col: Color = gh[6]
		col.a *= k
		var region: Rect2 = gh[1]
		var off: Vector2 = gh[3]
		var top_left: Vector2 = gh[2] + off - region.size * 0.5
		draw_texture_rect_region(gh[0], Rect2(top_left, region.size), region, col)
	for i in count:
		var k := _life[i] / _max[i]
		var c := _col[i]
		c.a *= k
		match _kind[i]:
			Kind.DOT:
				draw_rect(Rect2(_pos[i] - Vector2.ONE * _size[i] * 0.5, Vector2.ONE * _size[i] * (0.5 + 0.5 * k)), c)
			Kind.SPARK:
				draw_line(_pos[i], _pos[i] - _vel[i] * 0.04, c, _size[i])
			Kind.RING:
				draw_arc(_pos[i], _size[i] * (1.4 - 0.4 * k), 0, TAU, 20, c, 2.0)
			_:
				# Typed particles hold their colour, then fade out at the end.
				c.a = _col[i].a * minf(1.0, k * 2.5)
				_draw_kind(i, k, c)
	if count == 0 and _ghosts.is_empty():
		set_meta("dirty", true)


# ------------------------------------------------- v0.2 typed particles
# Small rects/lines in the pixel-art spirit; circles only for soft puffs.
# Spawned by TypeVfx (combat/type_vfx.gd) for hits, trails and KOs.

## Adds one particle of any kind (dropped silently when full).
func emit(kind: int, p: Vector2, v: Vector2, life: float, size: float, c: Color) -> void:
	_add(kind, p, v, life, size, c)


## True while less than `frac` of the capacity is in use (trails keep
## room for hit feedback).
func has_room(frac: float) -> bool:
	return count < int(capacity * frac)


func _step_kind(i: int, delta: float) -> void:
	var v := _vel[i]
	match _kind[i]:
		Kind.EMBER:
			v.y -= 70.0 * delta
			v *= maxf(0.0, 1.0 - 2.5 * delta)
		Kind.DROP, Kind.DEBRIS:
			v.y += 420.0 * delta
			v.x *= maxf(0.0, 1.0 - 1.5 * delta)
		Kind.LEAF, Kind.FEATHER:
			v *= maxf(0.0, 1.0 - 3.0 * delta)
			v.y += 30.0 * delta
		Kind.WISP, Kind.BUBBLE, Kind.SMOKE:
			v *= maxf(0.0, 1.0 - 2.0 * delta)
			v.y -= 28.0 * delta
		Kind.ZAP:
			v = Vector2.ZERO
		_:
			v *= maxf(0.0, 1.0 - 6.0 * delta)
	_vel[i] = v


func _draw_kind(i: int, k: float, c: Color) -> void:
	var p := _pos[i]
	var sz := _size[i]
	var sd := _seed[i]
	var age := _max[i] - _life[i]
	if _cheap and (_kind[i] == Kind.WISP or _kind[i] == Kind.BUBBLE or _kind[i] == Kind.DUST or _kind[i] == Kind.SMOKE):
		var r := sz * (1.2 - 0.4 * k)
		draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), Color(c, c.a * 0.5))
		return
	match _kind[i]:
		Kind.EMBER:
			var s := sz * (0.4 + 0.6 * k)
			var e := c.lerp(Color(0.75, 0.12, 0.05, c.a), 1.0 - k)
			e.a *= 0.7 + 0.3 * sin(age * 40.0 + sd * 20.0)
			draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), e)
		Kind.DROP:
			draw_line(p, p - _vel[i] * 0.025, c, sz * 0.8)
		Kind.ZAP:
			var d := Vector2.from_angle(sd * TAU)
			var n := d.orthogonal()
			var l := sz * (0.5 + 0.5 * k)
			var flip := 1.0 if fmod(age * 30.0 + sd * 7.0, 2.0) < 1.0 else -1.0
			var p1 := p + d * l * 0.35 + n * l * 0.28 * flip
			var p2 := p + d * l * 0.7 - n * l * 0.28 * flip
			draw_line(p, p1, c, 1.5)
			draw_line(p1, p2, c, 1.5)
			draw_line(p2, p + d * l, c, 1.5)
		Kind.LEAF:
			var d := Vector2.from_angle(sd * TAU + age * (4.0 + sd * 4.0)) * sz
			var sway := Vector2(sin(age * 5.0 + sd * 9.0) * 3.0, 0.0)
			draw_line(p + sway - d, p + sway + d, c, sz * 0.9)
			draw_line(p + sway - d * 0.8, p + sway + d * 0.8, c.darkened(0.35), 0.6)
		Kind.SHARD:
			var d := _vel[i].normalized() if _vel[i].length_squared() > 1.0 else Vector2.from_angle(sd * TAU)
			var l := sz * 1.6
			draw_line(p - d * l, p + d * l * 0.4, c, 1.6)
			draw_rect(Rect2(p + d * l * 0.4 - Vector2.ONE * 0.75, Vector2.ONE * 1.5), Color(1, 1, 1, c.a))
		Kind.WISP:
			var r := sz * (0.7 + 0.5 * (1.0 - k))
			var off := Vector2(sin(age * 6.0 + sd * 10.0) * 2.5, 0.0)
			draw_circle(p + off, r, Color(c, c.a * 0.55))
			draw_circle(p + off, r * 0.5, Color(c.lightened(0.4), c.a * 0.6))
		Kind.BUBBLE:
			var r := sz * (0.6 + 0.6 * (1.0 - k))
			draw_circle(p, r, Color(c, c.a * 0.5))
			draw_rect(Rect2(p + Vector2(-r * 0.5, -r * 0.6), Vector2.ONE * maxf(1.0, r * 0.4)), Color(1, 1, 1, c.a * 0.8))
		Kind.DEBRIS:
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz * 0.8)), c)
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz * 0.3)), c.lightened(0.25))
		Kind.DUST:
			draw_circle(p, sz * (1.6 - 0.9 * k), Color(c, c.a * 0.35))
		Kind.SMOKE:
			draw_circle(p, sz * (1.5 - 0.7 * k), Color(c, c.a * 0.5))
		Kind.SPARKLE:
			var l := sz * (0.4 + 0.6 * absf(sin(age * 16.0 + sd * 6.0)))
			draw_line(p - Vector2(l, 0), p + Vector2(l, 0), c, 1.2)
			draw_line(p - Vector2(0, l), p + Vector2(0, l), c, 1.2)
			draw_rect(Rect2(p - Vector2.ONE * 0.75, Vector2.ONE * 1.5), Color(1, 1, 1, c.a))
		Kind.SCALE:
			var d := Vector2.from_angle(sd * TAU + age * 8.0) * sz * 0.6
			var shimmer := 0.5 + 0.5 * sin(age * 20.0 + sd * 9.0)
			draw_line(p - d, p + d, c.lerp(Color(1, 1, 1, c.a), shimmer * 0.5), sz * 0.9)
		Kind.FEATHER:
			var d := Vector2.from_angle(sd * PI + 0.6 * sin(age * 4.0 + sd * 8.0)) * sz
			draw_line(p - d, p + d, c, 1.6)
			draw_line(p - d * 0.9, p + d * 0.9, c.darkened(0.3), 0.6)
		Kind.STREAK:
			draw_line(p, p - _vel[i] * 0.06, c, sz)
