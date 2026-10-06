class_name Fighter
extends CharacterBody2D
## A Pokémon on the field. Owns movement, dash, knockback, hitstun, casting,
## resources (HP, energy, ultimate, mega), statuses, passive and its form.
## Everything species-specific comes from PokemonDef/FormDef data.

signal hp_changed(fighter: Fighter)
signal fainted(fighter: Fighter)
signal cast_started(fighter: Fighter, slot: String)
signal cast_failed(fighter: Fighter, slot: String, reason: String)
signal form_changed(fighter: Fighter)

enum State { IDLE, CASTING, DASHING, HITSTUN, DISABLED, FAINTED }

const SLOTS := ["basic", "skill1", "skill2", "skill3", "ult"]
const LAYER_WORLD := 1
const LAYER_FIGHTERS := 2
const BUFFER_TIME := 0.22

static var _flash_shader: Shader

var species: PokemonDef
var form: FormDef
var team := 0
var team_color := Color(0.35, 0.7, 1.0)
var is_player := false
var world: CombatWorld

# Resolved stats
var types: Array = []
var max_hp := 1000
var hp := 1000
var max_energy := 100.0
var energy := 100.0
var energy_regen := 20.0
var energy_delay := 0.0
var move_speed := 120.0
var mass := 1.0
var radius := 9.0
var body_height := 24.0

# Resources
var ult_charge := 0.0
var mega_charge := 0.0
var mega_used := false
var transform_time := -1.0

# Cooldowns
var cooldowns := {}
var cooldown_max := {}
var dash_cd := 0.0
var combo_index := 0
var combo_timer := 0.0

# State
var state := State.IDLE
var facing := Vector2.DOWN
var aim_dir := Vector2.DOWN
var move_velocity := Vector2.ZERO
var knock_velocity := Vector2.ZERO
var forced_velocity := Vector2.ZERO
var forced_time := 0.0
var forced_through := false
var hitstun := 0.0
var invuln := 0.0
var hidden_mode := ""
var hidden_time := 0.0
var hidden_total := 0.0
var dash_time := 0.0
var dash_dir := Vector2.ZERO
var afterimage_time := 0.0
var _afterimage_acc := 0.0
var cast: CastState
var _buffer_slot := ""
var _buffer_aim := Vector2.ZERO
var _buffer_strength := 1.0
var _buffer_time := 0.0
var _pending: Array = []  # [[time_left, action, cast]]
var _cast_counter := 0
var _last_damage_time := 0.0
var _faint_time := 0.0

# Components
var input := FighterInput.new()
var status: StatusManager
var passive: PassiveBase
var animator: PMDAnimator
var library: AnimLibrary
var collision: CollisionShape2D
var flash := 0.0
var _material: ShaderMaterial

# Options (training)
var infinite_hp := false
var instant_cooldown := false
var mega_enabled := false

# Stats for results/debug
var damage_dealt := 0
var damage_taken := 0


