class_name PlayerController
extends Node
## Translates local input (keyboard + mouse, gamepad, touch controls) into
## FighterInput commands for the player's active fighter.
##
## Aim sources, in priority order:
##  1. touch drag on a skill button (MobileControls)
##  2. gamepad right stick
##  3. mouse cursor (desktop, while the mouse is being used)
##  4. none -> abilities auto-aim (nearest enemy / facing direction)

signal switch_requested(direction: int)
signal pause_requested

var fighter: Fighter
var controls: MobileControls
var ground_fx: GroundFx
var enabled := true
var _mouse_active_until := 0.0
var _time := 0.0


func _ready() -> void:
	process_physics_priority = -10


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active_until = _time + 2.5
	if event.is_action_pressed("pause"):
		pause_requested.emit()
	elif event.is_action_pressed("switch_prev"):
		switch_requested.emit(-1)
	elif event.is_action_pressed("switch_next"):
		switch_requested.emit(1)


func _physics_process(delta: float) -> void:
	_time += delta
	if fighter == null or not is_instance_valid(fighter) or not enabled:
		if ground_fx:
			ground_fx.aim_active = false
		return
	var inp := fighter.input
	var touch := controls != null and controls.visible
	# Movement
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch and controls.move_vector != Vector2.ZERO:
		mv = controls.move_vector
	inp.move = mv.limit_length(1.0)
	# Aim
	var aim := Vector2.ZERO
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse_aim := not touch and _time < _mouse_active_until
	if stick.length() > 0.35:
		aim = stick.normalized()
	elif mouse_aim:
		aim = (fighter.get_global_mouse_position() - fighter.position)
		if aim.length() < 4.0:
			aim = Vector2.ZERO
	if touch and controls.aim_slot != "" and controls.aim_vector != Vector2.ZERO:
		aim = controls.aim_vector
	inp.aim = aim.normalized() if aim != Vector2.ZERO else Vector2.ZERO
	# Buttons (keyboard / gamepad)
	for slot in InputActions.SKILL_ACTIONS:
		if Input.is_action_just_pressed(slot):
			inp.request_cast(slot, inp.aim, _mouse_strength(slot) if mouse_aim else 1.0)
	if Input.is_action_pressed("basic") and inp.cast_slot == "" and fighter.is_ready("basic") and fighter.can_act():
		inp.request_cast("basic", inp.aim, 1.0)
	if not touch:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and inp.cast_slot == "" and fighter.is_ready("basic") and fighter.can_act():
			inp.request_cast("basic", inp.aim, 1.0)
	if Input.is_action_just_pressed("dash"):
		inp.dash = true
	if Input.is_action_just_pressed("mega"):
		inp.mega = true
	# Touch controls
	if touch:
		controls.fighter = fighter
		for r in controls.requests:
			inp.request_cast(r[0], r[1], r[2])
		controls.requests.clear()
		if controls.basic_held and inp.cast_slot == "" and fighter.is_ready("basic") and fighter.can_act():
			inp.request_cast("basic", controls.basic_aim, 1.0)
		if controls.dash_requested:
			controls.dash_requested = false
			inp.dash = true
		if controls.mega_requested:
			controls.mega_requested = false
			inp.mega = true
	_update_aim_preview(touch)


func _mouse_strength(slot: String) -> float:
	var ab := fighter.ability(slot)
	if ab == null or ab.aim != "point":
		return 1.0
	var d := fighter.get_global_mouse_position().distance_to(fighter.position)
	return clampf(d / maxf(ab.reach, 1.0), 0.0, 1.0)


func _update_aim_preview(touch: bool) -> void:
	if ground_fx == null:
		return
	var slot := ""
	var dir := Vector2.ZERO
	var strength := 1.0
	if touch and controls.aim_slot != "" and controls.aim_vector != Vector2.ZERO:
		slot = controls.aim_slot
		dir = controls.aim_vector.normalized()
		strength = controls.aim_strength
	if slot == "" or not fighter.is_alive():
		ground_fx.aim_active = false
		return
	var ab := fighter.ability(slot)
	if ab == null:
		ground_fx.aim_active = false
		return
	ground_fx.aim_active = true
	ground_fx.aim_origin = fighter.position
	ground_fx.aim_dir = dir
	ground_fx.aim_reach = ab.reach
	ground_fx.aim_type = ab.aim
	ground_fx.aim_point = fighter.position + dir * ab.reach * clampf(strength, 0.12, 1.0)
	ground_fx.aim_radius = _ability_radius(ab)
	ground_fx.aim_width = _ability_width(ab)
	ground_fx.aim_color = Color(1, 1, 1) if fighter.is_ready(slot) else Color(1, 0.4, 0.4)


static func _ability_radius(ab: AbilityDef) -> float:
	for a in ab.actions:
		if a.has("radius") and a.get("do", "") in ["aoe", "zone", "melee"]:
			return float(a["radius"])
		if a.get("do", "") == "leap" and a.has("land"):
			return float(a["land"].get("radius", 20.0))
		if a.get("do", "") == "burrow" and a.has("emerge"):
			return float(a["emerge"].get("radius", 20.0))
	return 16.0


static func _ability_width(ab: AbilityDef) -> float:
	for a in ab.actions:
		if a.get("do", "") == "beam":
			return float(a.get("width", 6.0))
		if a.get("do", "") == "projectile":
			return float(a.get("radius", 5.0))
	return 6.0
