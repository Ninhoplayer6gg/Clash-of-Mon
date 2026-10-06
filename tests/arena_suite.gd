extends Node
## Arena + interactive terrain checks (v0.2). Run with:
##   godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/arena_suite.gd
## Static: every arena in roster.json loads, spawns are free, mirrored
## layouts are symmetric. In-match: lava, shallow water, tall grass
## concealment + reveal rules, bots vs concealment, fire burning grass and
## regrowing, bots leaving lava.

const PHASES := ["lava", "water", "conceal", "fire", "bot_hunt", "bot_lava"]

var _fail := 0
var _pass := 0
var _match: Node
var _phase := -1
var _frames := 0
var _fight := false
var _wait := 0
var _mem := {}


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", label)


func _ready() -> void:
	# The result overlay pauses the tree when a match ends: keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[arenas]")
	_static_tests()
	_next_phase()


# ------------------------------------------------------------------ static

func _static_tests() -> void:
	var gd := get_node("/root/GameData")
	var roster := GameData.load_json("res://data/roster.json")
	var ids: Array = roster.get("arenas", [])
	check(ids.has("volcano_crater") and ids.has("tropical_lagoon"), "new arenas listed in roster.json")
	check(gd.arena_ids.size() == ids.size(), "every arena in roster.json loads (%d/%d)" % [gd.arena_ids.size(), ids.size()])
	for id in ids:
		var data: Dictionary = gd.get_arena(id)
		check(not data.is_empty(), "%s: data loads" % id)
		if data.is_empty():
			continue
		check(String(data.get("name", "")) != "" and String(data.get("description", "")) != "", "%s: name + description" % id)
		var actors := Node2D.new()
		add_child(actors)
		var a := Arena.new()
		add_child(a)
		a.build(data, actors)
		check(a.spawns.size() >= 2, "%s: two spawns" % id)
		for s in a.spawns:
			check(not a.circle_blocked(s, 14.0), "%s: spawn %s not blocked" % [id, s])
			check(a.terrain_at(s) == ArenaTerrain.NONE, "%s: spawn %s on plain ground" % [id, s])
		var gap := a.spawns[0].distance_to(a.spawns[1])
		check(gap >= 380.0 and gap <= 620.0, "%s: spawns %.0f px apart" % [id, gap])
		if id == "volcano_crater" or id == "tropical_lagoon":
			check(a.bounds.size.x >= 1000 and a.bounds.size.x <= 1150 and a.bounds.size.y >= 700 and a.bounds.size.y <= 760, "%s: size %s" % [id, a.bounds.size])
			check(absf(gap - 500.0) < 30.0, "%s: spawns ~500 px apart" % id)
		if String(data.get("mirror", "")) == "x":
			_check_symmetry(id, a)
		a.queue_free()
		actors.queue_free()
	# Terrain content of the new arenas.
	var volcano := _build("volcano_crater")
	check(volcano.terrain.lava_regions.size() >= 6, "volcano has lava pools and channels (%d)" % volcano.terrain.lava_regions.size())
	check(volcano.terrain.is_lava(Vector2(550, 370)), "volcano centre is lava")
	var basalt := 0
	for o in volcano.obstacles:
		if o["kind"] == "wall":
			basalt += 1
	check(basalt >= 4, "volcano has basalt walls")
	var lagoon := _build("tropical_lagoon")
	check(lagoon.terrain.water_regions.size() >= 3, "lagoon has shallow water")
	check(lagoon.terrain.patches.size() >= 4, "lagoon has tall grass patches")
	var palms := 0
	for o in lagoon.obstacles:
		if o["kind"] == "palm":
			palms += 1
			check(o["shape"] == "circle" and o["blocks_move"] and o.get("canopy", false), "palm is a solid obstacle with fading canopy")
			break
	check(palms > 0, "lagoon has palm trees")
	var glade := _build("verdant_glade")
	check(glade.terrain.patches.size() >= 2, "verdant glade got tall grass")
	check(lagoon.terrain_at(Vector2(560, 370)) == ArenaTerrain.WATER, "lagoon centre is shallow water")
	check(lagoon.terrain_at(Vector2(192, 176)) == ArenaTerrain.GRASS, "lagoon grass patch queried by cell")
	check(lagoon.is_hazard(Vector2(560, 370)) == false and volcano.is_hazard(Vector2(550, 370)), "only lava is a hazard")
	for n in [volcano, lagoon, glade]:
		n.get_meta("actors").queue_free()
		n.queue_free()


func _build(id: String) -> Arena:
	var actors := Node2D.new()
	add_child(actors)
	var a := Arena.new()
	a.set_meta("actors", actors)
	add_child(a)
	a.build(get_node("/root/GameData").get_arena(id), actors)
	return a


