extends PassiveBase
## Pikachu - Static.
## Contact hits on Pikachu may paralyse the attacker (with an internal
## cooldown), and every N Thunder Shock hits charge the next one so it
## always paralyses.

var _cd := 0.0
var _charge := 0


func update(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func on_hit_taken(info: DamageInfo) -> void:
	if not info.contact or info.attacker == null or _cd > 0.0:
		return
	if randf() <= float(param("contact_chance", 0.3)):
		if info.attacker.status.apply("paralysis", fighter):
			_cd = float(param("internal_cd", 3.0))
			fighter.world.vfx.burst(info.attacker.position, Color("#ffe14a"), 8, 60.0, 0.3, 2.0)


func modify_outgoing(info: DamageInfo) -> void:
	if info.ability and info.ability.slot == "basic" and _charge >= int(param("charge_hits", 4)):
		info.tags = ["charged"]
		info.mult *= 1.25


func on_hit_dealt(info: DamageInfo) -> void:
	if info.ability == null or info.ability.slot != "basic":
		return
	if info.tags.has("charged"):
		_charge = 0
		info.target.status.apply("paralysis", fighter)
	else:
		_charge += 1


func aura_color() -> Color:
	if _charge >= int(param("charge_hits", 4)):
		return Color(1.0, 0.9, 0.3, 0.9)
	return Color(0, 0, 0, 0)


func hud_text() -> String:
	return "%d/%d" % [mini(_charge, int(param("charge_hits", 4))), int(param("charge_hits", 4))]
