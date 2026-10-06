class_name BotController
extends Node
## Simple but readable arena bot.
##  - chases or keeps its preferred distance (per-Pokémon "ai" profile)
##  - strafes, steers around obstacles and unsticks itself
##  - uses abilities by hint ("poke", "engage", "escape", "finisher")
##  - dodges incoming projectiles and telegraphed areas with dash
##  - respects cooldowns/energy through the same Fighter API as the player
##  - retreats/kites at low HP
## Behaviours for training: "idle" (stands still), "passive" (moves only),
## "active" (full AI).

signal switch_requested(direction: int)

const REACTION := [0.38, 0.22, 0.12]
const AIM_ERROR_DEG := [16.0, 8.0, 3.0]
const DODGE_CHANCE := [0.15, 0.45, 0.75]
const CAST_CHANCE := [0.45, 0.75, 0.95]

var fighter: Fighter
var world: CombatWorld
var behavior := "active"
var difficulty := 1
var profile := {}
var can_switch := false

var _rng := RandomNumberGenerator.new()
var _decide_timer := 0.0
var _desired := Vector2.ZERO
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _dodge_cd := 0.0
var _unstick_timer := 0.0
var _unstick_dir := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _stuck_acc := 0.0
var _switch_cd := 2.0
## Decision counters (debug overlay / balance tests).
var stats := {}
# Terrain (v0.2): vision vs tall grass, ambush and lava avoidance.
var _last_seen_pos := Vector2.INF
var _last_seen_frame := 0
var _search_point := Vector2.INF
var _ambush_until := 0
var _ambush_block_until := 0


func _ready() -> void:
	process_physics_priority = -10
	_rng.randomize()


func set_fighter(f: Fighter) -> void:
	fighter = f
	profile = f.species.ai if f else {}
	_last_pos = f.position if f else Vector2.ZERO


func _physics_process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not fighter.is_inside_tree() or not fighter.is_alive():
		return
	var inp := fighter.input
	if behavior == "idle":
		inp.move = Vector2.ZERO
		return
	var target := world.enemy_of(fighter)
	if target == null or not target.is_inside_tree():
		inp.move = Vector2.ZERO
		return
	_dodge_cd -= delta
	_strafe_timer -= delta
	_switch_cd -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(0.8, 2.0)
		_strafe_sign = -_strafe_sign if _rng.randf() < 0.6 else _strafe_sign
	_decide_timer -= delta
	if _decide_timer <= 0.0:
		_decide_timer = REACTION[difficulty] * _rng.randf_range(0.7, 1.3)
		_decide(target)
	var move := _desired
	if behavior == "active":
		move = _dodge(move)
	move = _avoid_hazards(move)  # terrain (v0.2): get out of lava
	move = _unstick(move, delta)
	inp.move = _steer(move)


# --------------------------------------------------------------- decisions

func _decide(target: Fighter) -> void:
	stats["decisions"] = stats.get("decisions", 0) + 1
	# Terrain (v0.2): a target concealed in tall grass is hunted at its last
	# known position; a concealed brawler may wait in ambush.
	if _terrain_decide(target):
		return
	var to := target.position - fighter.position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var pref := float(profile.get("range", 120.0))
	var style := String(profile.get("style", "kite"))
	var low_hp := fighter.hp_ratio() < float(profile.get("retreat_hp", 0.25))
	var los := world.arena.line_of_sight(fighter.position, target.position)
	var strafe := dir.orthogonal() * _strafe_sign
	if target.hidden_mode != "":
		# Lost track (vanished / underground): back off and wait.
		_desired = (-dir * 0.6 + strafe * 0.8).normalized()
		return
	if low_hp and dist < 220.0 and target.hp_ratio() > fighter.hp_ratio():
		_desired = (-dir + strafe * 0.7).normalized()
		if behavior == "active":
			_try_use(target, dist, los, ["escape"], -dir)
		if can_switch and _switch_cd <= 0.0 and fighter.hp_ratio() < 0.22:
			_switch_cd = 6.0
			switch_requested.emit(1)
		return
	if not los:
		_desired = dir
	elif style == "brawler":
		# Melee: walk straight in, circle a little once in range.
		if dist > pref + 6.0:
			_desired = (dir + strafe * 0.12).normalized()
		else:
			_desired = (strafe * 0.6 + dir * 0.4).normalized()
	elif dist > pref + 25.0:
		_desired = (dir + strafe * 0.25).normalized()
	elif dist < pref - 25.0 and style == "kite":
		_desired = (-dir + strafe * 0.5).normalized()
	else:
		_desired = (strafe + dir * (0.35 if style == "brawler" else 0.0)).normalized()
	if behavior != "active":
		return
	if fighter.can_mega() and dist < 260.0:
		fighter.input.mega = true
		return
	var punish := target.status.is_asleep() or target.status.is_frozen()
	if not punish and _rng.randf() > CAST_CHANCE[difficulty]:
		return
	var hints := ["finisher", "engage", "poke", "", "defense"]
	if punish:
		# Sleep/freeze combo: go for the biggest hit available.
		hints = ["finisher", "poke", "engage", ""]
	if style == "brawler" and dist > pref + 70.0:
		hints.push_front("escape")  # mobility used to close the gap
	_try_use(target, dist, los, hints, dir)


