class_name ArenaTerrain
extends Node2D
## Interactive ground terrain of an arena (v0.2), from the "terrain" list of
## data/arenas/<id>.json:
##   {"kind": "tall_grass" | "lava" | "shallow_water", "rect": [x, y, w, h]}
##   {"kind": ..., "circle": [x, y, r]}
##   {"kind": ..., "line": [[x, y], [x, y], ...], "width": w}
## Entries are mirrored with the arena ("mirror": "x") unless "no_mirror".
##
##  tall_grass    - conceals fighters from the enemy team (Brawl-Stars-like
##                  bushes) unless revealed: an enemy within REVEAL_RANGE, or
##                  for REVEAL_TIME after casting or losing HP. Fire burns a
##                  whole patch (on_fire_at); it regrows after GRASS_REGROW.
##  lava          - damage over time + burn for non-Fire types.
##  shallow_water - slows non-Water types, speeds Water types, puts out burns.
##  ash           - decorative ground only (volcanic ash fields).
##
## Lava, water and burnt grass are drawn by this node (below the actors);
## tall grass is one y-sorted sprite per cell row inside the actors node, so
## fighters standing in it look like they are *inside* the grass; flames are
## drawn by a child above the actors. Every physics tick (Arena.update_terrain)
## writes the per-fighter results read by Fighter / CombatWorld / bots:
## terrain_kind, terrain_speed_mult, concealed, reveal_time, terrain_alpha.

const NONE := 0
const GRASS := 1
const LAVA := 2
const WATER := 3
const ASH := 4  # decorative only (volcanic ash fields), never returned by terrain_at
const KIND_IDS := {"tall_grass": GRASS, "lava": LAVA, "shallow_water": WATER, "ash": ASH}

const CELL := 16
## Concealment
const REVEAL_RANGE := 55.0
const REVEAL_TIME := 1.0
const OWN_CONCEALED_ALPHA := 0.5
const ALPHA_RATE := 6.0
## Hazards
const LAVA_DPS_PCT := 0.04   # of max HP per second while standing in lava
const LAVA_TICK := 0.25
const LAVA_BURN := 2.0       # burn status refreshed while in lava
const WATER_SLOW := 0.75
const WATER_BOOST := 1.1
## Burning grass
const FLAME_LIFE := 0.45
const FLAME_SPREAD := 160.0  # px/s from the ignition point
const GRASS_REGROW := 10.0
const GRASS_GROW_TIME := 1.0
const _ESCAPE_RINGS := [22.0, 44.0, 72.0, 110.0, 160.0]

enum Patch { GROWN, BURNING, BURNT, GROWING }

## Team whose point of view is rendered (team 0 = the local player's side).
var viewer_team := 0
var arena: Arena
var palette := {}
var lava_regions: Array = []   # {kind, shape, aabb, box, src, src_a, src_b, phase}
var water_regions: Array = []
var decals: Array = []         # decorative ground (ash)
var patches: Array = []        # tall grass, see _setup_patch()
var _time := 0.0               # visual clock (lava pulse, water glints)
var _lava_acc := {}            # fighter instance id -> seconds to next lava tick
var _last_hp := {}             # fighter instance id -> HP seen last tick
var _bubble_acc := 0.0
var _burning := 0              # patches currently burning (flame layer redraws)
var _changing := 0             # patches not fully grown (ash drawn by this node)
var _fire: Node2D
var _vfx: VfxLayer
var _viewer_patch := -1
var _viewer_y := 0.0
## Two atlases per arena: every ground region, grass row and ash image in
## `_atlas`, the animated overlays (lava glow, water glints) in `_atlas_over`.
var _atlas: Texture2D
var _atlas_over: Texture2D


