extends Node
## Autoload "GameData": loads every data file (JSON) once and exposes typed
## accessors. Pokémon, abilities, statuses, types and arenas are all data.

const DATA_DIR := "res://data"

var config := {}
var types := {}
var statuses := {}
var roster: Array[String] = []
var arena_ids: Array[String] = []
var pokemon := {}  # id -> PokemonDef
var arenas := {}   # id -> Dictionary
var type_chart: TypeChart


func _ready() -> void:
	reload()


func reload() -> void:
	config = load_json(DATA_DIR + "/game_config.json")
	types = load_json(DATA_DIR + "/types.json")
	statuses = load_json(DATA_DIR + "/status.json")
	statuses.erase("_comment")
	type_chart = TypeChart.new(types)
	var index := load_json(DATA_DIR + "/roster.json")
	roster.clear()
	pokemon.clear()
	for id in index.get("pokemon", []):
		var raw := load_json("%s/pokemon/%s.json" % [DATA_DIR, id])
		if raw.is_empty():
			push_error("GameData: missing data for %s" % id)
			continue
		pokemon[id] = PokemonDef.from_dict(raw)
		roster.append(id)
	arena_ids.clear()
	arenas.clear()
	for id in index.get("arenas", []):
		var a := load_json("%s/arenas/%s.json" % [DATA_DIR, id])
		if not a.is_empty():
			arenas[id] = a
			arena_ids.append(id)


func get_pokemon(id: String) -> PokemonDef:
	return pokemon.get(id)


func get_arena(id: String) -> Dictionary:
	return arenas.get(id, {})


func cfg(section: String, key: String, default_value: Variant = 0.0) -> Variant:
	return config.get(section, {}).get(key, default_value)


func status_def(id: String) -> Dictionary:
	return statuses.get(id, {})


func type_color(t: String) -> Color:
	return Color.from_string(types.get("colors", {}).get(t, "#cccccc"), Color.GRAY)


func type_name(t: String) -> String:
	return types.get("names", {}).get(t, t.capitalize())


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var d = json.data
	return d if d is Dictionary else {}
