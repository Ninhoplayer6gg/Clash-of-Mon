extends PassiveBase
## Garchomp - Rough Skin. Contact attackers take part of the damage back.


func on_hit_taken(info: DamageInfo) -> void:
	if not info.contact or info.attacker == null or info.attacker == fighter:
		return
	var back := int(round(info.amount * float(param("reflect", 0.2))))
	if back > 0:
		info.attacker.take_dot(back, fighter, "")


func aura_color() -> Color:
	if fighter.status.has_mod("outrage"):
		return Color(1.0, 0.3, 0.3, 0.9)
	return Color(0, 0, 0, 0)
