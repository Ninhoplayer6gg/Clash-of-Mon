extends Node2D
## Match scene: builds arena, combat world, fighters, controllers, camera,
## HUD and touch controls from Game.match_config, then runs the match flow
## (intro -> fight -> KO/switch -> result) for 1v1 and 3v3, plus training.

signal match_ended(winner: int)

enum Phase { INTRO, FIGHT, END }

const TEAM_COLORS := [Color(0.3, 0.72, 1.0), Color(1.0, 0.36, 0.33)]

var config := {}
var options := {}
var training := false
var phase := Phase.INTRO
var time_left := 0.0
var intro_left := 0.0
var teams: Array[TeamState] = []

var arena: Arena
var ground_fx: GroundFx
var actors: Node2D
var world: CombatWorld
var vfx: VfxLayer
var overlay: WorldOverlay
var camera: MatchCamera
var hud: Hud
var controls: MobileControls
var player_ctrl: PlayerController
var bots := {}  # team index -> BotController
var _controls_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _pause: PauseOverlay
var _result: ResultOverlay
var _pending_swaps: Array = []  # [time_left, team_index, new_index]
# v0.2 polish: game feel helpers (see _build_polish).
var hit_stop: HitStop
var feedback: ScreenFeedback
var offscreen: OffscreenIndicator
var tutorial: TutorialOverlay
var _tutorial_from_pause := false


func _ready() -> void:
	config = Game.match_config
	if config.is_empty():
		config = Game.make_config("1v1", ["pikachu"], ["lucario"], "verdant_glade", true)
	options = config.get("options", {})
	training = bool(config.get("training", false))
	_build_scene()
	_build_teams()
	_start_intro()
	_build_polish()
	DebugOverlay.match_ref = self


func _exit_tree() -> void:
	if DebugOverlay.match_ref == self:
		DebugOverlay.match_ref = null


# ------------------------------------------------------------------- build

func _build_scene() -> void:
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	ground_fx = GroundFx.new()
	ground_fx.name = "GroundFx"
	ground_fx.z_index = -2
	add_child(ground_fx)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	world = CombatWorld.new()
	world.name = "CombatWorld"
	add_child(world)
	vfx = VfxLayer.new()
	vfx.name = "Vfx"
	add_child(vfx)
	overlay = WorldOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	var arena_data := GameData.get_arena(String(config.get("arena", "verdant_glade")))
	if arena_data.is_empty():
		arena_data = GameData.get_arena(GameData.arena_ids[0])
	arena.build(arena_data, actors)
	world.arena = arena
	world.vfx = vfx
	world.overlay = overlay
	world.ground_fx = ground_fx
	world.show_hitboxes = Settings.show_hitboxes or bool(options.get("show_hitboxes", false))
	ground_fx.world = world
	overlay.world = world
	camera = MatchCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.set_bounds(arena.bounds)
	camera.make_current()
	world.shake_requested.connect(camera.shake)
	# UI
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	hud = Hud.new()
	hud.match_node = self
	_ui_layer.add_child(hud)
	_controls_layer = CanvasLayer.new()
	_controls_layer.layer = 11
	add_child(_controls_layer)
	controls = MobileControls.new()
	controls.visible = Settings.use_touch_controls()
	_controls_layer.add_child(controls)
	var top := CanvasLayer.new()
	top.layer = 20
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	_pause = PauseOverlay.new()
	_pause.match_node = self
	_pause.visible = false
	top.add_child(_pause)
	_result = ResultOverlay.new()
	_result.match_node = self
	_result.visible = false
	top.add_child(_result)
	hud.pause_pressed.connect(toggle_pause)
	hud.switch_pressed.connect(func(i): request_switch(0, i))
	Settings.changed.connect(_on_settings_changed)