func _check_symmetry(id: String, a: Arena) -> void:
	var w := a.bounds.size.x
	check(a.spawns[1].distance_to(Vector2(w - a.spawns[0].x, a.spawns[0].y)) < 1.0, "%s: spawns mirrored" % id)
	var missing := 0
	for o in a.obstacles:
		var mp := Vector2(w - o["pos"].x, o["pos"].y)
		var found := false
		for o2 in a.obstacles:
			if o2["kind"] == o["kind"] and o2["pos"].distance_to(mp) < 1.0:
				found = true
				break
		if not found:
			missing += 1
	check(missing == 0, "%s: every obstacle has a mirrored twin (%d missing)" % [id, missing])
	var mismatch := 0
	var total := 0
	var y := 3.37
	while y < a.bounds.size.y:
		var x := 2.71
		while x < w:
			total += 1
			if a.terrain_at(Vector2(x, y)) != a.terrain_at(Vector2(w - x, y)):
				mismatch += 1
			x += 9.0
		y += 9.0
	check(mismatch <= total / 500, "%s: terrain symmetric (%d/%d samples differ)" % [id, mismatch, total])


# ------------------------------------------------------------------ phases

func _next_phase() -> void:
	if _match:
		_match.queue_free()
		_match = null
	get_tree().paused = false
	_phase += 1
	_frames = 0
	_fight = false
	_mem.clear()
	if _phase >= PHASES.size():
		_finish()
		return
	var name_p: String = PHASES[_phase]
	print("[%s]" % name_p)
	match name_p:
		"lava":
			_start("volcano_crater", "pikachu", "charizard", "idle")
		"water":
			_start("tropical_lagoon", "pikachu", "blastoise", "idle")
		"conceal":
			_start("tropical_lagoon", "pikachu", "lucario", "idle")
		"fire":
			_start("tropical_lagoon", "charizard", "pikachu", "idle")
		"bot_hunt":
			_start("tropical_lagoon", "blastoise", "lucario", "active")
		"bot_lava":
			_start("volcano_crater", "pikachu", "lucario", "active")


