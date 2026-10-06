class_name DamageInfo
extends RefCounted
## Describes one hit. CombatWorld reuses a single instance per hit to avoid
## allocations: passives must not keep references to it.

var attacker: Fighter
var target: Fighter
var ability: AbilityDef
var action: Dictionary
var move_type := "normal"
var category := "physical"
var power := 0.0
var contact := false
var source_pos := Vector2.ZERO
var direction := Vector2.RIGHT
## Multiplier chain filled by passives/status before the final computation.
var mult := 1.0
var amount := 0
var type_mult := 1.0
var knockback := 0.0
var hitstun := 0.0
var cancelled := false
var is_dot := false
var tags: Array = []


func reset() -> void:
	attacker = null
	target = null
	ability = null
	action = {}
	move_type = "normal"
	category = "physical"
	power = 0.0
	contact = false
	source_pos = Vector2.ZERO
	direction = Vector2.RIGHT
	mult = 1.0
	amount = 0
	type_mult = 1.0
	knockback = 0.0
	hitstun = 0.0
	cancelled = false
	is_dot = false
	tags = []


func effectiveness_label() -> String:
	if type_mult >= 1.05:
		return "super"
	if type_mult <= 0.95:
		return "resist"
	return ""
