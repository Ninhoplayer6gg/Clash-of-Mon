extends PassiveBase
## Charizard - Blaze. Fire moves hit harder at low HP.


func is_active() -> bool:
	return fighter.hp_ratio() < float(param("threshold", 0.4))


func modify_outgoing(info: DamageInfo) -> void:
	if info.move_type == "fire" and is_active():
		info.mult *= 1.0 + float(param("bonus", 0.25))


func aura_color() -> Color:
	return Color(1.0, 0.45, 0.1, 0.9) if is_active() else Color(0, 0, 0, 0)


func hud_text() -> String:
	return "ATIVO" if is_active() else ""
