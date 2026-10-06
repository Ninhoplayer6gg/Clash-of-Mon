class_name Arena
extends Node2D
## Arena built from data/arenas/<id>.json: tiled ground, obstacles with
## collision (rocks, trees, walls, stumps, ponds), decorative bushes and
## spawn points. Provides geometry queries for projectiles, AI and abilities.
##
## Obstacles are plain dictionaries so new kinds and interactions (burning
## trees, breakable rocks, water that only blocks walking...) are data.

signal obstacle_destroyed(obstacle: Dictionary)

const BORDER_TILES := 12

var data := {}
var palette := {}
var bounds := Rect2(0, 0, 1120, 760)
var spawns: Array[Vector2] = []
var obstacles: Array = []  # {kind, shape, pos, radius, rect, blocks_proj, blocks_move, hp, node, body}
var ground: TileMapLayer
var actors: Node2D
var _tile_names: Array = []


func build(arena_data: Dictionary, actors_parent: Node2D) -> void:
	data = arena_data
	actors = actors_parent
	palette = data.get("palette", {})
	var size: Array = data.get("size", [1120, 760])
	bounds = Rect2(0, 0, float(size[0]), float(size[1]))
	spawns.clear()
	for s in data.get("spawns", [[200, 380], [920, 380]]):
		spawns.append(Vector2(s[0], s[1]))
	_build_ground()
	_build_bounds()
	var list: Array = data.get("obstacles", []).duplicate(true)
	if String(data.get("mirror", "")) == "x":
		var mirrored := []
		for o in list:
			if o.get("no_mirror", false):
				continue
			var m: Dictionary = o.duplicate(true)
			if m.has("pos"):
				m["pos"] = [bounds.size.x - float(o["pos"][0]), o["pos"][1]]
			if m.has("rect"):
				var r: Array = o["rect"]
				m["rect"] = [bounds.size.x - float(r[0]) - float(r[2]), r[1], r[2], r[3]]
			mirrored.append(m)
		list.append_array(mirrored)
	var variant := 0
	for o in list:
		_add_obstacle(o, variant)
		variant += 1
	for b in data.get("bushes", []):
		_add_bush(Vector2(b[0], b[1]), variant)
		variant += 1


# ------------------------------------------------------------------ build