func _build_teams() -> void:
	var cfg_teams: Array = config.get("teams", [])
	for ti in cfg_teams.size():
		var tc: Dictionary = cfg_teams[ti]
		var team := TeamState.new()
		team.index = ti
		team.controller = String(tc.get("controller", "bot"))
		team.color = TEAM_COLORS[ti % TEAM_COLORS.size()]
		for id in tc.get("members", []):
			var def := GameData.get_pokemon(String(id))
			if def == null:
				continue
			team.members.append(String(id))
			var f := Fighter.new()
			f.name = "%s_%d" % [id, ti]
			f.setup(def, ti, world)
			f.team_color = team.color
			f.is_player = team.controller == "player"
			f.mega_enabled = bool(options.get("mega_enabled", false))
			if training:
				f.instant_cooldown = bool(options.get("instant_cooldown", false)) and f.is_player
				f.infinite_hp = bool(options.get("infinite_hp", false)) and f.is_player
			f.fainted.connect(_on_fighter_fainted)
			team.fighters.append(f)
		teams.append(team)
	player_ctrl = PlayerController.new()
	player_ctrl.name = "PlayerController"
	player_ctrl.controls = controls
	player_ctrl.ground_fx = ground_fx
	add_child(player_ctrl)
	player_ctrl.switch_requested.connect(func(d): request_switch_dir(0, d))
	player_ctrl.pause_requested.connect(toggle_pause)
	for team in teams:
		if team.controller != "bot":
			continue
		var bot := BotController.new()
		bot.name = "Bot%d" % team.index
		bot.world = world
		bot.behavior = String(config["teams"][team.index].get("behavior", options.get("bot_behavior", "active")))
		bot.difficulty = clampi(int(options.get("bot_difficulty", 1)), 0, 2)
		bot.can_switch = team.fighters.size() > 1
		add_child(bot)
		var ti := team.index
		bot.switch_requested.connect(func(d): request_switch_dir(ti, d))
		bots[team.index] = bot
	for team in teams:
		_put_on_field(team, 0, arena.spawns[team.index % arena.spawns.size()])
	time_left = float(GameData.cfg("match", "time_limit_3v3" if _is_team_mode() else "time_limit_1v1", 120.0))
	if training or not bool(options.get("time_limit", true)):
		time_left = -1.0
	camera.target = teams[0].active_fighter()
	camera.snap_to_target()
	hud.setup(teams)


func _is_team_mode() -> bool:
	for t in teams:
		if t.fighters.size() > 1:
			return true
	return false


func _put_on_field(team: TeamState, i: int, pos: Vector2) -> void:
	team.active = i
	var f := team.fighters[i]
	f.position = arena.find_free_position(pos, f.radius)
	if not f.is_inside_tree():
		actors.add_child(f)
	f.on_enter_field()
	var foe_pos := arena.bounds.get_center()
	f.facing = (foe_pos - f.position).normalized()
	f.aim_dir = f.facing
	world.register_fighter(f)
	if team.controller == "player":
		player_ctrl.fighter = f
		controls.fighter = f
	elif bots.has(team.index):
		bots[team.index].set_fighter(f)
	if team.index == 0:
		camera.target = f
		controls.fighter = f


func _take_off_field(team: TeamState) -> void:
	var f := team.active_fighter()
	if f == null:
		return
	world.unregister_fighter(f)
	world.cancel_owner_zones(f)
	f.on_leave_field()
	if f.is_inside_tree():
		actors.remove_child(f)


# -------------------------------------------------------------- match flow

func _start_intro() -> void:
	phase = Phase.INTRO
	intro_left = float(GameData.cfg("match", "intro_time", 1.6))
	_set_controllers_enabled(false)


func _set_controllers_enabled(on: bool) -> void:
	player_ctrl.enabled = on
	for b in bots.values():
		b.set_physics_process(on)


func _physics_process(delta: float) -> void:
	for t in teams:
		if t.switch_cd > 0.0:
			t.switch_cd = maxf(0.0, t.switch_cd - delta)
	_tick_swaps(delta)
	match phase:
		Phase.INTRO:
			intro_left -= delta
			hud.set_center_text(_intro_text(), 0.2)
			if intro_left <= 0.0:
				phase = Phase.FIGHT
				_set_controllers_enabled(true)
				hud.set_center_text("LUTEM!", 0.7)
		Phase.FIGHT:
			if time_left > 0.0:
				time_left -= delta
				if time_left <= 0.0:
					time_left = 0.0
					_on_time_up()
	arena.update_canopies([teams[0].active_fighter()] if teams[0].active_fighter() else [])


func _intro_text() -> String:
	var t := intro_left / float(GameData.cfg("match", "intro_time", 1.6))
	if t > 0.66:
		return "3"
	elif t > 0.33:
		return "2"
	return "1"


func _on_time_up() -> void:
	# Higher remaining total HP ratio wins; tie = draw.
	var scores := []
	for t in teams:
		var s := 0.0
		for f in t.fighters:
			s += f.hp_ratio()
		scores.append(s)
	var winner := -1
	if scores[0] > scores[1] + 0.001:
		winner = 0
	elif scores[1] > scores[0] + 0.001:
		winner = 1
	_end_match(winner, "Tempo esgotado")


