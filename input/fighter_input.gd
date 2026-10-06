class_name FighterInput
extends RefCounted
## Commands for one fighter for the current physics tick. Written by a
## controller (player, bot, network in the future) and consumed by Fighter.

var move := Vector2.ZERO
## Live aim (right stick / drag / mouse). Zero = no explicit aim.
var aim := Vector2.ZERO
## One-shot triggers, cleared by the fighter after reading them.
var cast_slot := ""
var cast_aim := Vector2.ZERO     # zero = auto aim
var cast_strength := 1.0         # 0..1 distance fraction for point-aimed skills
var dash := false
var mega := false


func request_cast(slot: String, aim_vec: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	cast_slot = slot
	cast_aim = aim_vec
	cast_strength = strength


func clear_triggers() -> void:
	cast_slot = ""
	cast_aim = Vector2.ZERO
	cast_strength = 1.0
	dash = false
	mega = false
