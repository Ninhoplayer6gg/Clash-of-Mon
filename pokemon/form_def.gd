class_name FormDef
extends RefCounted
## A playable form of a species. Swapping FormDef on a Fighter changes sprite,
## animations, stats, types, abilities, passive and effects in one go.

const SLOTS := ["basic", "skill1", "skill2", "skill3", "ult"]

var id := ""
var name := ""
var species: PokemonDef
var sprite_folder := ""
var portrait := ""
## "approved" assets are used; "pending" assets fall back to the base form's
## sprite until their licence is verified (see CREDITS.md).
var asset_status := "approved"
var types: Array = []
var stats := {}
var anim_map := {}
var abilities := {}  # slot -> AbilityDef
var passive := {}
var effects := {}
var dash := {}
## Transformation metadata (empty for base forms).
var trigger := ""          # "mega", "primal", ... or "" for base
var transform_duration := -1.0  # seconds, <0 = until fainted / mode rules
var available := true
var raw := {}


static func from_dict(form_id: String, d: Dictionary, p_species: PokemonDef) -> FormDef:
	var f := FormDef.new()
	f.raw = d
	f.id = form_id
	f.species = p_species
	f.name = d.get("name", p_species.name)
	f.sprite_folder = d.get("sprite", "")
	f.portrait = d.get("portrait", "")
	f.asset_status = d.get("asset_status", "approved")
	f.types = d.get("types", ["normal"])
	f.stats = d.get("stats", {})
	f.anim_map = d.get("anim_map", {})
	f.passive = d.get("passive", {})
	f.effects = d.get("effects", {})
	f.dash = d.get("dash", {})
	f.trigger = d.get("trigger", "")
	f.transform_duration = float(d.get("transform_duration", -1.0))
	f.available = bool(d.get("available", true))
	var abil: Dictionary = d.get("abilities", {})
	for slot in abil.keys():
		f.abilities[slot] = AbilityDef.from_dict(abil[slot], slot)
	return f


func stat(key: String, default_value: float = 0.0) -> float:
	return float(stats.get(key, default_value))


func ability(slot: String) -> AbilityDef:
	return abilities.get(slot)


func uses_pending_assets() -> bool:
	return asset_status != "approved"
