class_name CombatWorld
extends Node2D
## Owns the live combat simulation that is not a Fighter: pooled projectiles
## and hit zones, hit resolution (damage, knockback, statuses, passives, ult
## charge) and their rendering. Everything is drawn from this single canvas
## item (plus GroundFx for telegraphs), so dozens of projectiles cost one
## batch and zero nodes.

signal hit_landed(attacker: Fighter, target: Fighter, amount: int, effectiveness: String)
signal shake_requested(amount: float, time: float)

var arena: Arena
var vfx: VfxLayer
var overlay: WorldOverlay
var ground_fx: GroundFx
var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var zones: Array[HitZone] = []
var proj_pool := ObjectPool.new(func(): return Projectile.new(), 48)
var zone_pool := ObjectPool.new(func(): return HitZone.new(), 32)
var show_hitboxes := false
var total_hits := 0
var _info := DamageInfo.new()
var _time := 0.0


func _ready() -> void:
	z_index = 10


# ------------------------------------------------------------------ fighters

func register_fighter(f: Fighter) -> void:
	if not fighters.has(f):
		fighters.append(f)


func unregister_fighter(f: Fighter) -> void:
	fighters.erase(f)
	# Zones following a benched fighter must not keep running.
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].owner == f and zones[i].follow:
			_kill_zone(i)


func nearest_enemy(f: Fighter, max_range: float) -> Fighter:
	var best: Fighter = null
	var best_d := max_range * max_range
	for o in fighters:
		if o.team == f.team or not o.is_alive() or o.hidden_mode != "":
			continue
		var d := f.position.distance_squared_to(o.position)
		if d < best_d:
			best_d = d
			best = o
	return best


func enemy_of(f: Fighter) -> Fighter:
	for o in fighters:
		if o.team != f.team and o.is_alive():
			return o
	return null


# --------------------------------------------------------------- spawning

func spawn_projectile(src: Fighter, ability: AbilityDef, a: Dictionary, pos: Vector2, dir: Vector2, cast_id: int) -> Projectile:
	var p: Projectile = proj_pool.acquire()
	p.active = true
	p.owner = src
	p.team = src.team
	p.ability = ability
	p.action = a
	p.pos = pos
	p.prev_pos = pos
	p.dir = dir.normalized()
	p.speed = float(a.get("speed", 300.0))
	p.accel = float(a.get("accel", 0.0))
	p.max_speed = float(a.get("max_speed", 1200.0))
	p.radius = float(a.get("radius", 6.0))
	p.remaining = float(a.get("range", 200.0))
	p.homing = deg_to_rad(float(a.get("homing", 0.0)))
	p.pierce = bool(a.get("pierce", false))
	p.ignore_walls = bool(a.get("ignore_walls", false))
	p.cast_id = cast_id
	var v: Dictionary = a.get("vfx", {})
	p.color = Color.from_string(String(v.get("color", "#ffffff")), Color.WHITE)
	p.color2 = Color.from_string(String(v.get("color2", v.get("color", "#ffffff"))), Color.WHITE)
	p.size = float(v.get("size", p.radius))
	p.style = String(v.get("style", "orb"))
	projectiles.append(p)
	return p


func spawn_zone(src: Fighter, ability: AbilityDef, a: Dictionary, cast_id: int) -> HitZone:
	var z: HitZone = zone_pool.acquire()
	z.active = true
	z.owner = src
	z.team = src.team
	z.ability = ability
	z.action = a
	z.cast_id = cast_id
	match String(a.get("shape", "circle")):
		"sector", "cone", "arc":
			z.shape = HitZone.Shape.SECTOR
		"line":
			z.shape = HitZone.Shape.LINE
		_:
			z.shape = HitZone.Shape.CIRCLE
	z.radius = float(a.get("radius", 20.0))
	z.half_angle = deg_to_rad(float(a.get("angle", 100.0))) * 0.5
	z.length = float(a.get("length", 60.0))
	z.width = float(a.get("width", 8.0))
	z.duration = float(a.get("duration", 0.08))
	z.delay = float(a.get("delay", 0.0))
	z.interval = float(a.get("interval", 0.0))
	z.max_hits = int(a.get("hits", 1))
	var v: Dictionary = a.get("vfx", {})
	z.color = Color.from_string(String(v.get("color", "#ffffff")), Color.WHITE)
	z.style = String(v.get("style", "slash"))
	z.fade = float(v.get("fade", 0.14))
	zones.append(z)
	return z


