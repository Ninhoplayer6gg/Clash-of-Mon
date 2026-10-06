class_name GroundFx
extends Node2D
## Ground-level drawing below the actors: telegraphs, lingering zones,
## projectile shadows and the local player's aim indicator.

var world: CombatWorld
## Aim preview written by the player controller.
var aim_active := false
var aim_origin := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var aim_reach := 100.0
var aim_point := Vector2.ZERO
var aim_type := "direction"
var aim_radius := 0.0
var aim_width := 0.0
var aim_color := Color(1, 1, 1, 0.5)


func _draw() -> void:
	if world == null:
		return
	for z in world.zones:
		if z.elapsed < z.delay and z.telegraph:
			_draw_telegraph(z)
		elif z.style == "ground" or z.action.get("ground", false):
			_draw_ground_zone(z)
	for p in world.projectiles:
		if p.height > 3.0:
			draw_set_transform(p.pos, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, p.size * 0.8, Color(0, 0, 0, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if aim_active:
		_draw_aim()


func _draw_telegraph(z: HitZone) -> void:
	var k := clampf(z.elapsed / maxf(z.delay, 0.01), 0.0, 1.0)
	var col := Color(z.color, 0.22 + 0.25 * k)
	match z.shape:
		HitZone.Shape.CIRCLE:
			var a := z.anchor()
			draw_circle(a, z.radius * k, Color(col, 0.25))
			draw_arc(a, z.radius, 0, TAU, 32, Color(col, 0.8), 1.5)
		HitZone.Shape.LINE:
			var n := z.dir.orthogonal() * z.width
			var s := z.anchor()
			var e := z.line_end()
			draw_colored_polygon(PackedVector2Array([s + n, e + n, e - n, s - n]), Color(col, 0.18 + 0.2 * k))
			draw_line(s, s + (e - s) * k, Color(col, 0.9), 1.5)
		HitZone.Shape.SECTOR:
			var ang := z.dir.angle()
			var a := z.anchor()
			var pts := PackedVector2Array([a])
			for j in 9:
				pts.append(a + Vector2.from_angle(ang - z.half_angle + z.half_angle * 2.0 * j / 8.0) * z.radius)
			draw_colored_polygon(pts, Color(col, 0.2))


func _draw_ground_zone(z: HitZone) -> void:
	var total := z.delay + z.duration
	var k := 1.0
	if z.elapsed > total:
		k = clampf(1.0 - (z.elapsed - total) / maxf(z.fade, 0.01), 0.0, 1.0)
	var a := z.anchor()
	var pulse := 0.85 + 0.15 * sin(z.elapsed * 8.0)
	draw_circle(a, z.radius, Color(z.color, 0.22 * k * pulse))
	draw_arc(a, z.radius, 0, TAU, 32, Color(z.color, 0.55 * k), 1.5)


func _draw_aim() -> void:
	var c := aim_color
	match aim_type:
		"point":
			draw_arc(aim_origin, aim_reach, 0, TAU, 48, Color(c, 0.35), 1.5)
			draw_line(aim_origin, aim_point, Color(c, 0.35), 1.0)
			draw_circle(aim_point, maxf(aim_radius, 10.0), Color(c, 0.22))
			draw_arc(aim_point, maxf(aim_radius, 10.0), 0, TAU, 28, Color(c, 0.85), 1.5)
		"self":
			draw_arc(aim_origin, maxf(aim_radius, 24.0), 0, TAU, 40, Color(c, 0.8), 1.5)
			draw_circle(aim_origin, maxf(aim_radius, 24.0), Color(c, 0.15))
		_:
			var w := maxf(aim_width, 5.0)
			var n := aim_dir.orthogonal() * w
			var s := aim_origin + aim_dir * 8.0
			var e := aim_origin + aim_dir * aim_reach
			draw_colored_polygon(PackedVector2Array([s + n, e + n, e - n, s - n]), Color(c, 0.2))
			draw_line(s, e, Color(c, 0.8), 1.5)
			draw_line(e, e - aim_dir.rotated(0.5) * 8.0, Color(c, 0.9), 1.5)
			draw_line(e, e - aim_dir.rotated(-0.5) * 8.0, Color(c, 0.9), 1.5)