func setup(p_species: PokemonDef, p_team: int, p_world: CombatWorld, form_id: String = "") -> void:
	species = p_species
	team = p_team
	world = p_world
	status = StatusManager.new(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	collision_layer = LAYER_FIGHTERS
	collision_mask = LAYER_WORLD | LAYER_FIGHTERS
	collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	add_child(collision)
	animator = PMDAnimator.new()
	add_child(animator)
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}"""
	_material = ShaderMaterial.new()
	_material.shader = _flash_shader
	animator.material = _material
	for s in SLOTS:
		cooldowns[s] = 0.0
		cooldown_max[s] = 1.0
	apply_form(form_id if form_id != "" else species.default_form, false)
	hp = max_hp
	energy = max_energy


# --------------------------------------------------------------------- forms

## Switches to another form (Mega Evolution, regional form, ...). Sprite,
## animations, stats, types, abilities and passive are all replaced; HP keeps
## its ratio. Forms whose assets are still pending keep the current sprite.
func apply_form(form_id: String, keep_ratio: bool = true) -> void:
	var f := species.get_form(form_id)
	if f == null:
		return
	var ratio := float(hp) / float(max(max_hp, 1))
	form = f
	types = f.types
	max_hp = int(f.stat("hp", 3000))
	move_speed = f.stat("move_speed", 120.0)
	mass = f.stat("mass", 1.0)
	radius = f.stat("radius", 9.0)
	max_energy = f.stat("energy", 100.0)
	energy_regen = f.stat("energy_regen", 20.0)
	(collision.shape as CircleShape2D).radius = radius
	hp = int(round(max_hp * ratio)) if keep_ratio else max_hp
	var folder := f.sprite_folder
	if f.uses_pending_assets() or folder == "" or not FileAccess.file_exists(folder + "/AnimData.xml"):
		folder = species.base_form().sprite_folder if library == null else library.sprite_set.folder
	var sprite_set := PMDSpriteImporter.load_sprite_set(folder)
	library = AnimLibrary.new(sprite_set, f.anim_map)
	animator.setup(library)
	body_height = sprite_set.body_height()
	if passive:
		passive.on_detach()
	passive = PassiveBase.create(f.passive, self)
	for s in SLOTS:
		var ab := f.ability(s)
		cooldown_max[s] = ab.cooldown if ab else 1.0
		cooldowns[s] = minf(cooldowns.get(s, 0.0), cooldown_max[s])
	form_changed.emit(self)
	hp_changed.emit(self)


func get_stat(key: String) -> float:
	return form.stat(key, 100.0)


func ability(slot: String) -> AbilityDef:
	return form.ability(slot)


# ------------------------------------------------------------------ queries

func is_alive() -> bool:
	return state != State.FAINTED


func can_be_hit() -> bool:
	return state != State.FAINTED and invuln <= 0.0 and hidden_mode == "" and is_inside_tree()


func can_act() -> bool:
	return state == State.IDLE


func is_casting() -> bool:
	return state == State.CASTING


func hp_ratio() -> float:
	return float(hp) / float(max(max_hp, 1))


func cooldown_ratio(slot: String) -> float:
	var m: float = cooldown_max.get(slot, 1.0)
	return clampf(cooldowns.get(slot, 0.0) / maxf(m, 0.001), 0.0, 1.0)


func is_ready(slot: String) -> bool:
	var ab := ability(slot)
	if ab == null:
		return false
	if cooldowns.get(slot, 0.0) > 0.0:
		return false
	if slot == "ult" and ult_charge < 100.0:
		return false
	return energy >= ab.energy


func can_mega() -> bool:
	return mega_enabled and not mega_used and mega_charge >= 100.0 and species.form_for_trigger("mega") != null and form.trigger == ""


func state_name() -> String:
	return State.keys()[state]


# -------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if world == null:
		return
	if state == State.FAINTED:
		_faint_time += delta
		knock_velocity = knock_velocity.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
		velocity = knock_velocity
		move_and_slide()
		input.clear_triggers()
		return
	_tick_timers(delta)
	status.update(delta)
	if state == State.FAINTED:
		return
	passive.update(delta)
	_tick_pending(delta)

	if status.is_disabled():
		if state == State.CASTING:
			_end_cast(true)
		state = State.DISABLED
	elif state == State.DISABLED:
		state = State.IDLE

	match state:
		State.HITSTUN:
			hitstun -= delta
			if hitstun <= 0.0:
				state = State.IDLE
		State.DASHING:
			_update_dash(delta)
		State.CASTING:
			_update_cast(delta)

	_handle_input(delta)
	_integrate_movement(delta)
	input.clear_triggers()


func _tick_timers(delta: float) -> void:
	for s in SLOTS:
		if cooldowns[s] > 0.0:
			cooldowns[s] = 0.0 if instant_cooldown else maxf(0.0, cooldowns[s] - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	flash = maxf(0.0, flash - delta * 6.0)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_index = 0
	if energy_delay > 0.0:
		energy_delay -= delta
	else:
		energy = minf(max_energy, energy + energy_regen * delta)
	ult_charge = minf(100.0, ult_charge + float(GameData.cfg("ultimate", "passive_charge_per_second", 0.6)) * delta)
	if _buffer_time > 0.0:
		_buffer_time -= delta
		if _buffer_time <= 0.0:
			_buffer_slot = ""
	if hidden_time > 0.0:
		hidden_time -= delta
		if hidden_time <= 0.0:
			_unhide()
	if forced_time > 0.0:
		forced_time -= delta
		if forced_time <= 0.0:
			_end_forced_move()
	if transform_time > 0.0:
		transform_time -= delta
		if transform_time <= 0.0:
			revert_form()
	if infinite_hp and hp < max_hp:
		_last_damage_time += delta
		if _last_damage_time > 2.5:
			hp = max_hp
			hp_changed.emit(self)


func _tick_pending(delta: float) -> void:
	var i := _pending.size() - 1
	while i >= 0:
		var p: Array = _pending[i]
		p[0] -= delta
		if p[0] <= 0.0:
			_pending.remove_at(i)
			ActionExecutor.execute(self, p[2], p[1])
		i -= 1


func queue_action(delay: float, action: Dictionary, p_cast: CastState) -> void:
	_pending.append([delay, action, p_cast])


func _handle_input(_delta: float) -> void:
	if input.aim.length_squared() > 0.04:
		aim_dir = input.aim.normalized()
	if input.mega and can_mega():
		start_mega()
		return
	if input.dash:
		try_dash(input.move)
	if input.cast_slot != "":
		if not try_cast(input.cast_slot, input.cast_aim, input.cast_strength):
			_buffer_slot = input.cast_slot
			_buffer_aim = input.cast_aim
			_buffer_strength = input.cast_strength
			_buffer_time = BUFFER_TIME
	elif _buffer_slot != "" and can_act():
		var s := _buffer_slot
		_buffer_slot = ""
		try_cast(s, _buffer_aim, _buffer_strength, true)


func _integrate_movement(delta: float) -> void:
	var accel: float = GameData.cfg("movement", "acceleration", 1900.0)
	var decel: float = GameData.cfg("movement", "deceleration", 2400.0)
	var target := Vector2.ZERO
	var spd := move_speed * status.speed_mult()
	match state:
		State.IDLE:
			target = input.move.limit_length(1.0) * spd
			if input.move.length_squared() > 0.01:
				facing = input.move.normalized()
				if input.aim.length_squared() < 0.04:
					aim_dir = facing
		State.CASTING:
			target = input.move.limit_length(1.0) * spd * cast.move_mult
			if cast.channel_aim and input.aim.length_squared() > 0.04:
				var turn: float = GameData.cfg("movement", "cast_turn_speed", 14.0)
				cast.aim_dir = cast.aim_dir.slerp(input.aim.normalized(), clampf(turn * delta * 0.25, 0.0, 1.0)).normalized()
			facing = cast.aim_dir
			aim_dir = cast.aim_dir
		_:
			target = Vector2.ZERO
	var rate := accel if target.length_squared() > move_velocity.length_squared() else decel
	move_velocity = move_velocity.move_toward(target, rate * delta)
	var friction: float = GameData.cfg("movement", "knockback_friction", 7.5)
	knock_velocity = knock_velocity * exp(-friction * delta)
	if knock_velocity.length_squared() < 4.0:
		knock_velocity = Vector2.ZERO
	if forced_time > 0.0:
		velocity = forced_velocity + knock_velocity * 0.25
	elif state == State.DASHING:
		velocity = dash_dir * _dash_speed()
	else:
		velocity = move_velocity + knock_velocity
	move_and_slide()
	if forced_through:
		position = world.arena.clamp_inside(position, radius)


# ------------------------------------------------------------------- casting

func try_cast(slot: String, aim_vec: Vector2, strength: float, from_buffer: bool = false) -> bool:
	var ab := ability(slot)
	if ab == null:
		return false
	if state == State.CASTING and cast and cast.can_dash_cancel() and slot == "basic":
		_end_cast(false)
	if not can_act():
		return false
	if cooldowns.get(slot, 0.0) > 0.0:
		if not from_buffer:
			cast_failed.emit(self, slot, "cooldown")
		return false
	if slot == "ult" and ult_charge < 100.0:
		cast_failed.emit(self, slot, "ult")
		return false
	if energy < ab.energy:
		cast_failed.emit(self, slot, "energy")
		return false
	var aim := resolve_aim(ab, aim_vec, strength)
	_start_cast(ab, slot, aim[0], aim[1])
	return true


## Returns [direction, target point] for an ability, auto-aiming when the
## controller gave no explicit direction.
func resolve_aim(ab: AbilityDef, aim_vec: Vector2, strength: float) -> Array:
	var reach := ab.reach
	if ab.aim == "self":
		return [aim_dir if aim_dir != Vector2.ZERO else facing, position]
	if aim_vec.length_squared() > 0.01:
		var d := aim_vec.normalized()
		return [d, position + d * reach * clampf(strength, 0.12, 1.0)]
	var target := world.nearest_enemy(self, reach * float(GameData.cfg("aim", "auto_aim_range_bonus", 1.2)) + 30.0)
	if target != null and (Settings.aim_assist or not is_player):
		var lead := float(GameData.cfg("aim", "projectile_lead", 0.6))
		var t := position.distance_to(target.position) / maxf(_ability_speed(ab), 1.0)
		var predicted := target.position + target.velocity * t * lead
		var d := (predicted - position)
		if d.length_squared() < 1.0:
			d = facing
		var dist := minf(d.length(), reach)
		return [d.normalized(), position + d.normalized() * dist]
	var fd := aim_dir if aim_dir != Vector2.ZERO else facing
	return [fd, position + fd * reach * 0.7]


func _ability_speed(ab: AbilityDef) -> float:
	for a in ab.actions:
		if a.get("do", "") == "projectile":
			return float(a.get("speed", 300.0))
	return 2000.0


func _start_cast(ab: AbilityDef, slot: String, dir: Vector2, point: Vector2) -> void:
	_cast_counter += 1
	var c := CastState.new()
	c.ability = ab
	c.slot = slot
	c.id = _cast_counter
	c.aim_dir = dir
	c.aim_point = point
	var stage_index := 0
	if not ab.combo.is_empty():
		stage_index = combo_index % ab.combo.size()
		combo_index += 1
		combo_timer = ab.combo_window
	var st: Dictionary = ab.stage(stage_index)
	# Variant (e.g. empowered basic during Outrage) from an active modifier.
	var variants: Dictionary = ab.raw.get("variants", {})
	if not variants.is_empty():
		for m in status.mods:
			var v: String = m.get("variant", "")
			if v != "" and variants.has(v):
				st = variants[v]
				break
	c.stage = st
	var spd := float(st.get("anim_speed", ab.anim_speed)) * status.attack_speed_mult()
	c.anim = st.get("anim", ab.anim)
	c.anim_speed = spd
	c.hit_time = library.hit_time(c.anim) / maxf(spd, 0.05)
	c.duration = float(st.get("cast_time", ab.cast_time)) / status.attack_speed_mult()
	c.duration = maxf(c.duration, c.hit_time + 0.02)
	c.move_mult = float(st.get("move_mult", ab.move_mult))
	c.super_armor = bool(st.get("super_armor", ab.super_armor))
	c.channel_aim = bool(st.get("channel_aim", false))
	c.cancel_after = float(st.get("cancel_after", c.hit_time + 0.05))
	for a in st.get("actions", []):
		var at = a.get("at", 0.0)
		var t := 0.0
		if at is String:
			t = c.hit_time if at == "hit" else 0.0
		else:
			t = float(at) / status.attack_speed_mult()
		c.actions.append([t, a])
	c.actions.sort_custom(func(x, y): return x[0] < y[0])
	cast = c
	state = State.CASTING
	facing = dir
	aim_dir = dir
	animator.set_direction_vector(dir)
	animator.play(c.anim, spd, true, 1 if st.get("anim_loop", false) else 0)
	energy -= ab.energy
	if ab.energy > 0.0:
		energy_delay = float(GameData.cfg("energy", "regen_delay", 0.45))
	cooldowns[slot] = 0.0 if instant_cooldown else ab.cooldown
	if slot == "ult":
		ult_charge = 0.0
	passive.on_cast(ab)
	cast_started.emit(self, slot)
	var sfx: String = st.get("sfx", ab.raw.get("sfx", ""))
	if sfx != "":
		Audio.play(sfx, position)
	_update_cast(0.0)


func _update_cast(delta: float) -> void:
	if cast == null:
		state = State.IDLE
		return
	cast.elapsed += delta
	if cast.is_transform and cast.elapsed >= 0.5:
		_finish_mega()
	while cast and cast.next < cast.actions.size() and cast.actions[cast.next][0] <= cast.elapsed:
		var a: Dictionary = cast.actions[cast.next][1]
		cast.next += 1
		ActionExecutor.execute(self, cast, a)
	if cast and cast.elapsed >= cast.duration:
		_end_cast(false)


func _end_cast(interrupted: bool) -> void:
	if cast and cast.is_transform:
		# Transformations cannot be lost to an interrupt: finish instantly.
		_finish_mega()
	cast = null
	if state == State.CASTING:
		state = State.IDLE


func cancel_cast() -> void:
	if state == State.CASTING:
		_end_cast(true)


# ---------------------------------------------------------------------- dash

func _dash_cfg(key: String, default_value: float) -> float:
	return float(form.dash.get(key, GameData.cfg("dash", key, default_value)))


func _dash_speed() -> float:
	return _dash_cfg("distance", 78.0) / maxf(_dash_cfg("duration", 0.16), 0.01)


func try_dash(dir: Vector2) -> bool:
	var cost := _dash_cfg("energy_cost", 30.0)
	if dash_cd > 0.0 or energy < cost:
		if energy < cost:
			cast_failed.emit(self, "dash", "energy")
		return false
	if state == State.CASTING and cast and (cast.can_dash_cancel() or cast.move_mult > 0.0 and not cast.super_armor):
		_end_cast(true)
	if state != State.IDLE:
		return false
	if dir.length_squared() < 0.01:
		dir = facing
	dash_dir = dir.normalized()
	facing = dash_dir
	state = State.DASHING
	dash_time = _dash_cfg("duration", 0.16)
	invuln = maxf(invuln, _dash_cfg("invulnerable_time", 0.14))
	energy -= cost
	energy_delay = float(GameData.cfg("energy", "regen_delay", 0.45))
	dash_cd = _dash_cfg("cooldown", 0.55)
	afterimage_time = dash_time
	collision_mask = LAYER_WORLD
	animator.play("dash", 2.6, true, 1)
	passive.on_dash()
	Audio.play("dash", position)
	world.vfx.burst(position, Color(1, 1, 1, 0.7), 5, 40.0, 0.25, 2.0)
	return true


func _update_dash(delta: float) -> void:
	dash_time -= delta
	if dash_time <= 0.0:
		state = State.IDLE
		collision_mask = LAYER_WORLD | LAYER_FIGHTERS
		move_velocity = dash_dir * move_speed * 0.8


func start_forced_move(dir: Vector2, distance: float, duration: float, through_walls: bool, p_invuln: float) -> void:
	forced_time = maxf(duration, 0.01)
	forced_velocity = dir.normalized() * (distance / forced_time)
	forced_through = through_walls
	collision_mask = 0 if through_walls else LAYER_WORLD
	if p_invuln > 0.0:
		invuln = maxf(invuln, p_invuln)
	facing = dir.normalized()


func _end_forced_move() -> void:
	forced_time = 0.0
	forced_velocity = Vector2.ZERO
	collision_mask = LAYER_WORLD | LAYER_FIGHTERS
	if forced_through:
		forced_through = false
		position = world.arena.find_free_position(position, radius)
	move_velocity = Vector2.ZERO


func teleport_to(p: Vector2) -> void:
	position = p
	move_velocity = Vector2.ZERO
	knock_velocity = Vector2.ZERO


func set_hidden(mode: String, duration: float) -> void:
	hidden_mode = mode
	hidden_time = duration
	hidden_total = duration
	queue_redraw()


func _unhide() -> void:
	var was := hidden_mode
	hidden_mode = ""
	hidden_time = 0.0
	animator.position = Vector2.ZERO
	animator.visible = true
	if was == "under":
		world.vfx.burst(position, Color("#a07a48"), 14, 90.0, 0.45, 3.0)
	queue_redraw()


# ------------------------------------------------------------------- damage

func receive_hit(info: DamageInfo) -> void:
	var amount := info.amount
	if infinite_hp:
		amount = mini(amount, hp - 1)
		_last_damage_time = 0.0
	hp = maxi(0, hp - amount)
	damage_taken += info.amount
	flash = 1.0
	status.on_damaged(info)
	var armored := status.has_super_armor() or (cast != null and cast.super_armor)
	if not armored:
		var kb := info.knockback * status.knockback_mult() / maxf(mass, 0.1)
		if kb > 1.0:
			var kv := info.direction.normalized() * kb
			if kv.length_squared() > knock_velocity.length_squared():
				knock_velocity = kv
		if info.hitstun > 0.0 and forced_time <= 0.0:
			if state == State.CASTING:
				_end_cast(true)
			if state == State.IDLE or state == State.HITSTUN:
				state = State.HITSTUN
				hitstun = maxf(hitstun, info.hitstun)
				animator.play("hurt", 1.0, true, 0)
	hp_changed.emit(self)
	if hp <= 0:
		faint()


func take_dot(amount: int, source: Fighter, status_id: String) -> void:
	if state == State.FAINTED or amount <= 0:
		return
	var a := amount
	if infinite_hp:
		a = mini(a, hp - 1)
		_last_damage_time = 0.0
	hp = maxi(0, hp - a)
	damage_taken += a
	if source and is_instance_valid(source):
		source.damage_dealt += a
	world.on_dot(self, a, status_id)
	hp_changed.emit(self)
	if hp <= 0:
		faint()


func heal(amount: int) -> void:
	if state == State.FAINTED:
		return
	hp = mini(max_hp, hp + amount)
	world.overlay.add_text(position + Vector2(0, -body_height), "+%d" % amount, Color(0.5, 1.0, 0.5))
	hp_changed.emit(self)


func gain_ult(amount: float) -> void:
	ult_charge = clampf(ult_charge + amount, 0.0, 100.0)


func gain_mega(amount: float) -> void:
	if mega_enabled and not mega_used:
		mega_charge = clampf(mega_charge + amount, 0.0, 100.0)


func on_hard_cc() -> void:
	if state == State.CASTING:
		_end_cast(true)
	if state == State.DASHING:
		state = State.IDLE
		collision_mask = LAYER_WORLD | LAYER_FIGHTERS


func faint() -> void:
	if state == State.FAINTED:
		return
	if cast:
		_end_cast(true)
	state = State.FAINTED
	_faint_time = 0.0
	hp = 0
	collision_layer = 0
	collision_mask = LAYER_WORLD
	status.clear_all(true)
	animator.play("faint", 1.0, true, 0)
	Audio.play("ko", position)
	world.vfx.burst(position, Color(1, 1, 1), 18, 110.0, 0.6, 3.0)
	fainted.emit(self)


## Resets transient combat state when entering the field (switch-in).
func on_enter_field() -> void:
	state = State.IDLE if hp > 0 else State.FAINTED
	cast = null
	hitstun = 0.0
	knock_velocity = Vector2.ZERO
	move_velocity = Vector2.ZERO
	forced_time = 0.0
	hidden_mode = ""
	animator.visible = true
	animator.position = Vector2.ZERO
	collision_layer = LAYER_FIGHTERS
	collision_mask = LAYER_WORLD | LAYER_FIGHTERS
	_pending.clear()
	animator.play("idle", 1.0, true)


func on_leave_field() -> void:
	status.clear_all(true)
	cast = null
	_pending.clear()


# -------------------------------------------------------------------- mega

func start_mega() -> void:
	var target_form := species.form_for_trigger("mega")
	if target_form == null or state != State.IDLE:
		return
	_cast_counter += 1
	var c := CastState.new()
	c.slot = "mega"
	c.id = _cast_counter
	c.duration = 0.9
	c.is_transform = true
	c.transform_form = target_form.id
	c.super_armor = true
	c.aim_dir = facing
	c.anim = "pose"
	c.actions.append([0.45, {"do": "vfx", "style": "ring", "color": "#b8f2ff", "radius": 42.0, "life": 0.5}])
	cast = c
	state = State.CASTING
	invuln = maxf(invuln, 0.9)
	mega_used = true
	mega_charge = 0.0
	animator.play_for("pose", 0.9)
	world.vfx.ring(position, Color("#ffffff"), 30.0, 0.9)
	world.vfx.burst(position, Color("#9be7ff"), 30, 120.0, 0.8, 3.0)
	Audio.play("mega", position)
	queue_action(0.45, {"do": "shake", "amount": 4.0, "time": 0.25}, c)
	queue_action(0.5, {"do": "vfx", "style": "burst", "color": "#ffffff", "count": 24, "speed": 140.0}, c)


func _finish_mega() -> void:
	if form.trigger == "mega" or state == State.FAINTED:
		return
	var target_form := species.form_for_trigger("mega")
	if target_form == null:
		return
	apply_form(target_form.id)
	flash = 1.0
	var dur := target_form.transform_duration
	if dur <= 0.0:
		dur = float(GameData.cfg("mega", "default_duration", 25.0))
	transform_time = dur


func revert_form() -> void:
	transform_time = -1.0
	apply_form(species.default_form)
	world.vfx.ring(position, Color("#ffffff"), 26.0, 0.4)


# -------------------------------------------------------------- emit points

## Returns [ground position, visual height] for projectiles fired in `dir`,
## using the PMD Offsets markers (hands/head) of the cast animation.
func get_emit_info(dir: Vector2) -> Array:
	var anim_name := cast.anim if cast else "shoot"
	var anim := library.get_anim(anim_name)
	var di := PMDSpriteImporter.direction_index(dir)
	var marker := anim.get_emit_point(di) if anim else Vector2.INF
	var ground := position + dir.normalized() * radius * 0.7
	var height := body_height * 0.45
	if marker != Vector2.INF:
		var local := marker - library.sprite_set.ground_offset
		ground.x += local.x * 0.5
		height = clampf(-local.y, 2.0, body_height + 8.0)
	return [ground, height]


# ------------------------------------------------------------------ visuals

func _process(delta: float) -> void:
	if animator == null or library == null:
		return
	_update_animation(delta)
	_material.set_shader_parameter("flash", clampf(flash, 0.0, 1.0) * 0.85)
	var tint := status.tint()
	var alpha := 1.0
	match hidden_mode:
		"vanish":
			alpha = 0.28 if is_player else 0.0
		"under":
			alpha = 0.0
		"air":
			var t := 1.0 - hidden_time / maxf(hidden_total, 0.01)
			animator.position.y = -sin(t * PI) * 26.0
	if invuln > 0.0 and state != State.DASHING and hidden_mode == "" and int(Time.get_ticks_msec() / 60) % 2 == 0:
		alpha *= 0.6
	animator.modulate = Color(tint.r, tint.g, tint.b, alpha)
	if afterimage_time > 0.0:
		afterimage_time -= delta
		_afterimage_acc += delta
		if _afterimage_acc >= 0.035:
			_afterimage_acc = 0.0
			world.vfx.afterimage_from(self, 0.22)
	if hidden_mode == "under" and Engine.get_process_frames() % 4 == 0:
		world.vfx.burst(position, Color("#8a6a3e"), 2, 40.0, 0.3, 2.0)
	var pa := passive.aura_color()
	if pa.a <= 0.0:
		for m in status.mods:
			if m.has("aura"):
				pa = Color.from_string(String(m["aura"]), Color.WHITE)
				break
	if pa.a > 0.0 and Engine.get_process_frames() % 6 == 0 and hidden_mode == "":
		world.vfx.burst(position + Vector2(randf_range(-radius, radius), -randf() * body_height), pa, 1, 18.0, 0.5, 2.0)


func _update_animation(delta: float) -> void:
	animator.set_direction_vector(facing)
	match state:
		State.FAINTED:
			animator.play("faint", 1.0, false, 0)
		State.DISABLED:
			if status.is_asleep():
				animator.play("sleep")
			elif status.is_frozen():
				return  # frozen in place: hold the current frame
			else:
				animator.play("hurt", 1.0, false, 0)
		State.HITSTUN:
			pass
		State.DASHING:
			animator.play("dash", 2.6, false, 1)
		State.CASTING:
			pass
		_:
			var spd := velocity.length()
			if spd > 12.0 and forced_time <= 0.0:
				animator.play("walk", clampf(spd / maxf(move_speed, 1.0), 0.6, 1.6) * 1.15)
			elif forced_time > 0.0:
				animator.play("dash", 2.6, false, 1)
			else:
				animator.play("idle")
	animator.advance(delta)


func _draw() -> void:
	# Ground shadow + team ring, cached until queue_redraw().
	var sh := library.sprite_set.shadow_size if library else 1
	var w := 7.0 + sh * 3.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.35))
	if hidden_mode != "under":
		draw_arc(Vector2.ZERO, w + 2.5, 0, TAU, 28, Color(team_color, 0.85), 1.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