func cancel_owner_zones(src: Fighter) -> void:
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].owner == src:
			_kill_zone(i)


# -------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	_time += delta
	_update_projectiles(delta)
	_update_zones(delta)


func _update_projectiles(delta: float) -> void:
	var i := projectiles.size() - 1
	while i >= 0:
		var p: Projectile = projectiles[i]
		if not _step_projectile(p, delta):
			_kill_projectile(i)
		i -= 1


## Returns false when the projectile must be removed.
func _step_projectile(p: Projectile, delta: float) -> bool:
	p.age += delta
	if not is_instance_valid(p.owner):
		return false
	if p.homing > 0.0:
		var t := nearest_enemy(p.owner, 260.0)
		if t:
			var want := (t.position - p.pos).normalized()
			var ang := p.dir.angle_to(want)
			p.dir = p.dir.rotated(clampf(ang, -p.homing * delta, p.homing * delta))
	if p.accel != 0.0:
		p.speed = clampf(p.speed + p.accel * delta, 20.0, p.max_speed)
	var step := p.speed * delta
	p.prev_pos = p.pos
	p.pos += p.dir * step
	p.remaining -= step
	for f in fighters:
		if f.team == p.team or not f.can_be_hit():
			continue
		var fid := f.get_instance_id()
		if p.hit_ids.has(fid):
			continue
		if Geo.circle_vs_capsule(f.position, f.radius, p.prev_pos, p.pos, p.radius):
			if apply_hit(p.owner, f, p.ability, p.action, p.pos, p.dir, p.power_mult):
				p.hit_ids.append(fid)
				vfx.burst(p.pos, p.color, 6, 70.0, 0.25, 2.5)
				if p.action.has("explode"):
					_explode(p)
				if not p.pierce:
					return false
	if not p.ignore_walls and arena.segment_blocked(p.prev_pos, p.pos, p.radius * 0.4):
		vfx.burst(p.pos, p.color, 5, 50.0, 0.25, 2.0)
		arena.on_projectile_impact(p.pos, p.action)
		if p.action.has("explode"):
			_explode(p)
		return false
	if p.remaining <= 0.0:
		if p.action.has("explode") and p.action.get("explode_on_end", false):
			_explode(p)
		elif p.style != "wave":
			vfx.burst(p.pos, p.color, 3, 30.0, 0.2, 1.5)
		return false
	return true


func _explode(p: Projectile) -> void:
	var e: Dictionary = p.action["explode"]
	var z := spawn_zone(p.owner, p.ability, e, p.cast_id)
	z.shape = HitZone.Shape.CIRCLE
	z.origin = p.pos
	z.offset = 0.0
	z.duration = float(e.get("duration", 0.1))
	z.follow = false
	# The direct target already took the projectile hit; the blast applies
	# its own (splash) damage on top, by design.
	vfx.ring(p.pos, z.color, z.radius, 0.3)
	request_shake(2.0, 0.12, p.owner)
	if e.has("linger"):
		var l: Dictionary = e["linger"]
		var lz := spawn_zone(p.owner, p.ability, l, p.cast_id)
		lz.shape = HitZone.Shape.CIRCLE
		lz.origin = p.pos
		lz.offset = 0.0
		lz.follow = false
		lz.interval = float(l.get("interval", 0.5))
		lz.max_hits = int(l.get("hits", 99))
		lz.fade = 0.4


func _kill_projectile(i: int) -> void:
	var p: Projectile = projectiles[i]
	projectiles[i] = projectiles[projectiles.size() - 1]
	projectiles.pop_back()
	proj_pool.release(p)


