class_name Geo
extends RefCounted
## Small allocation-free geometry helpers used by hit detection.


## Distance squared from point p to segment ab.
static func dist2_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.000001:
		return p.distance_squared_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)


## True if a circle (c, r) overlaps a capsule from a to b with radius w.
static func circle_vs_capsule(c: Vector2, r: float, a: Vector2, b: Vector2, w: float) -> bool:
	var rr := r + w
	return dist2_point_segment(c, a, b) <= rr * rr


## True if a circle (c, r) overlaps an arc/cone sector.
static func circle_vs_sector(c: Vector2, r: float, origin: Vector2, dir: Vector2, radius: float, half_angle: float) -> bool:
	var d := c - origin
	var dist := d.length()
	if dist > radius + r:
		return false
	if dist <= r + 2.0:
		return true
	var ang := absf(dir.angle_to(d))
	# Widen the cone by the angular size of the target circle.
	var slack := asin(clampf(r / dist, 0.0, 1.0))
	return ang <= half_angle + slack


static func circle_vs_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return c.distance_squared_to(closest) <= r * r


## Swept circle along a->b against a static circle (center, cr).
static func sweep_circle_circle(a: Vector2, b: Vector2, r: float, center: Vector2, cr: float) -> bool:
	return circle_vs_capsule(center, cr, a, b, r)
