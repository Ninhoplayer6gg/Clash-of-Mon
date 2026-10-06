class_name ActionExecutor
extends RefCounted
## Executes one timeline action of a cast. Action types ("do"):
##
##  projectile  - pooled projectile(s): speed, range, radius, count, spread,
##                homing, pierce, accel, explode{}, explode_on_end
##  melee       - hitbox attached to the caster: shape circle|sector|line
##  aoe         - area at "where": self/target/forward, optional telegraph delay,
##                count/stagger/scatter for multi-strikes
##  beam        - line hitbox (telegraph + active window), stops at walls
##  zone        - lingering ground area ticking damage/status
##  dash        - forced movement with optional attached hitbox
##  leap        - airborne jump to the aim point (untargetable), land{} aoe
##  burrow      - underground travel (untargetable), emerge{} aoe
##  teleport    - blink to the aim point (through walls)
##  vanish      - become untargetable/invisible for a duration
##  buff        - timed modifiers on the caster (speed, damage, armor...)
##  cleanse     - remove statuses from the caster
##  heal        - restore a % of max HP
##  vfx / shake - visual only


static func execute(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var world := f.world
	if world == null:
		return
	var kind: String = a.get("do", "")
	match kind:
		"projectile":
			_projectile(f, cast, a)
		"melee":
			_melee(f, cast, a)
		"aoe":
			_aoe(f, cast, a)
		"beam":
			_beam(f, cast, a)
		"zone":
			_zone(f, cast, a)
		"dash":
			_dash(f, cast, a)
		"leap":
			_leap(f, cast, a)
		"burrow":
			_burrow(f, cast, a)
		"teleport":
			_teleport(f, cast, a)
		"vanish":
			f.set_hidden("vanish", float(a.get("duration", 0.8)))
			world.vfx.burst(f.position, _color(a, "#5b3a8a"), 14, 70.0, 0.45, 3.0)
		"buff":
			var mods: Dictionary = a.get("mods", {})
			f.status.add_mod(a.get("id", cast.ability.id if cast.ability else "buff"), float(a.get("duration", 2.0)), mods)
			if a.has("color"):
				world.vfx.ring(f.position, _color(a, "#ffffff"), f.radius * 2.6, 0.35)
		"cleanse":
			f.status.cleanse(a.get("ids", ["burn", "poison", "paralysis", "slow"]))
		"heal":
			f.heal(int(f.max_hp * float(a.get("pct", 0.1))))
		"vfx":
			_vfx(f, cast, a)
		"shake":
			world.request_shake(float(a.get("amount", 3.0)), float(a.get("time", 0.15)), f)
		_:
			push_warning("Unknown action type '%s'" % kind)
	var sfx: String = a.get("sfx", "")
	if sfx != "":
		Audio.play(sfx, f.position)


static func _color(a: Dictionary, fallback: String, key: String = "color") -> Color:
	return Color.from_string(String(a.get(key, fallback)), Color.WHITE)


static func _projectile(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var count := int(a.get("count", 1))
	var spread := deg_to_rad(float(a.get("spread", 0.0)))
	var base_dir := cast.aim_dir
	var emit := f.get_emit_info(base_dir)
	var reach := float(a.get("range", cast.ability.reach if cast.ability else 200.0))
	if a.get("range_to_point", false):
		reach = clampf(f.position.distance_to(cast.aim_point), 20.0, reach)
	for i in count:
		var d := base_dir
		if count > 1:
			var t := (float(i) / float(count - 1)) - 0.5
			d = base_dir.rotated(spread * t)
		var jitter := float(a.get("jitter", 0.0))
		if jitter > 0.0:
			d = d.rotated(deg_to_rad(randf_range(-jitter, jitter)))
		var p := f.world.spawn_projectile(f, cast.ability, a, emit[0], d, cast.id)
		p.remaining = reach
		p.height = emit[1]


static func _melee(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var z := f.world.spawn_zone(f, cast.ability, a, cast.id)
	z.origin = f.position
	z.dir = cast.aim_dir
	z.follow = bool(a.get("follow", true))
	z.offset = float(a.get("offset", f.radius))
	z.bound_to_cast = bool(a.get("bound", false))
	z.follow_aim = bool(a.get("follow_aim", false))
	if z.shape == HitZone.Shape.LINE and bool(a.get("stop_at_walls", true)):
		z.length = f.world.arena.ray_length(z.anchor(), z.dir, z.length)


static func _aoe(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var count := int(a.get("count", 1))
	var stagger := float(a.get("stagger", 0.0))
	var scatter := float(a.get("scatter", 0.0))
	var center := _anchor_point(f, cast, a)
	for i in count:
		var c := center
		if i > 0 and scatter > 0.0:
			c += Vector2.from_angle(randf() * TAU) * randf_range(scatter * 0.4, scatter)
		var z := f.world.spawn_zone(f, cast.ability, a, cast.id)
		z.shape = HitZone.Shape.CIRCLE
		z.origin = f.world.arena.clamp_inside(c)
		z.dir = cast.aim_dir
		z.offset = 0.0
		z.delay = float(a.get("delay", 0.0)) + stagger * i
		z.telegraph = z.delay > 0.0
		z.follow = bool(a.get("follow", false))
		z.bound_to_cast = bool(a.get("bound", false))


static func _anchor_point(f: Fighter, cast: CastState, a: Dictionary) -> Vector2:
	match String(a.get("where", "self")):
		"target":
			return cast.aim_point
		"forward":
			return f.position + cast.aim_dir * float(a.get("offset", 30.0))
	return f.position


static func _beam(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var z := f.world.spawn_zone(f, cast.ability, a, cast.id)
	z.shape = HitZone.Shape.LINE
	z.origin = f.position
	z.dir = cast.aim_dir
	z.offset = float(a.get("offset", f.radius * 0.8))
	z.length = float(a.get("length", cast.ability.reach if cast.ability else 200.0))
	z.width = float(a.get("width", 8.0))
	z.delay = float(a.get("delay", 0.0))
	z.telegraph = z.delay > 0.0
	z.follow = bool(a.get("follow", true))
	z.follow_aim = bool(a.get("follow_aim", false))
	z.bound_to_cast = bool(a.get("bound", true))
	if bool(a.get("stop_at_walls", true)):
		z.length = f.world.arena.ray_length(z.anchor(), z.dir, z.length)


static func _zone(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var z := f.world.spawn_zone(f, cast.ability, a, cast.id)
	z.shape = HitZone.Shape.CIRCLE
	z.origin = f.world.arena.clamp_inside(_anchor_point(f, cast, a))
	z.offset = 0.0
	z.follow = false
	z.interval = float(a.get("interval", 0.5))
	z.max_hits = int(a.get("hits", 99))
	z.delay = float(a.get("delay", 0.0))
	z.telegraph = false
	z.fade = 0.4


static func _dash(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var dir := cast.aim_dir
	var dist := float(a.get("distance", 90.0))
	if String(a.get("towards", "aim")) == "point":
		dist = clampf(f.position.distance_to(cast.aim_point), 20.0, dist)
	var dur := float(a.get("duration", 0.18))
	f.start_forced_move(dir, dist, dur, bool(a.get("through_walls", false)), float(a.get("invulnerable", 0.0)))
	if a.has("hit"):
		var hit: Dictionary = a["hit"]
		var z := f.world.spawn_zone(f, cast.ability, hit, cast.id)
		z.origin = f.position
		z.dir = dir
		z.follow = true
		z.offset = float(hit.get("offset", 0.0))
		z.duration = float(hit.get("duration", dur))
		z.bound_to_cast = false
	if a.get("afterimages", true):
		f.afterimage_time = dur


static func _leap(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var max_dist := float(a.get("distance", 140.0))
	var target := cast.aim_point
	var to := target - f.position
	if to.length() > max_dist:
		to = to.normalized() * max_dist
	var dest := f.world.arena.find_free_position(f.position + to, f.radius)
	var dur := float(a.get("duration", 0.45))
	f.start_forced_move(to.normalized() if to.length() > 0.1 else cast.aim_dir, f.position.distance_to(dest), dur, true, 0.0)
	f.set_hidden("air", dur)
	if a.has("land"):
		var land: Dictionary = a["land"].duplicate()
		land["do"] = land.get("do", "aoe")
		land["where"] = "self"
		f.queue_action(dur, land, cast)


static func _burrow(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var max_dist := float(a.get("distance", 150.0))
	var to := cast.aim_point - f.position
	if to.length() > max_dist:
		to = to.normalized() * max_dist
	var dest := f.world.arena.find_free_position(f.position + to, f.radius)
	var dur := float(a.get("duration", 0.6))
	f.start_forced_move(to.normalized() if to.length() > 0.1 else cast.aim_dir, f.position.distance_to(dest), dur, true, 0.0)
	f.set_hidden("under", dur)
	f.world.vfx.burst(f.position, Color("#a07a48"), 12, 80.0, 0.4, 3.0)
	if a.has("emerge"):
		var em: Dictionary = a["emerge"].duplicate()
		em["do"] = em.get("do", "aoe")
		em["where"] = "self"
		f.queue_action(dur, em, cast)


static func _teleport(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var max_dist := float(a.get("distance", 120.0))
	var to := cast.aim_point - f.position
	if to.length() > max_dist:
		to = to.normalized() * max_dist
	if to.length() < 8.0:
		to = cast.aim_dir * max_dist
	var col := _color(a, "#6a3fa0")
	var from := f.position
	var dest := f.world.arena.find_free_position(f.position + to, f.radius)
	f.world.vfx.burst(from, col, 16, 90.0, 0.4, 3.0)
	f.world.vfx.afterimage_from(f, 0.35)
	f.teleport_to(dest)
	f.invuln = maxf(f.invuln, float(a.get("invulnerable", 0.12)))
	f.world.vfx.ring(dest, col, 22.0, 0.3)


static func _vfx(f: Fighter, cast: CastState, a: Dictionary) -> void:
	var pos := _anchor_point(f, cast, a)
	var col := _color(a, "#ffffff")
	match String(a.get("style", "burst")):
		"ring":
			f.world.vfx.ring(pos, col, float(a.get("radius", 30.0)), float(a.get("life", 0.35)))
		_:
			f.world.vfx.burst(pos, col, int(a.get("count", 12)), float(a.get("speed", 80.0)), float(a.get("life", 0.4)), float(a.get("size", 3.0)))
