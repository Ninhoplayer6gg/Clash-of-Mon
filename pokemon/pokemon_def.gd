class_name PokemonDef
extends RefCounted
## Species definition loaded from data/pokemon/<id>.json.
##
## A species owns one or more forms (base, mega, regional, alternate...).
## Every non-base form inherits from another form and only overrides what
## changes: sprite folder, animation map, stats, types, abilities, passive,
## visual effects. See FormDef.

var id := ""
var name := ""
var dex := 0
var role := ""
var description := ""
var difficulty := 1
var ai := {}
var default_form := "base"
var forms := {}  # form id -> FormDef
var raw := {}


static func from_dict(d: Dictionary) -> PokemonDef:
	var p := PokemonDef.new()
	p.raw = d
	p.id = d.get("id", "")
	p.name = d.get("name", p.id.capitalize())
	p.dex = int(d.get("dex", 0))
	p.role = d.get("role", "")
	p.description = d.get("description", "")
	p.difficulty = int(d.get("difficulty", 1))
	p.ai = d.get("ai", {})
	p.default_form = d.get("default_form", "base")
	var raw_forms: Dictionary = d.get("forms", {})
	# Resolve inheritance (form -> parent form) by merging dictionaries.
	var resolved := {}
	for form_id in raw_forms.keys():
		resolved[form_id] = _resolve_form(raw_forms, form_id, 0)
	for form_id in resolved.keys():
		p.forms[form_id] = FormDef.from_dict(form_id, resolved[form_id], p)
	return p


static func _resolve_form(raw_forms: Dictionary, form_id: String, depth: int) -> Dictionary:
	var f: Dictionary = raw_forms.get(form_id, {})
	var parent_id: String = f.get("inherits", "")
	if parent_id == "" or depth > 6 or not raw_forms.has(parent_id):
		return f.duplicate(true)
	var base := _resolve_form(raw_forms, parent_id, depth + 1)
	return merge_form(base, f)


## Merge rules: "abilities" merge per slot, "stats" per key, "stat_mult"
## multiplies inherited stats, everything else is replaced.
static func merge_form(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in over.keys():
		if key == "inherits":
			continue
		var v = over[key]
		match key:
			"abilities", "stats", "anim_map", "effects":
				var merged: Dictionary = out.get(key, {}).duplicate(true)
				for k in v.keys():
					merged[k] = v[k]
				out[key] = merged
			"stat_mult":
				var stats: Dictionary = out.get("stats", {}).duplicate(true)
				for k in v.keys():
					if stats.has(k):
						stats[k] = float(stats[k]) * float(v[k])
				out["stats"] = stats
			_:
				out[key] = v
	return out


func get_form(form_id: String = "") -> FormDef:
	if form_id == "":
		form_id = default_form
	return forms.get(form_id, forms.get(default_form))


func base_form() -> FormDef:
	return get_form(default_form)


## Form reached through a transformation trigger ("mega", ...), if any.
func form_for_trigger(trigger: String) -> FormDef:
	for f in forms.values():
		if f.trigger == trigger:
			return f
	return null