func _update_zones(delta: float) -> void:
	var i := zones.size() - 1
	while i >= 0:
		var z: HitZone = zones[i]
		if not _step_zone(z, delta):
			_kill_zone(i)
		i -= 1


func _step_zone(z: HitZone, delta: float) -> bool:
	z.elapsed += delta
	if not is_instance_valid(z.owner):
		return false
	if z.follow:
		if not z.owner.is_inside_tree() or not z.owner.is_alive():
			return false
		z.origin = z.owner.position
		if z.follow_aim:
			z.dir = z.owner.aim_dir
		if z.shape == HitZone.Shape.LINE and z.action.get("stop_at_walls", true):
			z.length = arena.ray_length(z.anchor(), z.dir, float(z.action.get("length", z.length)))
	if z.bound_to_cast and z.elapsed < z.delay + z.duration:
		var c := z.owner.cast
		if c == null or c.id != z.cast_id:
			return false
	if z.is_live():
		for f in fighters:
			if f.team == z.team or not f.can_be_hit():
				continue
			if not _zone_overlaps(z, f):
				continue
			var fid := f.get_instance_id()
			var entry: Array = z.hit_log.get(fid, [0, -1.0])
			if entry[0] >= z.max_hits or z.elapsed < entry[1]:
				continue
			var src := z.anchor() if z.shape != HitZone.Shape.LINE else z.origin
			var dir := _knock_dir(z, f, src)
			if apply_hit(z.owner, f, z.ability, z.action, src, dir, z.power_mult):
				entry[0] += 1
				entry[1] = z.elapsed + (z.interval if z.interval > 0.0 else 9999.0)
				z.hit_log[fid] = entry
				z.hits_landed += 1
				if z.action.get("stop_owner_on_hit", false):
					z.owner.forced_time = minf(z.owner.forced_time, 0.02)
	return z.elapsed < z.delay + z.duration + z.fade


func _knock_dir(z: HitZone, f: Fighter, src: Vector2) -> Vector2:
	match String(z.action.get("kb_dir", "auto")):
		"forward":
			return z.dir
		"pull":
			return (src - f.position).normalized()
		"away":
			return (f.position - src).normalized()
	if z.shape == HitZone.Shape.LINE:
		return z.dir
	var d := f.position - src
	if d.length_squared() < 1.0:
		return z.dir
	# Melee: blend outward with the swing direction for readable knockback.
	return (d.normalized() + z.dir * 0.6).normalized()


func _zone_overlaps(z: HitZone, f: Fighter) -> bool:
	match z.shape:
		HitZone.Shape.CIRCLE:
			return f.position.distance_to(z.anchor()) <= z.radius + f.radius
		HitZone.Shape.SECTOR:
			return Geo.circle_vs_sector(f.position, f.radius, z.anchor(), z.dir, z.radius, z.half_angle)
		HitZone.Shape.LINE:
			return Geo.circle_vs_capsule(f.position, f.radius, z.anchor(), z.line_end(), z.width)
	return false


func _kill_zone(i: int) -> void:
	var z: HitZone = zones[i]
	zones[i] = zones[zones.size() - 1]
	zones.pop_back()
	zone_pool.release(z)


# ------------------------------------------------------------------ hits

