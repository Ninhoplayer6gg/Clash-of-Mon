class_name AbilityDef
extends RefCounted
## Data-driven ability. The timeline is a list of actions, each fired at a
## time ("at") which can be a number of seconds or "hit" (= HitFrame of the
## cast animation, read from AnimData.xml through the PMD importer).
##
## Supported action types live in abilities/action_executor.gd.

var id := ""
var slot := ""
var name := ""
var description := ""
var icon := ""
var move_type := "normal"
var category := "physical"  # physical | special | status
var cooldown := 1.0
var energy := 0.0
var aim := "direction"  # direction | point | self
var reach := 150.0
var anim := "attack"
var anim_speed := 1.0
var cast_time := 0.35
var move_mult := 0.0
var super_armor := false
var lock_aim := true
var actions: Array = []
var combo: Array = []  # optional stages for chained basic attacks
var combo_window := 0.0
var ai := {}
var tags: Array = []
var raw := {}


static func from_dict(d: Dictionary, p_slot: String) -> AbilityDef:
	var a := AbilityDef.new()
	a.raw = d
	a.slot = p_slot
	a.id = d.get("id", p_slot)
	a.name = d.get("name", a.id.capitalize())
	a.description = d.get("description", "")
	a.icon = d.get("icon", a.name.substr(0, 2).to_upper())
	a.move_type = d.get("type", "normal")
	a.category = d.get("category", "physical")
	a.cooldown = float(d.get("cooldown", 1.0))
	a.energy = float(d.get("energy", 0.0))
	a.aim = d.get("aim", "direction")
	a.reach = float(d.get("range", 150.0))
	a.anim = d.get("anim", "attack")
	a.anim_speed = float(d.get("anim_speed", 1.0))
	a.cast_time = float(d.get("cast_time", 0.35))
	a.move_mult = float(d.get("move_mult", 0.0))
	a.super_armor = bool(d.get("super_armor", false))
	a.lock_aim = bool(d.get("lock_aim", true))
	a.actions = d.get("actions", [])
	a.combo = d.get("combo", [])
	a.combo_window = float(d.get("combo_window", 0.0))
	a.ai = d.get("ai", {})
	a.tags = d.get("tags", [])
	return a


## Returns the stage dictionary (anim, cast_time, actions...) for a combo
## index, or the ability itself when it has no combo.
func stage(index: int) -> Dictionary:
	if combo.is_empty():
		return raw
	return combo[index % combo.size()]


func stage_count() -> int:
	return maxi(1, combo.size())