func _on_fighter_fainted(f: Fighter) -> void:
	var team := teams[f.team]
	var other := teams[1 - f.team]
	if f.team == 0:
		hud.set_center_text("%s foi derrotado!" % f.species.name, 1.2)
	else:
		hud.set_center_text_styled("NOCAUTE!", 1.1, "ko")
	TypeVfx.ko(vfx, f.position + Vector2(0, -f.body_height * 0.4), f.team_color)
	if training:
		# Training: revive after a short delay, never end the session.
		get_tree().create_timer(1.6, false).timeout.connect(func(): _training_revive(f))
		return
	if team.is_defeated():
		var deciding := phase != Phase.END
		_end_match(other.index, "")
		if deciding:
			_deciding_ko(f, other.index)
		return
	var next := team.next_available(1)
	_pending_swaps.append([float(GameData.cfg("switching", "swap_time", 0.35)) + 0.9, team.index, next])


func _training_revive(f: Fighter) -> void:
	if not is_instance_valid(f) or phase == Phase.END:
		return
	f.hp = f.max_hp
	f.energy = f.max_energy
	var team := teams[f.team]
	_take_off_field(team)
	_put_on_field(team, team.active, arena.spawns[f.team % arena.spawns.size()])
	f.invuln = 1.0
	vfx.ring(f.position, Color.WHITE, 24.0, 0.4)


func _end_match(winner: int, reason: String) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	_set_controllers_enabled(false)
	for t in teams:
		var f := t.active_fighter()
		if f:
			f.input.clear_triggers()
			f.input.move = Vector2.ZERO
	var won := winner == 0
	Game.last_result = {"winner": winner, "reason": reason, "time_left": time_left}
	match_ended.emit(winner)
	Audio.play("win" if won else "lose")
	hud.set_center_text("VITÓRIA!" if won else ("EMPATE" if winner < 0 else "DERROTA"), 1.4)
	get_tree().create_timer(float(GameData.cfg("match", "end_delay", 1.6)), false).timeout.connect(
		func(): _result.show_result(winner, reason, teams))


# --------------------------------------------------------------- switching

func request_switch_dir(team_index: int, direction: int) -> void:
	var team := teams[team_index]
	request_switch(team_index, team.next_available(direction))


func request_switch(team_index: int, i: int) -> void:
	if phase != Phase.FIGHT or team_index >= teams.size():
		return
	var team := teams[team_index]
	if not team.can_switch_to(i):
		return
	var cur := team.active_fighter()
	if cur and (cur.state == Fighter.State.DISABLED or cur.hidden_mode != ""):
		return
	team.switch_cd = float(GameData.cfg("switching", "cooldown", 6.0))
	if cur:
		vfx.ring(cur.position, team.color, 18.0, 0.3)
		cur.cancel_cast()
		cur.invuln = 1.0
	_pending_swaps.append([float(GameData.cfg("switching", "swap_time", 0.35)), team_index, i])


func _tick_swaps(delta: float) -> void:
	var k := _pending_swaps.size() - 1
	while k >= 0:
		var s: Array = _pending_swaps[k]
		s[0] -= delta
		if s[0] <= 0.0:
			_pending_swaps.remove_at(k)
			_do_swap(teams[s[1]], s[2])
		k -= 1


func _do_swap(team: TeamState, i: int) -> void:
	if phase == Phase.END or i < 0 or i >= team.fighters.size() or not team.fighters[i].is_alive():
		return
	var cur := team.active_fighter()
	var pos := cur.position if cur else arena.spawns[team.index]
	_take_off_field(team)
	_put_on_field(team, i, pos)
	var f := team.active_fighter()
	f.invuln = float(GameData.cfg("switching", "enter_invulnerable", 0.6))
	vfx.ring(f.position, team.color, 26.0, 0.4)
	vfx.burst(f.position, Color.WHITE, 14, 90.0, 0.4, 3.0)
	if team.controller == "player":
		hud.set_center_text("Vai, %s!" % f.species.name, 0.8)
	hud.refresh_team(team)


# ----------------------------------------------------------------- pausing

func toggle_pause() -> void:
	if phase == Phase.END and _result.visible:
		return
	var p := not get_tree().paused
	if p and hit_stop:
		hit_stop.cancel()
	get_tree().paused = p
	_pause.visible = p
	if p:
		controls.reset_state()


func restart() -> void:
	get_tree().paused = false
	Game.restart_match()


func quit_to_menu() -> void:
	get_tree().paused = false
	Game.goto("main_menu")


func _on_settings_changed() -> void:
	world.show_hitboxes = Settings.show_hitboxes or bool(options.get("show_hitboxes", false))
	controls.visible = Settings.use_touch_controls()
	if hit_stop:
		hit_stop.enabled = _hit_stop_allowed()
		if not hit_stop.enabled:
			hit_stop.cancel()