func apply_hit(attacker: Fighter, target: Fighter, ability: AbilityDef, a: Dictionary, source_pos: Vector2, dir: Vector2, power_mult: float = 1.0) -> bool:
	if not target.can_be_hit():
		return false
	var info := _info
	info.reset()
	info.attacker = attacker
	info.target = target
	info.ability = ability
	info.action = a
	info.move_type = String(a.get("type", ability.move_type if ability else "normal"))
	info.category = String(a.get("category", ability.category if ability else "physical"))
	info.power = float(a.get("power", 0.0)) * power_mult
	info.contact = bool(a.get("contact", false))
	info.source_pos = source_pos
	info.direction = dir
	info.knockback = float(a.get("knockback", 0.0))
	if a.has("hitstun"):
		info.hitstun = float(a["hitstun"])
	elif info.power >= 220.0:
		info.hitstun = clampf(0.05 + info.power * 0.00035, 0.1, float(GameData.cfg("damage", "hitstun_max", 0.4)))
	info.tags = a.get("tags", [])
	_speed_scaling(info)
	if attacker and is_instance_valid(attacker):
		attacker.passive.modify_outgoing(info)
	target.passive.modify_incoming(info)
	if info.cancelled:
		return false
	DamageCalc.compute(info)
	target.receive_hit(info)
	var amount := info.amount
	total_hits += 1
	if attacker and is_instance_valid(attacker):
		attacker.damage_dealt += amount
		var ult_rate: float = GameData.cfg("ultimate", "charge_per_damage_dealt", 1.25)
		if ability == null or ability.slot != "ult":
			attacker.gain_ult(float(amount) / float(target.max_hp) * 100.0 * ult_rate)
		attacker.gain_mega(float(amount) / float(target.max_hp) * 100.0 * float(GameData.cfg("mega", "charge_per_damage_dealt", 0.9)))
		for m in attacker.status.mods:
			if m.has("lifesteal"):
				attacker.heal(int(amount * float(m["lifesteal"])))
	target.gain_ult(float(amount) / float(target.max_hp) * 100.0 * float(GameData.cfg("ultimate", "charge_per_damage_taken", 0.45)))
	target.gain_mega(float(amount) / float(target.max_hp) * 100.0 * float(GameData.cfg("mega", "charge_per_damage_taken", 0.6)))
	# Status effects
	var st = a.get("status")
	if st is Dictionary and target.is_alive():
		var chance := float(st.get("chance", 1.0))
		if randf() <= chance:
			target.status.apply(String(st.get("id", "")), attacker, float(st.get("duration", -1.0)))
	if attacker and is_instance_valid(attacker):
		attacker.passive.on_hit_dealt(info)
	target.passive.on_hit_taken(info)
	# Feedback
	var eff := info.effectiveness_label()
	var col := GameData.type_color(info.move_type)
	vfx.hit_spark(target.position + Vector2(0, -target.body_height * 0.45), col, clampf(amount / 120.0, 0.6, 2.2))
	overlay.add_damage(target.position + Vector2(0, -target.body_height - 4.0), amount, eff, target.is_player)
	Audio.play("hit_heavy" if info.power >= 380.0 else "hit", target.position)
	if info.power >= 380.0:
		request_shake(clampf(info.power / 160.0, 2.0, 6.0), 0.18, attacker, target)
	if Settings.vibration and target.is_player and info.power >= 250.0:
		Input.vibrate_handheld(35)
	hit_landed.emit(attacker, target, amount, eff)
	return true


## Electro Ball style scaling: "speed_scaling": [min_mult, max_mult].
func _speed_scaling(info: DamageInfo) -> void:
	var sc = info.action.get("speed_scaling")
	if not sc is Array or info.attacker == null:
		return
	var mine := info.attacker.move_speed * info.attacker.status.speed_mult()
	var theirs := maxf(info.target.move_speed * info.target.status.speed_mult(), 1.0)
	info.mult *= clampf(mine / theirs, float(sc[0]), float(sc[1]))


func on_dot(target: Fighter, amount: int, status_id: String) -> void:
	var col := Color.from_string(String(GameData.status_def(status_id).get("color", "#dddddd")), Color.WHITE)
	overlay.add_text(target.position + Vector2(randf_range(-6, 6), -target.body_height - 2.0), str(amount), col, 0.8)


func request_shake(amount: float, time: float, a: Fighter = null, b: Fighter = null) -> void:
	if not Settings.screen_shake:
		return
	if (a and a.is_player) or (b and b.is_player) or (a == null and b == null):
		shake_requested.emit(amount, time)


# ----------------------------------------------------------------- drawing

