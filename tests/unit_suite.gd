extends Node
## Unit-style checks for core systems (importer, type chart, damage,
## statuses, forms/mega, switching). Loaded by tests/run_unit_tests.gd so
## autoloads exist before these scripts compile.

var _fail := 0
var _pass := 0
var _match: Node
var _step := 0
var _frames := 0
var gd: Node
var root: Node


func _ready() -> void:
	root = get_tree().root
	_run()


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", label)


func _run() -> void:
	gd = root.get_node("/root/GameData")
	_test_importer()
	_test_type_chart()
	_test_data()
	_start_match_tests()


func _test_importer() -> void:
	print("[importer]")
	var s := PMDSpriteImporter.load_sprite_set("res://assets/pmd/sprite/0025")
	check(s.anims.size() >= 30, "pikachu has many anims (%d)" % s.anims.size())
	var walk: PMDAnim = s.get_anim("Walk")
	check(walk != null and walk.frame_size == Vector2i(32, 40), "walk frame size 32x40")
	check(walk.rows == 8, "walk has 8 directions")
	check(walk.frame_count() == 4 and walk.total_ticks == 36, "walk durations 8+10+8+10")
	var atk: PMDAnim = s.get_anim("Attack")
	check(atk.hit_frame == 3 and atk.rush_frame == 1 and atk.return_frame == 6, "attack hit/rush/return frames")
	check(is_equal_approx(atk.hit_time(), 7.0 / 60.0), "attack hit time from durations")
	var p := atk.get_point(0, 0, PMDAnim.Point.HEAD)
	check(p == Vector2(-1, -7), "head marker parsed from Offsets.png (%s)" % p)
	var sleep: PMDAnim = s.get_anim("Sleep")
	check(sleep.rows == 1, "single-direction sheets supported")
	var luc := PMDSpriteImporter.load_sprite_set("res://assets/pmd/sprite/0448")
	var sp: PMDAnim = luc.get_anim("SpAttack")
	check(sp != null and sp.copy_of == "RearUp" and sp.texture == luc.get_anim("RearUp").texture, "CopyOf shares source sheet")
	check(PMDSpriteImporter.direction_index(Vector2.DOWN) == 0, "dir down = row 0")
	check(PMDSpriteImporter.direction_index(Vector2.RIGHT) == 2, "dir right = row 2")
	check(PMDSpriteImporter.direction_index(Vector2.UP) == 4, "dir up = row 4")
	check(PMDSpriteImporter.direction_index(Vector2.LEFT) == 6, "dir left = row 6")
	check(PMDSpriteImporter.direction_index(Vector2(1, 1)) == 1, "dir down-right = row 1")
	var credits := PMDSpriteImporter.parse_credits("res://assets/pmd/sprite/0448/credits.txt")
	check(credits.size() >= 2 and credits[0]["official"] and not credits[1]["official"], "credits parsed, official vs community")
	var lib := AnimLibrary.new(s, {"bolt": ["Shock"]})
	check(lib.get_anim("bolt").name == "Shock", "anim_map override")
	check(lib.get_anim("strike").name == "Attack", "fallback strike -> Attack for Pikachu")
	for id in gd.roster:
		var def: PokemonDef = gd.get_pokemon(id)
		for fid in def.forms.keys():
			var f: FormDef = def.forms[fid]
			var ss := PMDSpriteImporter.load_sprite_set(f.sprite_folder)
			check(ss.has_anim("Idle") and ss.has_anim("Walk") and ss.has_anim("Hurt"), "%s/%s has Idle/Walk/Hurt" % [id, fid])
			var l := AnimLibrary.new(ss, f.anim_map)
			for slot in FormDef.SLOTS:
				var ab := f.ability(slot)
				check(ab != null, "%s/%s has %s" % [id, fid, slot])
				if ab:
					check(l.get_anim(ab.anim) != null, "%s %s anim '%s' resolves" % [id, slot, ab.anim])


func _test_type_chart() -> void:
	print("[types]")
	var c: TypeChart = gd.type_chart
	check(is_equal_approx(c.effectiveness("electric", ["water"]), 1.15), "electric > water = 1.15")
	check(is_equal_approx(c.effectiveness("fire", ["water"]), 0.87), "fire < water = 0.87")
	check(c.effectiveness("ground", ["flying"]) >= 0.7 and c.effectiveness("ground", ["flying"]) < 0.8, "immunity is moderate, not 0")
	check(c.effectiveness("ice", ["dragon", "ground"]) <= 1.3, "dual weakness clamped to max_total")
	check(c.effectiveness("normal", ["ghost"]) >= 0.7, "clamped to min_total")