func _notification(what: int) -> void:
	# Auto-pause when the app goes to background (Android).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if phase == Phase.FIGHT and not get_tree().paused:
			toggle_pause()


# ------------------------------------------------------------------- debug

func player_fighter() -> Fighter:
	return teams[0].active_fighter() if not teams.is_empty() else null


func debug_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("projéteis %d (pool %d/%d) | zonas %d (pool %d/%d) | partículas %d/%d" % [
		world.projectiles.size(), world.proj_pool.in_use, world.proj_pool.created,
		world.zones.size(), world.zone_pool.in_use, world.zone_pool.created,
		vfx.count, vfx.capacity])
	for t in teams:
		var f := t.active_fighter()
		if f == null:
			continue
		var cds := []
		for s in Fighter.SLOTS:
			cds.append("%s:%.1f" % [s.substr(0, 2), f.cooldowns[s]])
		out.append("[%s] %s pos(%d,%d) vel %.0f | %s | anim %s/%s dir %d" % [
			"J" if t.controller == "player" else "B", f.species.name, f.position.x, f.position.y,
			f.velocity.length(), f.state_name(), f.animator.current,
			f.animator.current_anim.name if f.animator.current_anim else "-", f.animator.dir_index])
		out.append("    HP %d/%d EN %.0f ULT %.0f MEGA %.0f | %s | st %s" % [
			f.hp, f.max_hp, f.energy, f.ult_charge, f.mega_charge, " ".join(cds), ",".join(f.status.visible_ids())])
	return out


# ------------------------------------------------------- v0.2 game feel

## Hit-stop, low-HP vignette, offscreen enemy marker, cast whoosh and the
## first-match tutorial. Built after the scene and teams exist.
func _build_polish() -> void:
	hit_stop = HitStop.new()
	hit_stop.name = "HitStop"
	hit_stop.camera = camera
	add_child(hit_stop)
	hit_stop.enabled = _hit_stop_allowed()
	world.hit_stop = hit_stop
	feedback = ScreenFeedback.new()
	feedback.match_node = self
	_ui_layer.add_child(feedback)
	_ui_layer.move_child(feedback, 0)  # below the HUD
	feedback.watch(world)
	offscreen = OffscreenIndicator.new()
	offscreen.match_node = self
	_ui_layer.add_child(offscreen)
	tutorial = TutorialOverlay.new()
	tutorial.visible = false
	_pause.get_parent().add_child(tutorial)
	tutorial.closed.connect(_on_tutorial_closed)
	for t in teams:
		for f in t.fighters:
			f.cast_started.connect(_on_cast_started)
	if _should_auto_tutorial():
		show_tutorial(false)


func _has_local_player() -> bool:
	return not teams.is_empty() and teams[0].controller == "player"


## Real players only: bots/tests run headless and must not depend on the
## wall clock the hit-stop uses.
func _hit_stop_allowed() -> bool:
	return Settings.hit_stop and _has_local_player() and DisplayServer.get_name() != "headless"


func _should_auto_tutorial() -> bool:
	return not Settings.tutorial_seen and _has_local_player() and DisplayServer.get_name() != "headless"


## Opens "Como jogar" (pauses the match; from the pause menu it returns there).
func show_tutorial(from_pause: bool) -> void:
	_tutorial_from_pause = from_pause
	if hit_stop:
		hit_stop.cancel()
	get_tree().paused = true
	_pause.visible = false
	controls.reset_state()
	tutorial.open(Settings.use_touch_controls())


func _on_tutorial_closed() -> void:
	if not Settings.tutorial_seen:
		Settings.set_value("tutorial_seen", true)
	if _tutorial_from_pause:
		_pause.visible = true
	elif not _result.visible:
		get_tree().paused = false


func _on_cast_started(f: Fighter, slot: String) -> void:
	if slot == "basic" or slot == "mega":
		return
	var ab := f.ability(slot)
	if ab and String(ab.raw.get("sfx", "")) == "":
		Audio.play("cast", f.position, -4.0)


## Match-deciding KO: punchy text, slow motion + camera punch-in on the
## fallen fighter, then the result announcement.
func _deciding_ko(f: Fighter, winner: int) -> void:
	Audio.play("ko_big", f.position)
	hud.set_center_text_styled("NOCAUTE!", 0.85, "ko")
	if hit_stop and hit_stop.enabled:
		camera.target = f
		hit_stop.slowmo(0.55, 0.3)
	get_tree().create_timer(0.85, false).timeout.connect(_announce_result.bind(winner))


func _announce_result(winner: int) -> void:
	hud.set_center_text("VITÓRIA!" if winner == 0 else ("EMPATE" if winner < 0 else "DERROTA"), 1.2)
