class_name HitZone
extends RefCounted
## Pooled melee / area / beam hitbox. Optionally follows its owner and can
## show a telegraph before becoming active (delay).

enum Shape { CIRCLE, SECTOR, LINE }

var active := false
var owner: Fighter
var team := 0
var ability: AbilityDef
var action := {}
var shape := Shape.CIRCLE
var origin := Vector2.ZERO
var dir := Vector2.RIGHT
var offset := 0.0       # distance along dir from the owner/origin
var radius := 20.0      # circle radius / sector radius
var half_angle := 0.6   # sector half angle (radians)
var length := 100.0     # line length
var width := 8.0        # line half width
var follow := false     # re-anchor on owner each tick
var follow_aim := false # rotate with owner's aim while channeling
var delay := 0.0        # telegraph time before it can hit
var duration := 0.1     # active window after the delay
var elapsed := 0.0
var interval := 0.0     # >0: can hit the same target every `interval`
var max_hits := 1       # per target
var hit_log := {}       # instance id -> [count, next_time]
var cast_id := 0
var bound_to_cast := false
var power_mult := 1.0
var hits_landed := 0
# Visuals
var color := Color.WHITE
var style := "slash"
var telegraph := false
var fade := 0.12


func reset() -> void:
	active = false
	owner = null
	ability = null
	action = {}
	hit_log.clear()
	elapsed = 0.0
	delay = 0.0
	follow = false
	follow_aim = false
	bound_to_cast = false
	power_mult = 1.0
	hits_landed = 0
	telegraph = false
	interval = 0.0
	max_hits = 1
	offset = 0.0


func is_live() -> bool:
	return elapsed >= delay and elapsed < delay + duration


## World-space centre of the shape (for circles/sectors) or line start.
func anchor() -> Vector2:
	return origin + dir * offset


func line_end() -> Vector2:
	return anchor() + dir * length