func _start(arena: String, a: String, b: String, behavior: String) -> void:
	var game := get_node("/root/Game")
	var cfg: Dictionary = game.make_config("1v1", [a], [b], arena, false, {"bot_behavior": behavior})
	cfg["teams"][1]["behavior"] = behavior
	game.match_config = cfg
	_match = load("res://core/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_match)


func _physics_process(_d: float) -> void:
	if _match == null or not _match.is_inside_tree() or _match.teams.is_empty():
		return
	if not _fight:
		if _match.phase == 1:  # Phase.FIGHT
			_fight = true
			_frames = 0
			_match.player_ctrl.enabled = false  # tests drive the player's input
		return
	_frames += 1
	var me: Fighter = _match.teams[0].active_fighter()
	var foe: Fighter = _match.teams[1].active_fighter()
	var done := false
	match PHASES[_phase]:
		"lava":
			done = _phase_lava(me, foe)
		"water":
			done = _phase_water(me, foe)
		"conceal":
			done = _phase_conceal(me, foe)
		"fire":
			done = _phase_fire(me, foe)
		"bot_hunt":
			done = _phase_bot_hunt(me, foe)
		"bot_lava":
			done = _phase_bot_lava(me, foe)
	if done:
		_next_phase()


## Lava hurts and burns non-Fire types; Fire types are immune.
func _phase_lava(me: Fighter, foe: Fighter) -> bool:
	match _frames:
		1:
			me.position = Vector2(205, 182)   # side lava pool
			foe.position = Vector2(550, 370)  # central pool
			_mem["me_hp"] = me.hp
			_mem["foe_hp"] = foe.hp
		61:
			check(me.terrain_kind == ArenaTerrain.LAVA, "fighter standing in lava sees LAVA")
			var lost: int = int(_mem["me_hp"]) - me.hp
			check(lost >= int(me.max_hp * 0.04), "lava damages non-Fire types (-%d in 1 s)" % lost)
			check(me.status.has("burn"), "lava burns non-Fire types")
			check(foe.hp == int(_mem["foe_hp"]), "Fire type takes no lava damage")
			check(not foe.status.has("burn"), "Fire type is not burned by lava")
			check(foe.terrain_kind == ArenaTerrain.LAVA, "Fire type can stand in lava")
			return true
	return false


## Shallow water slows non-Water types, speeds Water types, puts out burns.
func _phase_water(me: Fighter, foe: Fighter) -> bool:
	var bot: BotController = _match.bots[1]
	match _frames:
		1:
			bot.set_physics_process(false)  # drive the Water type by hand
			me.position = Vector2(140, 300)   # plain grass ground
			foe.position = Vector2(140, 420)
			me.input.move = Vector2.RIGHT
			foe.input.move = Vector2.RIGHT
		30:
			_mem["land_me"] = me.velocity.length() / me.move_speed
			_mem["land_foe"] = foe.velocity.length() / foe.move_speed
			check(absf(float(_mem["land_me"]) - 1.0) < 0.05, "full speed on dry ground (%.2f)" % _mem["land_me"])
			me.position = Vector2(500, 340)   # central lagoon
			foe.position = Vector2(500, 410)
		60:
			var r_me := me.velocity.length() / me.move_speed
			var r_foe := foe.velocity.length() / foe.move_speed
			check(me.terrain_kind == ArenaTerrain.WATER and absf(me.terrain_speed_mult - 0.75) < 0.001, "shallow water multiplier 0.75 for non-Water")
			check(absf(r_me - 0.75) < 0.05, "non-Water type slowed in shallow water (%.2f)" % r_me)
			check(absf(foe.terrain_speed_mult - 1.1) < 0.001 and absf(r_foe - 1.1) < 0.05, "Water type faster in shallow water (%.2f)" % r_foe)
			me.input.move = Vector2.ZERO
			foe.input.move = Vector2.ZERO
			me.status.apply("burn", null, 3.0)
		63:
			check(not me.status.has("burn"), "shallow water puts out burns")
			bot.set_physics_process(true)
			return true
	return false


## Tall grass hides the foe from auto-aim / nearest_enemy / bots until it
## attacks, gets hit or an enemy comes close.
func _phase_conceal(me: Fighter, foe: Fighter) -> bool:
	var world: CombatWorld = _match.world
	var hide := Vector2(192, 176)  # lagoon top-left grass patch centre
	match _frames:
		1:
			foe.position = hide
			me.position = Vector2(300, 300)
		10:
			check(foe.concealed, "fighter in tall grass is concealed")
			check(world.nearest_enemy(me, 5000.0) == null, "concealed fighter skipped by nearest_enemy")
			check(not world.can_see(me, foe), "can_see false for concealed enemy")
			check(world.can_see(foe, foe), "own team always visible")
			# Auto-aim from a bot-controlled fighter ignores the hidden target.
			me.aim_dir = Vector2.DOWN
			var ab := me.ability("skill1")
			var aim: Array = me.resolve_aim(ab, Vector2.ZERO, 1.0)
			check(Vector2(aim[0]).dot(Vector2.DOWN) > 0.99, "auto-aim does not lock on a concealed enemy")
		40:
			check(foe.terrain_alpha < 0.05, "concealed enemy is invisible to the local player (alpha %.2f)" % foe.terrain_alpha)
			# Proximity reveal.
			me.position = hide + Vector2(45, 0)
		42:
			check(not foe.concealed, "enemy within reveal range is revealed")
			check(world.nearest_enemy(me, 500.0) == foe, "revealed enemy targetable again")
			me.position = Vector2(300, 300)
		50:
			check(foe.concealed, "concealed again once the enemy leaves")
			foe.input.request_cast("basic", Vector2.RIGHT, 1.0)
		53:
			check(not foe.concealed and foe.reveal_time > 0.5, "attacking reveals the hidden fighter")
		150:
			check(foe.concealed, "hidden again ~1 s after attacking")
			world.apply_hit(me, foe, me.ability("basic"), {"power": 60.0, "type": "electric"}, me.position, Vector2.LEFT)
		152:
			check(not foe.concealed, "being hit reveals the hidden fighter")
		230:
			check(foe.concealed, "hidden again after the hit reveal")
			# Own fighter in grass: drawn semi-transparent, not invisible.
			me.position = Vector2(192, 564)
		270:
			check(me.concealed and absf(me.terrain_alpha - ArenaTerrain.OWN_CONCEALED_ALPHA) < 0.05, "own concealed fighter is semi-transparent (%.2f)" % me.terrain_alpha)
			return true
	return false


## Fire-type hits / zones / projectiles burn tall grass; it regrows.
func _phase_fire(me: Fighter, foe: Fighter) -> bool:
	var world: CombatWorld = _match.world
	var terrain: ArenaTerrain = _match.arena.terrain
	var a := Vector2(192, 176)
	var b := Vector2(192, 564)
	var c := Vector2(928, 176)  # mirror of a
	match _frames:
		1:
			foe.position = a
			me.position = Vector2(330, 300)
		5:
			check(foe.concealed, "target hidden before the fire")
			world.apply_hit(me, foe, me.ability("skill3"), {"power": 40.0, "type": "electric"}, me.position, Vector2.LEFT)
			check(terrain.grass_patch_at(a) >= 0, "non-fire hit leaves the grass")
			world.apply_hit(me, foe, me.ability("basic"), {"power": 40.0, "type": "fire"}, me.position, Vector2.LEFT)
			check(terrain.grass_patch_at(a) < 0 and terrain.terrain_at(a) == ArenaTerrain.NONE, "fire hit burns the grass patch")
			check(terrain.patches[terrain.grass_patch_at(a, true)]["state"] == ArenaTerrain.Patch.BURNING, "patch is burning")
			# Fire zone (explosion / ground fire) over another patch.
			var z := world.spawn_zone(me, null, {"type": "fire", "radius": 18.0, "duration": 0.2, "power": 0.0}, 0)
			z.origin = b
			z.follow = false
			# Fire projectile landing in a third patch.
			world.spawn_projectile(me, null, {"type": "fire", "speed": 300.0, "range": 20.0, "radius": 5.0}, c - Vector2(20, 0), Vector2.RIGHT, 0)
		8:
			check(foe.terrain_kind == ArenaTerrain.NONE and not foe.concealed, "burning grass no longer conceals")
		12:
			check(terrain.grass_patch_at(b) < 0, "fire zone burns tall grass")
			check(terrain.grass_patch_at(c) < 0, "fire projectile landing burns tall grass")
			var i := terrain.grass_patch_at(a, true)
			terrain.tick_patches(2.0)
			check(terrain.patches[i]["state"] == ArenaTerrain.Patch.BURNT, "burnt after the flames")
			terrain.tick_patches(ArenaTerrain.GRASS_REGROW - 2.5)
			check(terrain.grass_patch_at(a) < 0, "still burnt before the regrow time")
			terrain.tick_patches(3.0)
			check(terrain.patches[i]["state"] == ArenaTerrain.Patch.GROWING, "regrowing after ~10 s")
			terrain.tick_patches(ArenaTerrain.GRASS_GROW_TIME + 0.1)
			check(terrain.grass_patch_at(a) == i, "grass regrown")
		90:
			check(foe.concealed, "regrown grass conceals again")
			return true
	return false


## An active bot whose target hides in grass hunts and finds it.
func _phase_bot_hunt(me: Fighter, foe: Fighter) -> bool:
	var bot: BotController = _match.bots[1]
	var world: CombatWorld = _match.world
	var hide := Vector2(192, 176)
	if _frames == 1:
		me.infinite_hp = true
		me.position = Vector2(240, 300)  # seen here first
		foe.position = Vector2(900, 600)
		_mem["hp"] = me.hp
		_mem["found"] = false
	elif _frames == 60:
		me.position = hide  # slips into the grass
	elif _frames == 75:
		_mem["hp"] = me.hp
		check(me.concealed, "player hidden in the grass")
		check(not world.can_see(foe, me), "bot cannot see the hidden player")
	elif _frames > 75:
		var hp0: int = _mem["hp"]
		if foe.position.distance_to(me.position) <= ArenaTerrain.REVEAL_RANGE or me.hp < hp0:
			_mem["found"] = true
		if _frames == 90:
			check(int(bot.stats.get("hunt", 0)) > 0, "bot switches to hunting a concealed target")
		if _mem["found"] or _frames > 60 * 12:
			check(_mem["found"], "bot finds the hidden player (%.1f s)" % ((_frames - 60) / 60.0))
			print("  bot found the hidden player after %.1f s" % ((_frames - 60) / 60.0))
			return true
	return false


## Active bots never idle in lava.
func _phase_bot_lava(me: Fighter, foe: Fighter) -> bool:
	var terrain: ArenaTerrain = _match.arena.terrain
	if _frames == 1:
		me.infinite_hp = true
		foe.position = Vector2(550, 370)  # centre of the lava pool
		me.position = Vector2(300, 370)
		_mem["in_lava"] = 0
		_mem["max_streak"] = 0
		_mem["streak"] = 0
	elif _frames == 90:
		check(not terrain.is_lava(foe.position), "bot left the lava within 1.5 s")
	elif _frames > 90:
		if terrain.is_lava(foe.position):
			_mem["streak"] = int(_mem["streak"]) + 1
			_mem["max_streak"] = maxi(int(_mem["max_streak"]), int(_mem["streak"]))
		else:
			_mem["streak"] = 0
		if _frames == 90 + 60 * 8:
			check(int(_mem["max_streak"]) < 60, "bot never lingers in lava (longest %d frames)" % int(_mem["max_streak"]))
			print("  longest stay in lava after escaping: %d frames" % int(_mem["max_streak"]))
			return true
	return false


func _finish() -> void:
	print("ARENA TESTS: %d passed, %d failed" % [_pass, _fail])
	set_physics_process(false)
	await get_tree().process_frame
	get_tree().quit(_fail)
