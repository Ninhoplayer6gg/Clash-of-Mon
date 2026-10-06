extends PassiveBase
## Lucario - Aura. Damage scales with missing HP (up to max_bonus).
## Mega form adds a STAB bonus (Adaptability).


func bonus() -> float:
	return float(param("max_bonus", 0.35)) * (1.0 - fighter.hp_ratio())


func modify_outgoing(info: DamageInfo) -> void:
	info.mult *= 1.0 + bonus()
	var stab_bonus := float(param("stab_bonus", 0.0))
	if stab_bonus > 0.0 and fighter.types.has(info.move_type):
		info.mult *= 1.0 + stab_bonus


func aura_color() -> Color:
	var b := bonus() / maxf(float(param("max_bonus", 0.35)), 0.01)
	if b < 0.25 and float(param("stab_bonus", 0.0)) <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(0.3, 0.7, 1.0, clampf(0.4 + b * 0.6, 0.0, 1.0))


func hud_text() -> String:
	return "+%d%%" % int(round(bonus() * 100.0))
