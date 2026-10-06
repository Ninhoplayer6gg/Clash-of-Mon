class_name CastState
extends RefCounted
## Runtime state of an ability being cast: a timeline of actions.

var ability: AbilityDef
var stage := {}
var slot := ""
var id := 0
var elapsed := 0.0
var duration := 0.3
var actions: Array = []  # [[time, action_dict], ...] sorted by time
var next := 0
var aim_dir := Vector2.RIGHT
var aim_point := Vector2.ZERO
var move_mult := 0.0
var super_armor := false
var lock_aim := true
var channel_aim := false
var anim := ""
var anim_speed := 1.0
var hit_time := 0.0
var cancel_after := 0.0  # time after which dash can cancel the recovery
var is_transform := false
var transform_form := ""


func all_fired() -> bool:
	return next >= actions.size()


func can_dash_cancel() -> bool:
	return all_fired() and elapsed >= cancel_after