## Tries ult, skills then basic in priority, honouring each ability's AI hint.
func _try_use(target: Fighter, dist: float, los: bool, hints: Array, fallback_dir: Vector2) -> void:
	for slot in ["ult", "skill1", "skill2", "skill3", "basic"]:
		var ab := fighter.ability(slot)
		if ab == null or not fighter.is_ready(slot):
			continue
		var use := String(ab.ai.get("use", ""))
		if not hints.has(use):
			continue
		var max_r := float(ab.ai.get("max", ab.reach))
		var min_r := float(ab.ai.get("min", 0.0))
		var aim := _aim_at(target, ab)
		var strength := clampf(dist / maxf(ab.reach, 1.0), 0.1, 1.0)
		match use:
			"escape":
				if fighter.hp_ratio() < float(profile.get("retreat_hp", 0.25)):
					# Run away from the target.
					aim = (fallback_dir + fallback_dir.orthogonal() * _strafe_sign * 0.5).normalized()
					strength = 1.0
				elif dist < float(profile.get("range", 100.0)) + 50.0:
					continue  # already close: keep mobility for later
				fighter.input.request_cast(slot, aim, strength)
				return
			"finisher":
				if dist > max_r or not los:
					continue
				if target.hp_ratio() > 0.65 and _rng.randf() < 0.5:
					continue
			"defense":
				if dist > max_r:
					continue
			_:
				if dist > max_r or dist < min_r:
					continue
				if not los and ab.aim != "self":
					continue
		fighter.input.request_cast(slot, aim, strength)
		stats[slot] = stats.get(slot, 0) + 1
		return


func _aim_at(target: Fighter, ab: AbilityDef) -> Vector2:
	var speed := 2000.0
	for a in ab.actions:
		if a.get("do", "") == "projectile":
			speed = float(a.get("speed", 300.0))
	var t := fighter.position.distance_to(target.position) / speed
	var predicted := target.position + target.velocity * t * 0.7
	var d := (predicted - fighter.position).normalized()
	var err := deg_to_rad(AIM_ERROR_DEG[difficulty])
	return d.rotated(_rng.randf_range(-err, err))


# ------------------------------------------------------------------ dodging

func _dodge(move: Vector2) -> Vector2:
	var me := fighter.position
	for z in world.zones:
		if z.team == fighter.team or not z.telegraph or z.elapsed >= z.delay:
			continue
		if z.shape == HitZone.Shape.CIRCLE:
			var d := me - z.anchor()
			if d.length() < z.radius + fighter.radius + 6.0:
				var away := d.normalized() if d.length() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)
				_maybe_dash(away)
				return away
		elif z.shape == HitZone.Shape.LINE:
			if Geo.circle_vs_capsule(me, fighter.radius + 6.0, z.anchor(), z.line_end(), z.width):
				var side := z.dir.orthogonal()
				if side.dot(me - z.anchor()) < 0.0:
					side = -side
				_maybe_dash(side)
				return side
	if _dodge_cd > 0.0:
		return move
	for p in world.projectiles:
		if p.team == fighter.team:
			continue
		var rel := me - p.pos
		var along := rel.dot(p.dir)
		if along <= 0.0 or along > 150.0:
			continue
		var perp := absf(rel.cross(p.dir))
		if perp < fighter.radius + p.radius + 6.0:
			_dodge_cd = 0.5
			var side := p.dir.orthogonal()
			if side.dot(rel) < 0.0:
				side = -side
			if _rng.randf() < DODGE_CHANCE[difficulty]:
				_maybe_dash(side, true)
			return side
	return move


func _maybe_dash(dir: Vector2, force: bool = false) -> void:
	if fighter.dash_cd > 0.0 or fighter.energy < 35.0:
		return
	if force or _rng.randf() < DODGE_CHANCE[difficulty]:
		fighter.input.dash = true
		fighter.input.move = dir


# ---------------------------------------------------------------- steering

