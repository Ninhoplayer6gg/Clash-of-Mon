extends PassiveBase
## Gengar - Cursed Body. Skills that hit Gengar may get their cooldown
## extended (internal cooldown prevents chaining).

var _cd := 0.0


func update(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func on_hit_taken(info: DamageInfo) -> void:
	if _cd > 0.0 or info.ability == null or info.attacker == null:
		return
	var slot := info.ability.slot
	if not slot in ["skill1", "skill2", "skill3"]:
		return
	if randf() > float(param("chance", 0.4)):
		return
	_cd = float(param("internal_cd", 5.0))
	var a := info.attacker
	a.cooldowns[slot] = a.cooldowns.get(slot, 0.0) + float(param("penalty", 2.5))
	a.cooldown_max[slot] = maxf(a.cooldown_max.get(slot, 1.0), a.cooldowns[slot])
	fighter.world.vfx.burst(a.position, Color(0.55, 0.3, 0.85), 12, 70.0, 0.5, 3.0)
	fighter.world.overlay.add_text(a.position + Vector2(0, -a.body_height - 12.0), "Maldição!", Color(0.8, 0.6, 1.0), 0.9)


func aura_color() -> Color:
	return Color(0.5, 0.25, 0.8, 0.7) if _cd <= 0.0 else Color(0, 0, 0, 0)


func hud_text() -> String:
	return "pronto" if _cd <= 0.0 else "%ds" % int(ceil(_cd))