func _build_ground() -> void:
	var seed_value := int(data.get("seed", 1))
	var atlas := ArenaArt.ground_atlas(palette, seed_value)
	var tex: Texture2D = atlas[0]
	_tile_names = atlas[1]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(ArenaArt.TILE, ArenaArt.TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(ArenaArt.TILE, ArenaArt.TILE)
	for i in _tile_names.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.z_index = -10
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grass_ids := _ids("grass")
	var flower_ids := _ids("flower")
	var tuft_ids := _ids("tuft")
	var dirt_ids := _ids("dirt")
	var border_ids := _ids("border")
	var deco: Dictionary = data.get("decor", {})
	var flower_p := float(deco.get("flowers", 0.04))
	var tuft_p := float(deco.get("tufts", 0.08))
	var paths: Array = data.get("paths", [])
	var tiles_x := int(ceil(bounds.size.x / ArenaArt.TILE))
	var tiles_y := int(ceil(bounds.size.y / ArenaArt.TILE))
	for ty in range(-BORDER_TILES, tiles_y + BORDER_TILES):
		for tx in range(-BORDER_TILES, tiles_x + BORDER_TILES):
			var center := Vector2((tx + 0.5) * ArenaArt.TILE, (ty + 0.5) * ArenaArt.TILE)
			var id := 0
			if tx < 0 or ty < 0 or tx >= tiles_x or ty >= tiles_y:
				id = border_ids[rng.randi() % border_ids.size()]
			elif _in_path(center, paths):
				id = dirt_ids[rng.randi() % dirt_ids.size()]
			else:
				var r := rng.randf()
				if r < flower_p:
					id = flower_ids[rng.randi() % flower_ids.size()]
				elif r < flower_p + tuft_p:
					id = tuft_ids[rng.randi() % tuft_ids.size()]
				else:
					id = grass_ids[rng.randi() % grass_ids.size()]
			ground.set_cell(Vector2i(tx, ty), 0, Vector2i(id, 0))


func _ids(n: String) -> Array:
	var out := []
	for i in _tile_names.size():
		if _tile_names[i] == n:
			out.append(i)
	return out


func _in_path(p: Vector2, paths: Array) -> bool:
	for path in paths:
		if path.has("rect"):
			var r: Array = path["rect"]
			if Rect2(r[0], r[1], r[2], r[3]).has_point(p):
				return true
		elif path.has("line"):
			var pts: Array = path["line"]
			var w := float(path.get("width", 32.0)) * 0.5
			for i in pts.size() - 1:
				var a := Vector2(pts[i][0], pts[i][1])
				var b := Vector2(pts[i + 1][0], pts[i + 1][1])
				if Geo.dist2_point_segment(p, a, b) <= w * w:
					return true
		elif path.has("circle"):
			var c: Array = path["circle"]
			if p.distance_to(Vector2(c[0], c[1])) <= float(c[2]):
				return true
	return false


func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	body.collision_layer = Fighter.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var t := 64.0
	var rects := [
		Rect2(-t, -t, bounds.size.x + t * 2, t),
		Rect2(-t, bounds.size.y, bounds.size.x + t * 2, t),
		Rect2(-t, 0, t, bounds.size.y),
		Rect2(bounds.size.x, 0, t, bounds.size.y),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)


func _add_obstacle(o: Dictionary, variant: int) -> void:
	var kind: String = o.get("kind", "rock")
	var ob := {
		"kind": kind,
		"blocks_proj": bool(o.get("blocks_projectiles", kind != "pond")),
		"blocks_move": true,
		"hp": float(o.get("hp", 0.0)),
		"breakable": bool(o.get("breakable", false)),
		"tags": o.get("tags", []),
	}
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var body := StaticBody2D.new()
	body.collision_layer = Fighter.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	body.add_child(cs)
	match kind:
		"wall":
			var r: Array = o["rect"]
			var rect := Rect2(r[0], r[1], r[2], r[3])
			ob["shape"] = "rect"
			ob["rect"] = rect
			ob["pos"] = rect.get_center()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			cs.shape = shape
			sprite.texture = ArenaArt.wall(palette, int(rect.size.x), int(rect.size.y))
			sprite.centered = false
			# Origin at the wall's bottom edge so y-sort works.
			sprite.position = Vector2(-rect.size.x * 0.5, -rect.size.y - 6.0)
			var holder := Node2D.new()
			holder.position = Vector2(rect.get_center().x, rect.end.y)
			holder.add_child(sprite)
			body.position = Vector2(0, -rect.size.y * 0.5)
			holder.add_child(body)
			actors.add_child(holder)
			ob["node"] = holder
		_:
			var pos := Vector2(o["pos"][0], o["pos"][1])
			var radius := float(o.get("radius", _default_radius(kind)))
			ob["shape"] = "circle"
			ob["pos"] = pos
			ob["radius"] = radius
			var shape := CircleShape2D.new()
			shape.radius = radius
			cs.shape = shape
			var holder := Node2D.new()
			holder.position = pos
			match kind:
				"tree":
					sprite.texture = ArenaArt.tree(palette, variant % 3)
					sprite.offset = Vector2(0, -26)
					ob["canopy"] = true
				"stump":
					sprite.texture = ArenaArt.stump(palette)
					sprite.offset = Vector2(0, -5)
				"pond":
					sprite.texture = ArenaArt.pond(palette, int(radius))
					sprite.z_index = -5
					sprite.z_as_relative = false
					ob["blocks_proj"] = false
				_:
					sprite.texture = ArenaArt.rock(palette, radius, variant % 4)
					sprite.offset = Vector2(0, -radius * 0.35)
			holder.add_child(sprite)
			holder.add_child(body)
			actors.add_child(holder)
			ob["node"] = holder
	ob["sprite"] = sprite
	ob["body"] = body
	obstacles.append(ob)


func _default_radius(kind: String) -> float:
	match kind:
		"tree": return 11.0
		"stump": return 9.0
		"pond": return 34.0
	return 14.0


func _add_bush(p: Vector2, variant: int) -> void:
	var s := Sprite2D.new()
	s.texture = ArenaArt.bush(palette, variant % 3)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = Vector2(0, -6)
	s.position = p
	actors.add_child(s)


# ---------------------------------------------------------------- queries

func clamp_inside(p: Vector2, margin: float = 6.0) -> Vector2:
	return Vector2(clampf(p.x, bounds.position.x + margin, bounds.end.x - margin), clampf(p.y, bounds.position.y + margin, bounds.end.y - margin))


func is_inside(p: Vector2, margin: float = 0.0) -> bool:
	return bounds.grow(-margin).has_point(p)


## True if a circle overlaps any movement-blocking obstacle.
func circle_blocked(p: Vector2, r: float) -> bool:
	if not is_inside(p, r):
		return true
	for o in obstacles:
		if not o["blocks_move"]:
			continue
		if o["shape"] == "circle":
			var rr: float = o["radius"] + r
			if p.distance_squared_to(o["pos"]) < rr * rr:
				return true
		elif Geo.circle_vs_rect(p, r, o["rect"]):
			return true
	return false


## Projectile segment test against projectile-blocking obstacles.
func segment_blocked(a: Vector2, b: Vector2, r: float) -> bool:
	if not bounds.has_point(b):
		return true
	return _segment_obstacle(a, b, r) != null


func _segment_obstacle(a: Vector2, b: Vector2, r: float):
	for o in obstacles:
		if not o["blocks_proj"]:
			continue
		if o["shape"] == "circle":
			if Geo.circle_vs_capsule(o["pos"], o["radius"], a, b, r):
				return o
		else:
			var rect: Rect2 = o["rect"].grow(r)
			if rect.has_point(b) or rect.has_point(a) or _seg_rect(a, b, rect):
				return o
	return null


func _seg_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


## Distance a ray can travel before hitting a projectile-blocking obstacle
## or the arena edge (analytic ray vs circle / slab tests, O(obstacles)).
func ray_length(origin: Vector2, dir: Vector2, max_len: float) -> float:
	var best := max_len
	var edge := _ray_rect(origin, dir, bounds, true)
	if edge >= 0.0:
		best = minf(best, edge)
	for o in obstacles:
		if not o["blocks_proj"]:
			continue
		var t := -1.0
		if o["shape"] == "circle":
			var oc: Vector2 = origin - o["pos"]
			var b := oc.dot(dir)
			var r: float = o["radius"]
			var cc := oc.dot(oc) - r * r
			var disc := b * b - cc
			if disc >= 0.0:
				t = -b - sqrt(disc)
				if t < 0.0:
					t = -1.0 if cc > 0.0 else 0.0
		else:
			t = _ray_rect(origin, dir, o["rect"], false)
		if t >= 0.0 and t < best:
			best = t
	return maxf(best, 4.0)


## Ray vs axis-aligned rect. `inside_exit` returns the exit distance (for the
## arena bounds), otherwise the entry distance. -1 when there is no hit.
func _ray_rect(origin: Vector2, dir: Vector2, rect: Rect2, inside_exit: bool) -> float:
	var tmin := -INF
	var tmax := INF
	for axis in 2:
		var o := origin[axis]
		var d := dir[axis]
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(d) < 0.00001:
			if o < lo or o > hi:
				return -1.0
		else:
			var t1 := (lo - o) / d
			var t2 := (hi - o) / d
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
	if tmax < tmin or tmax < 0.0:
		return -1.0
	if inside_exit:
		return tmax
	return maxf(tmin, 0.0)


func line_of_sight(a: Vector2, b: Vector2) -> bool:
	return _segment_obstacle(a, b, 2.0) == null


## Nearest free spot (spiral search) for teleports / leap landings.
func find_free_position(p: Vector2, r: float) -> Vector2:
	p = clamp_inside(p, r + 2.0)
	if not circle_blocked(p, r):
		return p
	for ring in range(1, 14):
		var dist := ring * 8.0
		for k in 12:
			var c := clamp_inside(p + Vector2.from_angle(k * TAU / 12.0) * dist, r + 2.0)
			if not circle_blocked(c, r):
				return c
	return clamp_inside(bounds.get_center(), r)


## Hook for terrain interaction: breakable props take projectile damage.
func on_projectile_impact(p: Vector2, action: Dictionary) -> void:
	for o in obstacles:
		if not o["breakable"]:
			continue
		var near := false
		if o["shape"] == "circle":
			near = p.distance_to(o["pos"]) <= o["radius"] + 10.0
		else:
			near = o["rect"].grow(10.0).has_point(p)
		if near:
			damage_obstacle(o, float(action.get("power", 100.0)))
			return


func damage_obstacle(o: Dictionary, amount: float) -> void:
	o["hp"] = float(o["hp"]) - amount
	var spr: Sprite2D = o["sprite"]
	if is_instance_valid(spr):
		var tw := spr.create_tween()
		spr.modulate = Color(1.6, 1.6, 1.6)
		tw.tween_property(spr, "modulate", Color.WHITE, 0.15)
	if o["hp"] <= 0.0:
		obstacles.erase(o)
		if is_instance_valid(o["node"]):
			o["node"].queue_free()
		obstacle_destroyed.emit(o)


## Fades tree canopies that hide the given fighters (readability).
func update_canopies(watch: Array) -> void:
	for o in obstacles:
		if not o.get("canopy", false):
			continue
		var spr: Sprite2D = o["sprite"]
		var hide := false
		for f in watch:
			var d: Vector2 = f.position - o["pos"]
			if d.y < 0.0 and d.y > -46.0 and absf(d.x) < 22.0:
				hide = true
				break
		var target := 0.55 if hide else 1.0
		if not is_equal_approx(spr.modulate.a, target):
			spr.modulate.a = move_toward(spr.modulate.a, target, 0.08)