func _process(_delta: float) -> void:
	queue_redraw()
	if ground_fx:
		ground_fx.queue_redraw()


func _draw() -> void:
	for z in zones:
		_draw_zone(z)
	for p in projectiles:
		_draw_projectile(p)
	if show_hitboxes:
		_draw_debug()


func _draw_projectile(p: Projectile) -> void:
	var c := p.pos - Vector2(0, p.height)
	var s := p.size
	match p.style:
		"bolt":
			var back := c - p.dir * s * 2.4
			var n := p.dir.orthogonal()
			var pts := PackedVector2Array([back, back.lerp(c, 0.33) + n * s * 0.6, back.lerp(c, 0.66) - n * s * 0.6, c])
			draw_polyline(pts, p.color2, s * 0.9)
			draw_polyline(pts, p.color, s * 0.4)
		"water":
			draw_line(c - p.dir * s * 2.2, c, Color(p.color2, 0.6), s * 0.9)
			draw_circle(c, s * 0.6, p.color)
		"bone":
			var n := p.dir.orthogonal().rotated(p.age * 18.0)
			draw_line(c - n * s, c + n * s, p.color, 3.0)
			draw_circle(c - n * s, 2.2, p.color)
			draw_circle(c + n * s, 2.2, p.color)
		"wave":
			var n := p.dir.orthogonal()
			var k := 1.0 + 0.15 * sin(p.age * 20.0)
			for j in 3:
				var off := c - p.dir * (j * 5.0)
				draw_arc(off, s * k, p.dir.angle() - 1.0, p.dir.angle() + 1.0, 10, Color(p.color, 0.8 - j * 0.25), 2.0)
		"fire":
			draw_circle(c - p.dir * s * 0.7, s * 0.8, Color(p.color2, 0.55))
			draw_circle(c, s, p.color2)
			draw_circle(c + p.dir * s * 0.2, s * 0.6, p.color)
		_:
			# "orb" and variants: glow + core
			var pulse := 1.0 + 0.12 * sin(p.age * 24.0)
			draw_circle(c, s * 1.45 * pulse, Color(p.color2, 0.35))
			draw_circle(c, s * pulse, p.color2)
			draw_circle(c - p.dir * s * 0.15, s * 0.55, p.color)