func build(p_arena: Arena, arena_data: Dictionary, actors: Node2D) -> void:
	arena = p_arena
	name = "Terrain"
	palette = arena_data.get("palette", {})
	z_index = -8
	_fire = Node2D.new()
	_fire.name = "Flames"
	_fire.z_as_relative = false
	_fire.z_index = 9
	_fire.draw.connect(_draw_flames)
	add_child(_fire)
	var list: Array = []
	for t in arena_data.get("terrain", []):
		var e := _parse(t)
		if not e.is_empty():
			list.append(e)
	if String(arena_data.get("mirror", "")) == "x":
		var mirrored := []
		for e in list:
			if not e["no_mirror"]:
				mirrored.append(_mirrored(e, arena.bounds.size.x))
		list.append_array(mirrored)
	var n := 0
	for e in list:
		match int(e["kind"]):
			GRASS:
				_setup_patch(e, n)
				patches.append(e)
			LAVA:
				_setup_region(e, n)
				lava_regions.append(e)
			WATER:
				_setup_region(e, n)
				water_regions.append(e)
			ASH:
				_setup_region(e, n)
				decals.append(e)
		n += 1
	_build_art(list, arena_data)
	for e in patches:
		_add_rows(e, actors)


# ------------------------------------------------------------------ shapes

