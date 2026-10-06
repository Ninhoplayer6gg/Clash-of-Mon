class_name Projectile
extends RefCounted
## Pooled projectile state. CombatWorld moves, collides and draws them, so a
## projectile costs no node, no physics body and no allocation when reused.

var active := false
var owner: Fighter
var team := 0
var ability: AbilityDef
var action := {}
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var dir := Vector2.RIGHT
var speed := 300.0
var accel := 0.0
var max_speed := 1000.0
var radius := 6.0
var remaining := 200.0
var age := 0.0
var homing := 0.0  # rad/s
var pierce := false
var ignore_walls := false
var hit_ids: Array[int] = []
var power_mult := 1.0
var cast_id := 0
# Visuals
var color := Color.WHITE
var color2 := Color.WHITE
var size := 6.0
var style := "orb"
var trail := 0.0
var height := 8.0  # visual elevation above the ground point


func reset() -> void:
	active = false
	owner = null
	ability = null
	action = {}
	hit_ids.clear()
	age = 0.0
	homing = 0.0
	pierce = false
	ignore_walls = false
	accel = 0.0
	power_mult = 1.0
	trail = 0.0