func _draw_zone(z: HitZone) -> void:
	if z.elapsed < z.delay:
		return  # telegraph drawn by GroundFx
	var t_live := z.elapsed - z.delay
	var total := z.duration + z.fade
	var k := clampf(1.0 - maxf(0.0, t_live - z.duration) / maxf(z.fade, 0.01), 0.0, 1.0)
	var col := Color(z.color, z.color.a * k)
	var a := z.anchor()
	match z.style:
		"slash":
			if z.shape == HitZone.Shape.SECTOR:
				var ang := z.dir.angle()
				var prog := clampf(t_live / maxf(z.duration, 0.05), 0.0, 1.0)
				var start := ang - z.half_angle
				var sweep := z.half_angle * 2.0 * (0.4 + 0.6 * prog)
				draw_arc(a - z.dir * z.radius * 0.35, z.radius * 0.95, start, start + sweep, 14, col, 4.0)
				draw_arc(a - z.dir * z.radius * 0.35, z.radius * 0.75, start, start + sweep, 14, Color(1, 1, 1, 0.7 * k), 2.0)
			else:
				draw_arc(a, z.radius, 0, TAU, 20, col, 3.0)
		"thrust":
			draw_line(z.origin, a + z.dir * z.radius, col, 5.0 * k + 1.0)
			draw_circle(a + z.dir * z.radius * 0.6, z.radius * 0.5, Color(col, col.a * 0.5))
		"burst":
			var r := z.radius * (0.6 + 0.4 * clampf(t_live / 0.12, 0.0, 1.0))
			draw_circle(a, r, Color(col, col.a * 0.35))
			draw_arc(a, r, 0, TAU, 28, col, 3.0)
		"bolt":
			var top := a + Vector2(0, -160)
			var pts := PackedVector2Array()
			for j in 7:
				var y := lerpf(top.y, a.y, j / 6.0)
				pts.append(Vector2(a.x + (randf() - 0.5) * 10.0 * (1.0 - j / 6.0), y))
			draw_polyline(pts, Color(1, 1, 0.6, k), 4.0)
			draw_polyline(pts, Color(1, 1, 1, k), 1.5)
			draw_circle(a, z.radius * 0.8, Color(col, 0.35 * k))
			draw_arc(a, z.radius, 0, TAU, 24, col, 2.0)
		"beam":
			var e := z.line_end()
			var w := z.width * (1.0 + 0.15 * sin(_time * 40.0))
			draw_line(a, e, Color(col, col.a * 0.45), w * 2.0)
			draw_line(a, e, col, w * 1.1)
			draw_line(a, e, Color(1, 1, 1, 0.8 * k), maxf(1.5, w * 0.35))
			draw_circle(e, w * 1.1, col)
		"cone":
			var ang := z.dir.angle()
			var pts := PackedVector2Array([a])
			for j in 9:
				var aa := ang - z.half_angle + z.half_angle * 2.0 * j / 8.0
				pts.append(a + Vector2.from_angle(aa) * z.radius * (0.9 + 0.1 * sin(_time * 30.0 + j)))
			draw_colored_polygon(pts, Color(col, col.a * 0.35))
			for j in 5:
				var dd := z.dir.rotated(randf_range(-z.half_angle, z.half_angle))
				var rr := randf_range(0.2, 1.0) * z.radius
				draw_circle(a + dd * rr, 2.0 + rr * 0.08, Color(1.0, 0.85, 0.3, k) if j % 2 == 0 else Color(col, k))
		"ring":
			var r := z.radius * clampf(0.3 + t_live / maxf(z.duration, 0.05) * 0.7, 0.3, 1.0)
			draw_arc(a, r, 0, TAU, 32, col, 4.0)
			draw_arc(a, r * 0.8, 0, TAU, 32, Color(col, col.a * 0.4), 2.0)
		"spin":
			var rot := _time * 25.0
			for j in 3:
				draw_arc(a, z.radius, rot + j * TAU / 3.0, rot + j * TAU / 3.0 + 1.2, 8, col, 3.0)
		"none", "ground":
			pass
		_:
			draw_circle(a, z.radius, Color(col, col.a * 0.3))


func _draw_debug() -> void:
	for f in fighters:
		draw_arc(f.position, f.radius, 0, TAU, 20, Color(0.2, 1.0, 0.3, 0.9) if f.can_be_hit() else Color(0.6, 0.6, 0.6, 0.6), 1.0)
		draw_line(f.position, f.position + f.aim_dir * 18.0, Color(0.2, 1, 0.3, 0.8), 1.0)
	for z in zones:
		var c := Color(1, 0.2, 0.2, 0.9) if z.is_live() else Color(1, 0.6, 0.2, 0.5)
		match z.shape:
			HitZone.Shape.CIRCLE:
				draw_arc(z.anchor(), z.radius, 0, TAU, 24, c, 1.0)
			HitZone.Shape.SECTOR:
				var ang := z.dir.angle()
				var a := z.anchor()
				draw_arc(a, z.radius, ang - z.half_angle, ang + z.half_angle, 12, c, 1.0)
				draw_line(a, a + Vector2.from_angle(ang - z.half_angle) * z.radius, c, 1.0)
				draw_line(a, a + Vector2.from_angle(ang + z.half_angle) * z.radius, c, 1.0)
			HitZone.Shape.LINE:
				var n := z.dir.orthogonal() * z.width
				var s := z.anchor()
				var e := z.line_end()
				draw_polyline(PackedVector2Array([s + n, e + n, e - n, s - n, s + n]), c, 1.0)
	for p in projectiles:
		draw_arc(p.pos, p.radius, 0, TAU, 12, Color(1, 0.8, 0.1, 0.9), 1.0)