func _steer(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return dir
	var arena := world.arena
	var probe := fighter.radius + 14.0
	if not _blocked(fighter.position + dir * probe):
		return dir
	for k in [0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var d := dir.rotated(k * _strafe_sign)
		if not _blocked(fighter.position + d * probe):
			return d
	return dir.orthogonal() * _strafe_sign


func _unstick(move: Vector2, delta: float) -> Vector2:
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		return _unstick_dir
	if move.length_squared() > 0.1 and fighter.state == Fighter.State.IDLE:
		if fighter.position.distance_to(_last_pos) < 0.5:
			_stuck_acc += delta
		else:
			_stuck_acc = 0.0
		if _stuck_acc > 0.35:
			_stuck_acc = 0.0
			_unstick_timer = 0.5
			_unstick_dir = move.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
	_last_pos = fighter.position
	return move


# ------------------------------------------------------- terrain (v0.2)

## Vision + ambush. Returns true when the decision was taken here.
func _terrain_decide(target: Fighter) -> bool:
	if not world.can_see(fighter, target):
		_hunt(target)
		return true
	_last_seen_pos = target.position
	_last_seen_frame = Engine.get_physics_frames()
	_search_point = Vector2.INF
	return _ambush(target)


## Goes to where the target vanished, sweeps that grass patch (anyone
## within ArenaTerrain.REVEAL_RANGE is revealed) and pokes into it.
func _hunt(target: Fighter) -> void:
	stats["hunt"] = stats.get("hunt", 0) + 1
	var terrain := world.arena.terrain
	if _last_seen_pos == Vector2.INF:
		_last_seen_pos = target.position  # never seen yet: it entered here
		_last_seen_frame = Engine.get_physics_frames()
	var me := fighter.position
	var unseen := float(Engine.get_physics_frames() - _last_seen_frame) / float(Engine.physics_ticks_per_second)
	if _search_point == Vector2.INF:
		_search_point = _last_seen_pos
	elif me.distance_to(_search_point) < 20.0 and terrain:
		# Reached: try another cell of the patch (wider after a while).
		_search_point = terrain.search_point(_last_seen_pos if unseen < 6.0 else me, _rng, 120.0 if unseen < 6.0 else 400.0)
	var to := _search_point - me
	var strafe := to.normalized().orthogonal() * _strafe_sign
	_desired = (to.normalized() + strafe * 0.15).normalized() if to.length() > 4.0 else Vector2.ZERO
	if behavior != "active" or unseen > 5.0 or _rng.randf() > 0.45:
		return
	# Blind fire into the grass where the target was last seen.
	var aim_to := _last_seen_pos - me
	var dist := aim_to.length()
	for slot in ["basic", "skill1", "skill2", "skill3"]:
		var ab := fighter.ability(slot)
		if ab == null or not fighter.is_ready(slot):
			continue
		if slot != "basic" and String(ab.ai.get("use", "")) != "poke":
			continue
		if dist > float(ab.ai.get("max", ab.reach)) or ab.aim == "self":
			continue
		fighter.input.request_cast(slot, aim_to.normalized(), clampf(dist / maxf(ab.reach, 1.0), 0.1, 1.0))
		stats["blind_" + slot] = stats.get("blind_" + slot, 0) + 1
		return


## Concealed brawlers hold still for a moment while the unaware target
## walks in, then fight normally (bounded so matches never stall).
func _ambush(target: Fighter) -> bool:
	if behavior != "active" or not fighter.concealed or String(profile.get("style", "")) != "brawler":
		_ambush_until = 0
		return false
	var now := Engine.get_physics_frames()
	if now < _ambush_block_until:
		return false
	var dist := fighter.position.distance_to(target.position)
	if dist < float(profile.get("range", 40.0)) + 70.0 or dist > 300.0 or now > _ambush_until and _ambush_until != 0:
		if _ambush_until != 0:
			_ambush_until = 0
			_ambush_block_until = now + 8 * Engine.physics_ticks_per_second
		return false
	if _ambush_until == 0:
		_ambush_until = now + int(2.5 * Engine.physics_ticks_per_second)
	stats["ambush"] = stats.get("ambush", 0) + 1
	_desired = Vector2.ZERO
	return true


## Out of lava as fast as possible (dash when available).
func _avoid_hazards(move: Vector2) -> Vector2:
	var terrain := world.arena.terrain
	if terrain == null or fighter.terrain_kind != ArenaTerrain.LAVA or fighter.types.has("fire"):
		return move
	stats["lava_escape"] = stats.get("lava_escape", 0) + 1
	var out := terrain.escape_dir(fighter.position, fighter.radius)
	if behavior == "active" and fighter.state == Fighter.State.IDLE:
		_maybe_dash(out, true)
	return out


## Steering probe: obstacles, plus lava for non-Fire types (ignored while
## already standing in lava so the escape direction is not overridden).
func _blocked(p: Vector2) -> bool:
	if world.arena.circle_blocked(p, fighter.radius):
		return true
	return fighter.terrain_kind != ArenaTerrain.LAVA and world.arena.is_hazard(p, fighter)
