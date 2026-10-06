extends PassiveBase
## Blastoise - Shell Armor. Frontal hits deal less damage; knockback reduced.


func modify_incoming(info: DamageInfo) -> void:
	info.knockback *= float(param("knockback_mult", 0.6))
	if info.is_dot:
		return
	var from := info.source_pos - fighter.position
	if from.length_squared() < 1.0:
		return
	var limit := deg_to_rad(float(param("front_angle", 75.0)))
	if absf(fighter.facing.angle_to(from)) <= limit:
		info.mult *= 1.0 - float(param("front_reduction", 0.2))
		fighter.world.vfx.ring(fighter.position + from.normalized() * fighter.radius, Color(0.7, 0.9, 1.0), 6.0, 0.15)