func _parse(t: Dictionary) -> Dictionary:
	var kind: int = KIND_IDS.get(String(t.get("kind", "")), NONE)
	if kind == NONE:
		push_warning("ArenaTerrain: unknown terrain kind '%s'" % t.get("kind", ""))
		return {}
	var e := {"kind": kind, "no_mirror": bool(t.get("no_mirror", false)), "shape": ""}
	if t.has("rect"):
		var r: Array = t["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if kind == GRASS:
			# Grass is made of whole cells: snap the size so mirrored copies match.
			rect.size = Vector2(maxf(CELL, roundf(rect.size.x / CELL) * CELL), maxf(CELL, roundf(rect.size.y / CELL) * CELL))
		e["shape"] = "rect"
		e["rect"] = rect
		e["round"] = minf(float(t.get("round", 10.0)), minf(rect.size.x, rect.size.y) * 0.5)
	elif t.has("circle"):
		var c: Array = t["circle"]
		e["shape"] = "circle"
		e["c"] = Vector2(float(c[0]), float(c[1]))
		e["r"] = float(c[2])
	elif t.has("line"):
		var pts := PackedVector2Array()
		for p in t["line"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() < 2:
			return {}
		e["shape"] = "line"
		e["pts"] = pts
		e["hw"] = float(t.get("width", 28.0)) * 0.5
	else:
		return {}
	_finish_shape(e)
	return e


static func _mirrored(e: Dictionary, width: float) -> Dictionary:
	var m := e.duplicate(true)
	match String(e["shape"]):
		"rect":
			var r: Rect2 = e["rect"]
			m["rect"] = Rect2(width - r.end.x, r.position.y, r.size.x, r.size.y)
		"circle":
			var c: Vector2 = e["c"]
			m["c"] = Vector2(width - c.x, c.y)
		"line":
			var pts := PackedVector2Array()
			for p in e["pts"]:
				pts.append(Vector2(width - p.x, p.y))
			m["pts"] = pts
	_finish_shape(m)
	return m


static func _finish_shape(e: Dictionary) -> void:
	match String(e["shape"]):
		"rect":
			e["aabb"] = e["rect"]
		"circle":
			var r: float = e["r"]
			e["aabb"] = Rect2(e["c"] - Vector2(r, r), Vector2(r, r) * 2.0)
		"line":
			var pts: PackedVector2Array = e["pts"]
			var box := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				box = box.expand(p)
			e["aabb"] = box.grow(float(e["hw"]))


## Signed distance from `p` to a terrain shape (negative inside).
static func shape_sd(e: Dictionary, p: Vector2) -> float:
	match String(e["shape"]):
		"rect":
			var r: Rect2 = e["rect"]
			var rr: float = e.get("round", 0.0)
			var q := (p - r.get_center()).abs() - r.size * 0.5 + Vector2(rr, rr)
			return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rr
		"circle":
			return p.distance_to(e["c"]) - float(e["r"])
		"line":
			var pts: PackedVector2Array = e["pts"]
			var best := INF
			for i in pts.size() - 1:
				best = minf(best, Geo.dist2_point_segment(p, pts[i], pts[i + 1]))
			return sqrt(best) - float(e["hw"])
	return INF


static func _inside(e: Dictionary, p: Vector2) -> bool:
	var box: Rect2 = e["aabb"]
	return box.has_point(p) and shape_sd(e, p) <= 0.0


# ------------------------------------------------------------------- build

func _setup_region(e: Dictionary, n: int) -> void:
	var box: Rect2 = e["aabb"]
	box = box.grow(6.0)
	e["box"] = Rect2i(Vector2i(int(floor(box.position.x)), int(floor(box.position.y))), Vector2i(int(ceil(box.size.x)), int(ceil(box.size.y))))
	e["phase"] = n * 1.7


## A tall grass patch is a grid of CELL cells centred on the shape's box;
## a cell is grass when its centre lies inside the shape. Gameplay queries
## use the same cells as the art, so what you see is what conceals.
func _setup_patch(e: Dictionary, n: int) -> void:
	var box: Rect2 = e["aabb"]
	var cols := maxi(1, int(round(box.size.x / CELL)))
	var rows := maxi(1, int(round(box.size.y / CELL)))
	var origin := box.get_center() - Vector2(cols, rows) * CELL * 0.5
	var cells := PackedByteArray()
	cells.resize(cols * rows)
	var centers := PackedVector2Array()
	for r in rows:
		for c in cols:
			var cc := origin + Vector2(c + 0.5, r + 0.5) * CELL
			var inside := shape_sd(e, cc) <= 2.0
			cells[r * cols + c] = 1 if inside else 0
			if inside:
				centers.append(cc)
	e["grid"] = Rect2(origin, Vector2(cols, rows) * CELL)
	e["cols"] = cols
	e["rows"] = rows
	e["cells"] = cells
	e["centers"] = centers
	e["delays"] = PackedFloat32Array()
	e["state"] = Patch.GROWN
	e["timer"] = 0.0
	e["burn_time"] = 0.0
	e["index"] = n


## Generates (or fetches from the per-arena cache) the two atlases and the
## source rect of every piece of terrain art inside them.
func _build_art(list: Array, arena_data: Dictionary) -> void:
	var key := "terrain_atlas_%d" % hash([arena_data.get("terrain", []), palette, arena_data.get("size", []), arena_data.get("mirror", "")])
	var cached = ArenaArt.cache_get(key)
	if cached == null:
		var base_imgs := []
		var over_imgs := []
		var owners := []  # [entry index, field] per base image
		for i in list.size():
			var e: Dictionary = list[i]
			if int(e["kind"]) == GRASS:
				var grid_key := "%d_%d_%s" % [int(e["cols"]), int(e["rows"]), str(e["grid"])]
				var rows_img: Array = ArenaArt.tall_grass_rows(palette, e["cells"], e["cols"], e["rows"], grid_key)
				for r in rows_img.size():
					base_imgs.append(rows_img[r])
					owners.append([i, "row", r])
				base_imgs.append(ArenaArt.ash_patch(palette, e["cells"], e["cols"], e["rows"], grid_key))
				owners.append([i, "ash", 0])
				continue
			var kind_name: String = {LAVA: "lava", WATER: "water", ASH: "ash"}[int(e["kind"])]
			var shape := e.duplicate()
			var imgs := ArenaArt.terrain_images(kind_name, palette, e["box"], func(p: Vector2) -> float: return shape_sd(shape, p))
			base_imgs.append(imgs[0])
			owners.append([i, "src", 0])
			if imgs[1] != null:
				over_imgs.append(imgs[1])
				over_imgs.append(imgs[2])
		var packed := ArenaArt.pack_atlas(base_imgs)
		var packed_over := ArenaArt.pack_atlas(over_imgs)
		# Source rects per entry, in list order (deterministic for the cache).
		var rects := []
		for i in list.size():
			rects.append({"row_src": []})
		var base_rects: Array = packed[1]
		for k in owners.size():
			var o: Array = owners[k]
			var d: Dictionary = rects[o[0]]
			if o[1] == "row":
				d["row_src"].append(base_rects[k])
			else:
				d[o[1]] = base_rects[k]
		var over_rects: Array = packed_over[1]
		var j := 0
		for i in list.size():
			var kind := int(list[i]["kind"])
			if kind == LAVA or kind == WATER:
				rects[i]["src_a"] = over_rects[j]
				rects[i]["src_b"] = over_rects[j + 1]
				j += 2
		cached = [ImageTexture.create_from_image(packed[0]), ImageTexture.create_from_image(packed_over[0]), rects]
		ArenaArt.cache_put(key, cached)
	_atlas = cached[0]
	_atlas_over = cached[1]
	var all_rects: Array = cached[2]
	for i in list.size():
		var d: Dictionary = all_rects[i]
		for k in d.keys():
			list[i][k] = d[k]


## One y-sorted sprite per cell row (region of the shared atlas), origin at
## the row's bottom edge so it sorts against fighters' feet.
func _add_rows(e: Dictionary, actors: Node2D) -> void:
	var g: Rect2 = e["grid"]
	var row_rects: Array = e["row_src"]
	var sprites: Array = []
	for r in row_rects.size():
		var src: Rect2i = row_rects[r]
		if src.size == Vector2i.ZERO:
			sprites.append(null)
			continue
		var s := Sprite2D.new()
		s.texture = _atlas
		s.region_enabled = true
		s.region_rect = Rect2(src)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.position = g.position + Vector2(0, (r + 1) * CELL)
		s.offset = Vector2(0, -src.size.y)
		actors.add_child(s)
		sprites.append(s)
	e["sprites"] = sprites


# ----------------------------------------------------------------- queries

## Terrain kind under a point: LAVA > WATER > GRASS (grown) > NONE.
func terrain_at(p: Vector2) -> int:
	for e in lava_regions:
		if _inside(e, p):
			return LAVA
	for e in water_regions:
		if _inside(e, p):
			return WATER
	if grass_patch_at(p) >= 0:
		return GRASS
	return NONE


func is_lava(p: Vector2) -> bool:
	for e in lava_regions:
		if _inside(e, p):
			return true
	return false


## Index of the tall grass patch whose cell contains `p` (-1 = none).
## Burnt / regrowing patches only count with `any_state`.
func grass_patch_at(p: Vector2, any_state: bool = false) -> int:
	for i in patches.size():
		var e: Dictionary = patches[i]
		if not any_state and e["state"] != Patch.GROWN:
			continue
		var g: Rect2 = e["grid"]
		if not g.has_point(p):
			continue
		var cols: int = e["cols"]
		var c := int((p.x - g.position.x) / CELL)
		var r := int((p.y - g.position.y) / CELL)
		if c >= 0 and c < cols and r >= 0 and r < int(e["rows"]):
			var cells: PackedByteArray = e["cells"]
			if cells[r * cols + c] == 1:
				return i
	return -1


## Lava is a hazard for everyone but Fire types.
func is_hazard(p: Vector2, f: Fighter) -> bool:
	if f != null and f.types.has("fire"):
		return false
	return is_lava(p)


## Direction toward the nearest walkable spot outside lava (bots).
func escape_dir(p: Vector2, r: float) -> Vector2:
	var start := randi() % 16
	for dist in _ESCAPE_RINGS:
		for k in 16:
			var d := Vector2.from_angle((start + k) * TAU / 16.0)
			var q: Vector2 = p + d * float(dist)
			if arena.is_inside(q, r) and not is_lava(q) and not arena.circle_blocked(q, r):
				return d
	return (arena.bounds.get_center() - p).normalized()


## A random grass cell centre of a (grown) patch near `p`, for bots
## searching a concealed target; `p` plus a small offset when none is near.
func search_point(p: Vector2, rng: RandomNumberGenerator, max_dist: float = 120.0) -> Vector2:
	var best := -1
	var best_d := max_dist
	for i in patches.size():
		var e: Dictionary = patches[i]
		if e["state"] != Patch.GROWN:
			continue
		var g: Rect2 = e["grid"]
		var closest := Vector2(clampf(p.x, g.position.x, g.end.x), clampf(p.y, g.position.y, g.end.y))
		var d := closest.distance_to(p) + rng.randf() * 20.0
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return arena.clamp_inside(p + Vector2.from_angle(rng.randf() * TAU) * 40.0, 16.0)
	var centers: PackedVector2Array = patches[best]["centers"]
	return centers[rng.randi() % centers.size()]


## Fire touching tall grass burns the whole patch (spreading flames, then
## ash) and it regrows after GRASS_REGROW. Returns true if anything ignited.
func on_fire_at(p: Vector2, radius: float) -> bool:
	var lit := false
	for e in patches:
		if e["state"] != Patch.GROWN:
			continue
		var g: Rect2 = e["grid"]
		if not Geo.circle_vs_rect(p, radius, g):
			continue
		var touched := false
		for cc in e["centers"]:
			if Geo.circle_vs_rect(p, radius, Rect2(cc - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))):
				touched = true
				break
		if touched:
			_ignite(e, p)
			lit = true
	return lit


func _ignite(e: Dictionary, p: Vector2) -> void:
	var centers: PackedVector2Array = e["centers"]
	var delays := PackedFloat32Array()
	delays.resize(centers.size())
	var longest := 0.0
	for i in centers.size():
		delays[i] = centers[i].distance_to(p) / FLAME_SPREAD
		longest = maxf(longest, delays[i])
	# Per row: first and last flame (rows darken as the front passes).
	var rows: int = e["rows"]
	var g: Rect2 = e["grid"]
	var row_lo := PackedFloat32Array()
	var row_hi := PackedFloat32Array()
	row_lo.resize(rows)
	row_hi.resize(rows)
	row_lo.fill(INF)
	row_hi.fill(0.0)
	for i in centers.size():
		var r := clampi(int((centers[i].y - g.position.y) / CELL), 0, rows - 1)
		row_lo[r] = minf(row_lo[r], delays[i])
		row_hi[r] = maxf(row_hi[r], delays[i])
	e["delays"] = delays
	e["row_lo"] = row_lo
	e["row_hi"] = row_hi
	e["state"] = Patch.BURNING
	e["burn_time"] = 0.0
	e["timer"] = longest + FLAME_LIFE
	_burning += 1
	_changing += 1
	Audio.play("fire", p)


# -------------------------------------------------------------- simulation

## Per physics tick: patch states, then every on-field fighter's terrain
## effects and concealment. `hazards` = false outside the fight phase.
func update(world: CombatWorld, delta: float, hazards: bool = true) -> void:
	if world:
		_vfx = world.vfx
	_viewer_patch = -1
	if world:
		for f in world.fighters:
			_update_fighter(world, f, delta, hazards)
	tick_patches(delta)
	_ambient(delta)


func _update_fighter(world: CombatWorld, f: Fighter, delta: float, hazards: bool) -> void:
	if not f.is_alive() or not f.is_inside_tree():
		f.terrain_kind = NONE
		f.terrain_speed_mult = 1.0
		f.concealed = false
		f.terrain_alpha = 1.0
		return
	var id := f.get_instance_id()
	# Reveal: casting/attacking or losing HP (hits, damage over time).
	var last: int = _last_hp.get(id, f.hp)
	if f.hp < last or f.state == Fighter.State.CASTING:
		f.reveal_time = REVEAL_TIME
	else:
		f.reveal_time = maxf(0.0, f.reveal_time - delta)
	_last_hp[id] = f.hp
	var grounded := f.hidden_mode != "air" and f.hidden_mode != "under"
	var kind := terrain_at(f.position) if grounded else NONE
	f.terrain_kind = kind
	var mult := 1.0
	match kind:
		WATER:
			mult = WATER_BOOST if f.types.has("water") else WATER_SLOW
			if f.status.has("burn"):
				f.status.remove("burn")
				if _vfx:
					_vfx.burst(f.position + Vector2(0, -f.body_height * 0.5), Color(0.9, 0.9, 0.95, 0.8), 8, 40.0, 0.5, 3.0)
			_splash(f, id)
		LAVA:
			if hazards and not f.types.has("fire"):
				_lava_tick(f, id, delta)
	if kind != LAVA:
		_lava_acc[id] = 0.08  # first tick shortly after stepping in
	f.terrain_speed_mult = mult
	# Concealment in tall grass.
	var hidden := kind == GRASS and f.reveal_time <= 0.0 and not _enemy_near(world, f)
	f.concealed = hidden
	var target := 1.0
	if hidden:
		target = OWN_CONCEALED_ALPHA if f.team == viewer_team else 0.0
	f.terrain_alpha = move_toward(f.terrain_alpha, target, ALPHA_RATE * delta)
	if kind == GRASS and f.team == viewer_team:
		_viewer_patch = grass_patch_at(f.position)
		_viewer_y = f.position.y


func _enemy_near(world: CombatWorld, f: Fighter) -> bool:
	for o in world.fighters:
		if o.team != f.team and o.is_alive() and o.position.distance_squared_to(f.position) <= REVEAL_RANGE * REVEAL_RANGE:
			return true
	return false


func _lava_tick(f: Fighter, id: int, delta: float) -> void:
	var acc: float = _lava_acc.get(id, 0.08) - delta
	if acc <= 0.0:
		acc += LAVA_TICK
		# Dash i-frames let a well-timed dash cross a thin channel unharmed.
		if f.invuln <= 0.0:
			f.take_dot(maxi(1, int(round(f.max_hp * LAVA_DPS_PCT * LAVA_TICK))), null, "burn")
			if f.is_alive():
				f.status.apply("burn", null, LAVA_BURN)
			if _vfx:
				_vfx.burst(f.position, Color(1.0, 0.55, 0.15), 4, 50.0, 0.35, 2.5)
	_lava_acc[id] = acc


func _splash(f: Fighter, id: int) -> void:
	if _vfx == null or f.velocity.length_squared() < 900.0:
		return
	var frame := Engine.get_physics_frames() + id
	if frame % 7 == 0:
		_vfx.burst(f.position + Vector2(0, 1), Color(0.85, 0.96, 1.0, 0.9), 3, 45.0, 0.3, 2.0)
	if frame % 21 == 0:
		_vfx.ring(f.position, Color(0.85, 0.96, 1.0, 0.55), 6.0, 0.35)


## Advances burning / burnt / regrowing patches (also used by tests).
func tick_patches(delta: float) -> void:
	for i in patches.size():
		var e: Dictionary = patches[i]
		var state: int = e["state"]
		if state == Patch.GROWN:
			_fade_rows(e, i)
			continue
		e["timer"] = float(e["timer"]) - delta
		match state:
			Patch.BURNING:
				e["burn_time"] = float(e["burn_time"]) + delta
				_burn_visuals(e)
				if e["timer"] <= 0.0:
					e["state"] = Patch.BURNT
					e["timer"] = GRASS_REGROW
					_burning = maxi(0, _burning - 1)
					_set_rows(e, false, 1.0, 1.0)
			Patch.BURNT:
				if e["timer"] <= 0.0:
					e["state"] = Patch.GROWING
					e["timer"] = GRASS_GROW_TIME
					_set_rows(e, true, 0.2, 0.4)
				elif _vfx and e["timer"] > GRASS_REGROW - 2.5 and Engine.get_physics_frames() % 9 == 0:
					var centers: PackedVector2Array = e["centers"]
					_vfx.burst(centers[randi() % centers.size()], Color(0.35, 0.33, 0.32, 0.7), 1, 14.0, 0.8, 3.0)
			Patch.GROWING:
				var k := clampf(1.0 - float(e["timer"]) / GRASS_GROW_TIME, 0.0, 1.0)
				_set_rows(e, true, lerpf(0.2, 1.0, k), lerpf(0.4, 1.0, k))
				if e["timer"] <= 0.0:
					e["state"] = Patch.GROWN
					_changing = maxi(0, _changing - 1)
					_set_rows(e, true, 1.0, 1.0)
					queue_redraw()
	if _changing > 0:
		queue_redraw()


func _set_rows(e: Dictionary, on: bool, scale_y: float, alpha: float) -> void:
	for s in e["sprites"]:
		if s == null:
			continue
		var spr: Sprite2D = s
		spr.visible = on
		spr.scale = Vector2(1.0, scale_y)
		spr.modulate = Color(1, 1, 1, alpha)


## Rows in front of the local fighter fade so it stays readable inside.
func _fade_rows(e: Dictionary, i: int) -> void:
	var sprites: Array = e["sprites"]
	var g: Rect2 = e["grid"]
	for r in sprites.size():
		var s = sprites[r]
		if s == null:
			continue
		var spr: Sprite2D = s
		var bottom := g.position.y + (r + 1) * CELL
		var target := 1.0
		if i == _viewer_patch and bottom > _viewer_y and bottom < _viewer_y + CELL + ArenaArt.GRASS_OVER + 4.0:
			target = 0.6
		if not is_equal_approx(spr.modulate.a, target):
			spr.modulate.a = move_toward(spr.modulate.a, target, 0.1)


## Burning rows darken and fade as the flame front passes; embers + smoke.
func _burn_visuals(e: Dictionary) -> void:
	var t: float = e["burn_time"]
	var sprites: Array = e["sprites"]
	var centers: PackedVector2Array = e["centers"]
	var delays: PackedFloat32Array = e["delays"]
	var row_lo: PackedFloat32Array = e["row_lo"]
	var row_hi: PackedFloat32Array = e["row_hi"]
	for r in sprites.size():
		var s = sprites[r]
		if s == null or row_lo[r] == INF:
			continue
		var spr: Sprite2D = s
		# Row progress: from the earliest flame in this row to its last one.
		var p := clampf((t - row_lo[r]) / (row_hi[r] - row_lo[r] + FLAME_LIFE), 0.0, 1.0)
		spr.modulate = Color(1.0, 1.0 - p * 0.6, 1.0 - p * 0.85, 1.0 - p)
	if _vfx and Engine.get_physics_frames() % 3 == 0:
		for n in 2:
			var k := randi() % centers.size()
			var lt := t - delays[k]
			if lt < 0.0 or lt > FLAME_LIFE:
				continue
			_vfx.burst(centers[k] + Vector2(randf_range(-6, 6), -6), Color(1.0, 0.6, 0.15) if n == 0 else Color(1.0, 0.85, 0.3), 2, 38.0, 0.45, 2.5)
		if randf() < 0.4:
			_vfx.burst(centers[randi() % centers.size()] + Vector2(0, -10), Color(0.3, 0.28, 0.27, 0.6), 1, 16.0, 0.9, 4.0)


## Lava bubbles popping now and then.
func _ambient(delta: float) -> void:
	if lava_regions.is_empty() or _vfx == null:
		return
	_bubble_acc -= delta
	if _bubble_acc > 0.0:
		return
	_bubble_acc = randf_range(0.18, 0.4)
	var e: Dictionary = lava_regions[randi() % lava_regions.size()]
	var box: Rect2 = e["aabb"]
	for attempt in 6:
		var p := box.position + Vector2(randf() * box.size.x, randf() * box.size.y)
		if shape_sd(e, p) < -6.0:
			_vfx.burst(p, Color(1.0, 0.75, 0.25), 3, 26.0, 0.4, 2.0)
			_vfx.ring(p, Color(1.0, 0.55, 0.15, 0.7), 3.0, 0.3)
			return


# ----------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_time += delta
	# Lava glow pulses every frame; water glints flip twice a second.
	if not lava_regions.is_empty():
		queue_redraw()
	elif not water_regions.is_empty() and int((_time - delta) * 2.0) != int(_time * 2.0):
		queue_redraw()
	if _burning > 0:
		_fire.queue_redraw()
	elif _fire.get_meta("dirty", false):
		_fire.set_meta("dirty", false)
		_fire.queue_redraw()


func _draw() -> void:
	var glint := int(_time * 2.0) % 2 == 0
	# Base layer first (one texture: batches), then the animated overlays.
	for e in decals:
		_draw_src(_atlas, e, "src", Color.WHITE)
	for e in water_regions:
		_draw_src(_atlas, e, "src", Color.WHITE)
	for e in lava_regions:
		_draw_src(_atlas, e, "src", Color.WHITE)
	for e in water_regions:
		_draw_src(_atlas_over, e, "src_a" if glint else "src_b", Color.WHITE)
	for e in lava_regions:
		var k := 0.5 + 0.5 * sin(_time * 2.2 + float(e["phase"]))
		_draw_src(_atlas_over, e, "src_a", Color(1, 1, 1, 0.35 + 0.65 * k))
	for e in lava_regions:
		var k := 0.5 + 0.5 * sin(_time * 2.2 + float(e["phase"]))
		_draw_src(_atlas_over, e, "src_b", Color(1, 1, 1, 0.35 + 0.65 * (1.0 - k)))
	for e in patches:
		var state: int = e["state"]
		if state == Patch.GROWN:
			continue
		var a := 1.0
		if state == Patch.BURNING:
			a = clampf(float(e["burn_time"]) / maxf(float(e["burn_time"]) + float(e["timer"]), 0.01) * 1.5, 0.0, 1.0)
		elif state == Patch.GROWING:
			a = clampf(float(e["timer"]) / GRASS_GROW_TIME, 0.0, 1.0)
		var g: Rect2 = e["grid"]
		var src: Rect2i = e["ash"]
		draw_texture_rect_region(_atlas, Rect2(g.position, src.size), Rect2(src), Color(1, 1, 1, a))


func _draw_src(tex: Texture2D, e: Dictionary, field: String, col: Color) -> void:
	var src: Rect2i = e[field]
	var box: Rect2i = e["box"]
	draw_texture_rect_region(tex, Rect2(Vector2(box.position), Vector2(src.size)), Rect2(src), col)


## Pixel flames over burning cells (child canvas item above the actors).
func _draw_flames() -> void:
	if _burning <= 0:
		_fire.set_meta("dirty", true)
		return
	for e in patches:
		if e["state"] != Patch.BURNING:
			continue
		var t: float = e["burn_time"]
		var centers: PackedVector2Array = e["centers"]
		var delays: PackedFloat32Array = e["delays"]
		for k in centers.size():
			var lt := (t - delays[k]) / FLAME_LIFE
			if lt < 0.0 or lt > 1.0:
				continue
			var grow := sin(lt * PI)
			_flame(centers[k] + Vector2(-4, 4), 15.0 * grow, k)
			_flame(centers[k] + Vector2(4, -1), 11.0 * grow, k + 7)


## Tapered pixel flame (outer red, orange body, yellow core) swaying at the tip.
func _flame(b: Vector2, fh: float, seed_k: int) -> void:
	fh = roundf(fh * (0.85 + 0.15 * sin(_time * 23.0 + seed_k * 1.9)))
	if fh < 2.0:
		return
	var sway := roundf(sin(_time * 13.0 + seed_k) * 1.5)
	b = b.round()
	var red := Color(0.88, 0.2, 0.06, 0.9)
	var orange := Color(1.0, 0.55, 0.1)
	var yellow := Color(1.0, 0.93, 0.5)
	var h1 := roundf(fh * 0.45)
	var h2 := roundf(fh * 0.3)
	var h3 := fh - h1 - h2
	_fire.draw_rect(Rect2(b.x - 4, b.y - h1, 9, h1), red)
	_fire.draw_rect(Rect2(b.x - 3 + sway * 0.5, b.y - h1 - h2, 7, h2), red)
	_fire.draw_rect(Rect2(b.x - 1 + sway, b.y - fh, 3, h3), red)
	_fire.draw_rect(Rect2(b.x - 2, b.y - h1 - 1, 5, h1), orange)
	_fire.draw_rect(Rect2(b.x - 1 + sway * 0.5, b.y - h1 - h2, 3, h2), orange)
	_fire.draw_rect(Rect2(b.x - 1, b.y - roundf(h1 * 0.8), 3, roundf(h1 * 0.6)), yellow)
