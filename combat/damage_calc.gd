class_name DamageCalc
extends RefCounted
## Final damage formula.
##
##   damage = power * (atk / def) ^ exponent * STAB * type * modifiers
##
## atk/def use Attack/Defense for physical moves and Sp. Atk/Sp. Def for
## special moves. The exponent (< 1) keeps stat gaps from snowballing.


static func compute(info: DamageInfo) -> void:
	var a := info.attacker
	var t := info.target
	var chart: TypeChart = GameData.type_chart
	var exponent: float = GameData.cfg("damage", "stat_exponent", 0.6)
	var atk := 100.0
	var def := 100.0
	if a != null:
		atk = a.get_stat("sp_attack" if info.category == "special" else "attack")
	if t != null:
		def = t.get_stat("sp_defense" if info.category == "special" else "defense")
	var ratio := pow(maxf(atk, 1.0) / maxf(def, 1.0), exponent)
	var stab := 1.0
	if a != null:
		stab = chart.stab_for(info.move_type, a.types)
	info.type_mult = chart.effectiveness(info.move_type, t.types) if t != null else 1.0
	var mods := info.mult
	if a != null:
		mods *= a.status.outgoing_mult(info)
	if t != null:
		mods *= t.status.incoming_mult(info)
	info.amount = maxi(1, int(round(info.power * ratio * stab * info.type_mult * mods)))
