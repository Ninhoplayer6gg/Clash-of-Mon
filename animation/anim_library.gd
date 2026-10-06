class_name AnimLibrary
extends RefCounted
## Abstraction between gameplay animation names ("idle", "shoot", ...) and the
## PMD animation names actually available for a given Pokémon form.
##
## Every logical name has an ordered fallback list. A Pokémon can override or
## extend the mapping in its data file ("anim_map"), so species with unique
## sheets (Blastoise "Withdraw", Gengar "Lick"...) plug in without code.

const DEFAULT_MAP := {
	"idle": ["Idle", "Walk"],
	"walk": ["Walk", "Idle"],
	"attack": ["Attack", "Strike", "Swing"],
	"strike": ["Strike", "Attack"],
	"shoot": ["Shoot", "SpAttack", "Charge", "Attack"],
	"special": ["SpAttack", "Shoot", "Charge", "Attack"],
	"swing": ["Swing", "Attack"],
	"double": ["Double", "Attack"],
	"quick": ["QuickStrike", "Attack"],
	"charge": ["Charge", "Shoot", "Idle"],
	"hop": ["Hop", "Walk"],
	"spin": ["Rotate", "Swing", "Attack"],
	"rearup": ["RearUp", "Charge", "Idle"],
	"pose": ["Pose", "Charge", "Idle"],
	"hurt": ["Hurt", "Idle"],
	"faint": ["Faint", "Hurt"],
	"sleep": ["Sleep", "EventSleep", "Laying", "Idle"],
	"dash": ["Walk"],
}

## Animations that loop by default.
const LOOPING := {"idle": true, "walk": true, "sleep": true, "dash": true}

var sprite_set: PMDSpriteSet
var _resolved := {}  # logical -> PMDAnim


func _init(p_set: PMDSpriteSet, overrides: Dictionary = {}) -> void:
	sprite_set = p_set
	var map := DEFAULT_MAP.duplicate(true)
	for k in overrides.keys():
		var v = overrides[k]
		var list: Array = v if v is Array else [v]
		# Overrides go first, defaults stay as fallbacks.
		var merged: Array = list.duplicate()
		for d in map.get(k, []):
			if not merged.has(d):
				merged.append(d)
		map[k] = merged
	for logical in map.keys():
		for pmd_name in map[logical]:
			if sprite_set.has_anim(pmd_name):
				_resolved[logical] = sprite_set.get_anim(pmd_name)
				break
	# Absolute last resort so nothing ever renders blank.
	var any: PMDAnim = _resolved.get("idle")
	if any == null and not sprite_set.anims.is_empty():
		any = sprite_set.anims.values()[0]
		_resolved["idle"] = any


func get_anim(logical: String) -> PMDAnim:
	var a: PMDAnim = _resolved.get(logical)
	if a == null:
		# Allow raw PMD names too ("Withdraw", "Lick"...).
		a = sprite_set.get_anim(logical)
	if a == null:
		a = _resolved.get("idle")
	return a


func has_logical(logical: String) -> bool:
	return _resolved.has(logical)


func is_looping(logical: String) -> bool:
	return LOOPING.has(logical)


## Seconds until the HitFrame of a logical animation (speed 1).
func hit_time(logical: String) -> float:
	var a := get_anim(logical)
	return a.hit_time() if a else 0.15
