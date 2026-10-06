class_name VfxLayer
extends Node2D
## Fixed-capacity particle system drawn from one canvas item. Capacity
## depends on the graphics quality setting; when full, new particles are
## simply dropped (never allocates during a match).

enum Kind { DOT, SPARK, RING }

var capacity := 160
var count := 0
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _kind := PackedInt32Array()
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
			continue
		_pos[i] += _vel[i] * delta
		_vel[i] *= 0.9
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
	if count == 0 and _ghosts.is_empty():
		set_meta("dirty", true)
