class_name TypeChart
extends RefCounted
## Moderate PvP type effectiveness. Values come from data/types.json.

var advantage := 1.15
var resist := 0.87
var immune := 0.75
var stab := 1.1
var min_total := 0.7
var max_total := 1.3
var _table := {}  # "atk>def" -> float


func _init(data: Dictionary) -> void:
	var m: Dictionary = data.get("multipliers", {})
	advantage = m.get("advantage", advantage)
	resist = m.get("resist", resist)
	immune = m.get("immune", immune)
	stab = m.get("stab", stab)
	min_total = m.get("min_total", min_total)
	max_total = m.get("max_total", max_total)
	var chart: Dictionary = data.get("chart", {})
	for atk in chart.keys():
		var row: Dictionary = chart[atk]
		for d in row.get("advantage", []):
			_table["%s>%s" % [atk, d]] = advantage
		for d in row.get("resist", []):
			_table["%s>%s" % [atk, d]] = resist
		for d in row.get("immune", []):
			_table["%s>%s" % [atk, d]] = immune


func single(attack_type: String, defend_type: String) -> float:
	return _table.get("%s>%s" % [attack_type, defend_type], 1.0)


func effectiveness(attack_type: String, defend_types: Array) -> float:
	var m := 1.0
	for t in defend_types:
		m *= single(attack_type, t)
	return clampf(m, min_total, max_total)


func stab_for(attack_type: String, user_types: Array) -> float:
	return stab if user_types.has(attack_type) else 1.0