func _test_data() -> void:
	print("[data]")
	check(gd.roster.size() == 6, "six Pokémon in roster")
	var luc: PokemonDef = gd.get_pokemon("lucario")
	var mega := luc.form_for_trigger("mega")
	check(mega != null, "Lucario has a mega form")
	check(mega.stat("attack") > luc.base_form().stat("attack"), "mega stat_mult applied")
	check(mega.ability("skill1") != null and mega.ability("skill1").id == "force_palm", "mega inherits abilities")
	check(mega.sprite_folder.ends_with("0448/0001"), "mega uses its own sprite folder")
	check(gd.arena_ids.size() >= 1, "arenas loaded")


# ------------------------------------------------------------ in-match tests

func _start_match_tests() -> void:
	print("[match]")
	var game := root.get_node("/root/Game")
	var cfg: Dictionary = game.make_config("3v3", ["lucario", "pikachu", "blastoise"], ["garchomp", "gengar", "charizard"], "verdant_glade", false, {"mega_enabled": true, "bot_behavior": "idle"})
	cfg["teams"][0]["controller"] = "bot"
	game.match_config = cfg
	_match = load("res://core/match.tscn").instantiate()
	root.add_child(_match)


func _physics_process(_d: float) -> void:
	if _match == null:
		return
	_frames += 1
	var t0: TeamState = _match.teams[0]
	var t1: TeamState = _match.teams[1]
	var me: Fighter = t0.active_fighter()
	var foe: Fighter = t1.active_fighter()
	match _step:
		0:
			if _frames > 110:  # intro done
				_step = 1
				# Place fighters close for deterministic hits.
				me.position = Vector2(400, 380)
				foe.position = Vector2(430, 380)
				me.facing = Vector2.RIGHT
				me.aim_dir = Vector2.RIGHT
		1:
			var hp_before := foe.hp
			me.input.request_cast("skill1", Vector2.RIGHT, 1.0)  # Force Palm
			_step = 2
			_frames = 0
			set_meta("hp_before", hp_before)
		2:
			if _frames == 40:
				check(foe.hp < int(get_meta("hp_before")), "Force Palm damaged target")
				check(me.cooldowns["skill1"] > 0.0, "cooldown started")
				check(me.energy < me.max_energy, "energy spent")
				# Status: burn ticks
				foe.status.apply("burn", me)
				set_meta("hp_burn", foe.hp)
			if _frames == 100:
				check(foe.hp < int(get_meta("hp_burn")), "burn deals damage over time")
				foe.status.apply("sleep", me)
				check(foe.status.is_asleep(), "sleep applied")
			if _frames == 104:
				check(foe.state == Fighter.State.DISABLED, "sleeping fighter is disabled")
				foe.position = me.position + Vector2(24, 0)
				me.input.request_cast("basic", Vector2.RIGHT, 1.0)
			if _frames == 140:
				check(not foe.status.is_asleep(), "damage wakes the target")
				check(not foe.status.apply("sleep", me), "sleep immunity after waking")
				check(not foe.status.apply("poison", me) or not foe.types.has("poison"), "type immunity (poison)")
				# Mega Evolution
				me.mega_charge = 100.0
				set_meta("atk_before", me.get_stat("attack"))
				me.input.mega = true
			if _frames == 200:
				check(me.form.id == "mega", "mega evolution applied")
				check(me.get_stat("attack") > float(get_meta("atk_before")), "mega stats applied")
				check(me.library.sprite_set.folder.ends_with("0448/0001"), "mega sprite set swapped")
				check(me.transform_time > 0.0, "mega has a duration")
				me.transform_time = 0.01
			if _frames == 210:
				check(me.form.id == "base", "mega reverts after duration")
				# Switching
				t0.switch_cd = 0.0
				_match.request_switch(0, 1)
			if _frames == 250:
				check(t0.active == 1 and t0.active_fighter().species.id == "pikachu", "switched to Pikachu")
				check(t0.switch_cd > 0.0, "switch cooldown running")
				var before := t0.active
				_match.request_switch(0, 2)
				set_meta("before", before)
			if _frames == 290:
				check(t0.active == int(get_meta("before")), "switch blocked during cooldown")
				# Faint -> forced swap, fainted can't return
				var f := t0.active_fighter()
				f.hp = 1
				f.take_dot(10, null, "")
			if _frames == 420:
				check(not t0.fighters[1].is_alive(), "Pikachu fainted")
				check(t0.active != 1, "auto swap after faint")
				t0.switch_cd = 0.0
				_match.request_switch(0, 1)
			if _frames == 460:
				check(t0.active != 1, "fainted Pokémon cannot return")
				check(_match.world.proj_pool.created <= 64, "projectile pool bounded")
				_finish()


func _finish() -> void:
	print("UNIT TESTS: %d passed, %d failed" % [_pass, _fail])
	set_physics_process(false)
	_match.queue_free()
	await get_tree().process_frame
	get_tree().quit(_fail)
