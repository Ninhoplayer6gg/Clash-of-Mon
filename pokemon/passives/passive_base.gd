class_name PassiveBase
extends RefCounted
## Base class for Pokémon passives. Passives are created from data
## ("passive": {"id": "static", "params": {...}}) and receive combat hooks.
## Hooks receive the shared DamageInfo: read/modify it, never store it.

var fighter: Fighter
var params := {}
var id := ""
var display_name := ""
var description := ""


static func create(data: Dictionary, p_fighter: Fighter) -> PassiveBase:
	var pid: String = data.get("id", "")
	var p: PassiveBase
	var path := "res://pokemon/passives/%s.gd" % pid
	if pid != "" and ResourceLoader.exists(path):
		p = load(path).new()
	else:
		p = PassiveBase.new()
	p.id = pid
	p.fighter = p_fighter
	p.params = data.get("params", {})
	p.display_name = data.get("name", pid.capitalize())
	p.description = data.get("description", "")
	p.on_attach()
	return p


func param(key: String, default_value: Variant) -> Variant:
	return params.get(key, default_value)


func on_attach() -> void:
	pass


func on_detach() -> void:
	pass


func update(_delta: float) -> void:
	pass


## Adjust info.mult before damage is computed (attacker side).
func modify_outgoing(_info: DamageInfo) -> void:
	pass


## Adjust info.mult / knockback before damage is computed (target side).
func modify_incoming(_info: DamageInfo) -> void:
	pass


func on_hit_dealt(_info: DamageInfo) -> void:
	pass


func on_hit_taken(_info: DamageInfo) -> void:
	pass


func on_cast(_ability: AbilityDef) -> void:
	pass


func on_dash() -> void:
	pass


func allow_status(_status_id: String, _source: Fighter) -> bool:
	return true


## Optional visual: aura colour drawn under the fighter (alpha 0 = none).
func aura_color() -> Color:
	return Color(0, 0, 0, 0)


## Short state text for HUD/debug ("3/4", "+25%"...).
func hud_text() -> String:
	return ""
