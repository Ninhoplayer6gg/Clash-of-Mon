extends Node
## v0.2 combat polish checks: skill icon inference (every ability of every
## roster Pokémon + unknown/future data), hit-stop always restoring
## Engine.time_scale (expiry, pause, cancel, match freed mid-effect, KO
## slow motion), tutorial flag persistence and offscreen indicator
## edge-clamping geometry.
##   godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/polish_suite.gd [verbose]

var _fail := 0
var _pass := 0
var _verbose := false
var _game: Node
var _settings: Node


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", label)


func _ready() -> void:
	_verbose = OS.get_cmdline_user_args().has("verbose")
	_game = get_node("/root/Game")
	_settings = get_node("/root/Settings")
	_test_icons()
	_test_icon_robustness()
	_test_icon_geometry()
	_test_offscreen_math()
	_test_feedback_math()
	await _test_hit_stop()
	await _test_ko_slowmo()
	await _test_tutorial()
	await _test_offscreen_in_match()
	Engine.time_scale = 1.0
	get_tree().paused = false
	print("POLISH TESTS: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(_fail)


# ------------------------------------------------------------------ icons

func _test_icons() -> void:
	print("[icons]")
	var gd := get_node("/root/GameData")
	for id in gd.roster:
		var def: PokemonDef = gd.get_pokemon(id)
		for fid in def.forms.keys():
			var form: FormDef = def.forms[fid]
			var kit := SkillIcons.assign_kit(form.abilities)
			var line := PackedStringArray()
			for slot in FormDef.SLOTS:
				var ab := form.ability(slot)
				if ab == null:
					continue
				var single := SkillIcons.infer(ab)
				check(SkillIcons.SHAPES.has(single), "%s/%s %s infers a valid shape (%s)" % [id, fid, ab.id, single])
				var s := SkillIcons.shape_for(ab, form)
				check(SkillIcons.SHAPES.has(s), "%s/%s %s kit shape valid (%s)" % [id, fid, ab.id, s])
				check(s == kit.get(slot, ""), "%s %s cached kit shape matches the kit assignment" % [id, slot])
				line.append("%s=%s" % [ab.name, s])
			if _verbose:
				print("  %s/%s: %s" % [id, fid, ", ".join(line)])
	# Hand-checked v0.1 kits keep readable, distinct icons.
	var expected := {
		"pikachu": ["bolt", "orb", "beam", "dash", "storm"],
		"charizard": ["claw", "flame", "comet", "wing", "burst"],
		"gengar": ["bubble", "orb", "eye", "swirl", "ghost"],
	}
	for id in expected.keys():
		var def: PokemonDef = gd.get_pokemon(id)
		if def == null:
			continue
		var got := []
		for slot in FormDef.SLOTS:
			got.append(SkillIcons.shape_for(def.base_form().ability(slot), def.base_form()))
		check(got == expected[id], "%s icons %s" % [id, str(got)])


func _test_icon_robustness() -> void:
	print("[icons: unknown data]")
	var weird := {
		"id": "zz_future_move", "name": "Movimento Desconhecido", "type": "cosmic",
		"actions": [{"do": "summon_meteor_party", "vfx": {"style": "rainbow"}}, {"do": 42}, "not a dict"],
		"combo": [{"actions": [{"do": "???"}]}],
	}
	check(SkillIcons.SHAPES.has(SkillIcons.infer_from_dict(weird)), "unknown action/move types fall back to a valid shape")
	check(SkillIcons.SHAPES.has(SkillIcons.infer_from_dict({})), "empty ability dict -> valid shape")
	check(SkillIcons.infer_from_dict({"icon_shape": "heart", "type": "fire", "actions": [{"do": "projectile"}]}) == "heart", "icon_shape override wins")
	check(SkillIcons.infer_from_dict({"icon_shape": "nope", "type": "water"}) == "droplet", "invalid icon_shape override is ignored")
	var combo_only := {"id": "triple_kick", "type": "fighting", "combo": [{"actions": [{"do": "melee", "shape": "sector"}]}]}
	check(SkillIcons.infer_from_dict(combo_only) == "fist", "combo-only melee kit infers a fist")
	# A whole fake form made of odd abilities still resolves every slot.
	var abilities := {}
	var slots := ["basic", "skill1", "skill2", "skill3", "ult"]
	for i in slots.size():
		abilities[slots[i]] = AbilityDef.from_dict({"id": "x%d" % i, "type": "unknown", "actions": [{"do": "warp_%d" % i}]}, slots[i])
	var kit := SkillIcons.assign_kit(abilities)
	var ok := kit.size() == 5
	for s in kit.values():
		ok = ok and SkillIcons.SHAPES.has(s)
	check(ok, "kit of unknown abilities gets 5 valid shapes (%s)" % str(kit.values()))
	for t in get_node("/root/GameData").types.get("colors", {}).keys():
		check(SkillIcons.TYPE_SHAPES.has(t), "type %s has a fallback shape" % t)


func _test_icon_geometry() -> void:
	print("[icons: geometry]")
	var bad := []
	for shape in SkillIcons.SHAPES + SkillIcons.UI_SHAPES:
		var ops: Array = SkillIcons._get_ops(shape)
		if ops.is_empty():
			bad.append(shape)
			continue
		for op in ops:
			if op[0] == SkillIcons.Op.POLY:
				var pts: PackedVector2Array = op[2]
				if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
					bad.append(shape)
	check(bad.is_empty(), "every icon polygon triangulates (bad: %s)" % str(bad))


# --------------------------------------------------------- offscreen math

func _test_offscreen_math() -> void:
	print("[offscreen: geometry]")
	var r := Rect2(0, 0, 1280, 720)
	check(_near(OffscreenIndicator.edge_point(r, Vector2(3000, 360)), Vector2(1280, 360)), "right edge clamp")
	check(_near(OffscreenIndicator.edge_point(r, Vector2(640, -900)), Vector2(640, 0)), "top edge clamp")
	check(_near(OffscreenIndicator.edge_point(r, Vector2(-640, 360)), Vector2(0, 360)), "left edge clamp")
	check(_near(OffscreenIndicator.edge_point(r, Vector2(640, 5000)), Vector2(640, 720)), "bottom edge clamp")
	var corner := OffscreenIndicator.edge_point(r, Vector2(640 + 6400, 360 - 3600))
	check(_near(corner, Vector2(1280, 0)), "diagonal clamps into the corner (%s)" % corner)
	var inside := Vector2(900, 200)
	check(OffscreenIndicator.edge_point(r, inside) == inside, "point inside stays put")
	var p := OffscreenIndicator.edge_point(r, Vector2(2000, 1000))
	check(p.x <= 1280.001 and p.y <= 720.001 and is_equal_approx(p.x, 1280.0), "clamped point lies on the rect border (%s)" % p)
	var dir_ok := (p - r.get_center()).normalized().is_equal_approx((Vector2(2000, 1000) - r.get_center()).normalized())
	check(dir_ok, "clamped point keeps the direction to the target")
	var mr := OffscreenIndicator.marker_rect(Vector2(1280, 720))
	check(mr.position.y >= OffscreenIndicator.INSET_TOP and mr.end.x <= 1280.0 and mr.end.y <= 720.0, "marker rect is inset (HUD-safe)")
	check(OffscreenIndicator.marker_rect(Vector2(20, 20)).size.x > 0.0, "tiny viewports still give a valid marker rect")
	check(OffscreenIndicator.distance_alpha(0.0) > OffscreenIndicator.distance_alpha(400.0), "farther enemies are fainter")
	check(OffscreenIndicator.distance_alpha(99999.0) >= 0.4, "far enemies stay visible")


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


func _test_feedback_math() -> void:
	print("[feedback]")
	check(ScreenFeedback.low_hp_alpha(1.0, 0.3) == 0.0, "no vignette at full HP")
	check(ScreenFeedback.low_hp_alpha(0.3, 0.3) == 0.0, "no vignette above 25%")
	check(ScreenFeedback.low_hp_alpha(0.1, 0.3) > 0.0, "vignette below 25%")
	check(ScreenFeedback.low_hp_alpha(0.0, 0.3) == 0.0, "no vignette once fainted")


# --------------------------------------------------------------- hit-stop

func _new_match(player: String = "pikachu", foe: String = "blastoise", training: bool = false) -> Node:
	var cfg: Dictionary = _game.make_config("1v1", [player], [foe], "verdant_glade", training, {"bot_behavior": "idle"})
	_game.match_config = cfg
	var m: Node = load("res://core/match.tscn").instantiate()
	get_tree().root.add_child(m)
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits real (wall-clock) time: the hit-stop runs on the real clock.
func _real_wait(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await get_tree().process_frame


func _test_hit_stop() -> void:
	print("[hit-stop]")
	var m := _new_match()
	await _frames(2)
	var hs: HitStop = m.hit_stop
	check(hs != null and m.world.hit_stop == hs, "match owns a HitStop wired into CombatWorld")
	check(not hs.enabled, "hit-stop is off in headless runs (bots/tests stay wall-clock independent)")
	check(not m.tutorial.visible and not get_tree().paused, "no automatic tutorial in headless runs")
	hs.enabled = true
	# Light hits never freeze.
	hs.on_heavy_hit(120.0)
	check(Engine.time_scale == 1.0, "light hit: no hit-stop")
	# Heavy hit: short freeze, then restored on the real clock.
	hs.on_heavy_hit(520.0)
	check(Engine.time_scale < 0.5 and hs.is_active(), "heavy hit dips Engine.time_scale (%.2f)" % Engine.time_scale)
	await _real_wait(0.2)
	check(Engine.time_scale == 1.0 and not hs.is_active(), "freeze restored after its real-time duration")
	# A real heavy hit landing on the player goes through CombatWorld.
	await _real_wait(0.15)
	var me: Fighter = m.player_fighter()
	var foe: Fighter = m.teams[1].active_fighter()
	foe.invuln = 0.0
	me.invuln = 0.0
	m.world.apply_hit(foe, me, foe.ability("skill1"), {"power": 420.0, "type": "water"}, foe.position, Vector2.RIGHT)
	check(Engine.time_scale < 1.0, "heavy hit on the player triggers hit-stop via apply_hit")
	await _real_wait(0.2)
	check(Engine.time_scale == 1.0, "restored after apply_hit freeze")
	# Pausing restores immediately and nothing starts while paused.
	hs.freeze(5.0)
	m.toggle_pause()
	check(Engine.time_scale == 1.0, "pause menu restores time scale at once")
	hs.freeze(5.0)
	check(Engine.time_scale == 1.0, "no hit-stop while paused")
	m.toggle_pause()
	await _real_wait(0.15)
	hs.freeze(5.0)
	get_tree().paused = true
	await _frames(2)
	check(Engine.time_scale == 1.0, "external pause also restores (watchdog)")
	get_tree().paused = false
	# Settings toggle off cancels a running effect.
	await _real_wait(0.15)
	hs.freeze(5.0)
	_settings.hit_stop = false
	_settings.changed.emit()
	check(Engine.time_scale == 1.0 and not hs.enabled, "turning the setting off cancels hit-stop")
	_settings.hit_stop = true
	_settings.changed.emit()
	hs.enabled = true
	# Freed mid-effect (scene change / restart): must restore.
	hs.slowmo(5.0, 0.3)
	await _frames(3)
	check(Engine.time_scale < 1.0, "slow motion running before the match is freed")
	check(m.camera.zoom.x > m.camera._fit_z, "slow motion punches the camera in")
	m.queue_free()
	await _frames(2)
	check(Engine.time_scale == 1.0, "freeing the match mid-effect restores Engine.time_scale")


func _test_ko_slowmo() -> void:
	print("[KO slow motion]")
	var m := _new_match("lucario", "gengar")
	await _frames(2)
	m.hit_stop.enabled = true
	var foe: Fighter = m.teams[1].active_fighter()
	foe.hp = 1
	foe.take_dot(10, m.player_fighter(), "poison")
	check(not foe.is_alive(), "foe fainted")
	check(m.phase == m.Phase.END, "deciding KO ends the match")
	check(m.hit_stop.is_slowmo() and Engine.time_scale < 1.0, "deciding KO triggers slow motion")
	check(m.hud._center_text == "NOCAUTE!" and m.hud._center_style == "ko", "styled NOCAUTE! announcement")
	await _real_wait(0.75)
	check(Engine.time_scale == 1.0 and not m.hit_stop.is_active(), "slow motion ends and restores time scale")
	check(is_equal_approx(m.camera._zoom_mult, 1.0), "camera zoom restored after the KO")
	m.queue_free()
	await _frames(2)
	get_tree().paused = false
	check(Engine.time_scale == 1.0, "time scale still 1 after the match is gone")


# --------------------------------------------------------------- tutorial

func _test_tutorial() -> void:
	print("[tutorial]")
	var original: bool = _settings.tutorial_seen
	_settings.set_value("tutorial_seen", false)
	var cfg := ConfigFile.new()
	check(cfg.load(_settings.PATH) == OK and cfg.get_value("settings", "tutorial_seen", true) == false, "tutorial_seen=false persisted")
	var m := _new_match()
	await _frames(2)
	# Opened from the pause menu: closing returns to the pause menu.
	m.toggle_pause()
	m.show_tutorial(true)
	check(m.tutorial.visible and not m._pause.visible and get_tree().paused, "tutorial opens over a paused match")
	check(m.tutorial._rows.get_child_count() >= 12, "tutorial lists the controls")
	m.tutorial.close()
	check(not m.tutorial.visible and m._pause.visible and get_tree().paused, "closing returns to the pause menu")
	m.toggle_pause()
	check(not get_tree().paused, "resume after the pause-menu tutorial")
	# First-match flow: pauses, and closing unpauses + marks it as seen.
	m.show_tutorial(false)
	check(get_tree().paused and m.tutorial.visible, "first-match tutorial pauses the match")
	m.tutorial.close()
	await _frames(1)
	check(not get_tree().paused, "closing the first-match tutorial resumes the match")
	check(_settings.tutorial_seen, "tutorial_seen set after closing")
	cfg = ConfigFile.new()
	check(cfg.load(_settings.PATH) == OK and cfg.get_value("settings", "tutorial_seen", false) == true, "tutorial_seen=true persisted to disk")
	_settings.tutorial_seen = false
	_settings.load_settings()
	check(_settings.tutorial_seen, "tutorial_seen reloads from disk")
	# Touch vs keyboard text.
	m.tutorial.open(false)
	var kb_text: String = m.tutorial._footer.text
	m.tutorial.open(true)
	check(kb_text != m.tutorial._footer.text and m.tutorial._footer.text.begins_with("Toque"), "touch and keyboard variants differ")
	m.tutorial.close()
	m.queue_free()
	await _frames(2)
	get_tree().paused = false
	_settings.set_value("tutorial_seen", original)


# ------------------------------------------------------ offscreen in match

func _test_offscreen_in_match() -> void:
	print("[offscreen: in match]")
	var m := _new_match()
	await _frames(4)
	var me: Fighter = m.player_fighter()
	var foe: Fighter = m.teams[1].active_fighter()
	foe.position = me.position + Vector2(40, 0)
	m.camera.snap_to_target()
	await _frames(3)
	check(not m.offscreen.showing, "no marker while the enemy is on screen")
	foe.position = me.position + Vector2(700, 40)
	await _frames(3)
	var vs: Vector2 = m.offscreen.get_viewport_rect().size
	var mr := OffscreenIndicator.marker_rect(vs)
	check(m.offscreen.showing, "marker shown for an offscreen enemy")
	check(mr.grow(0.5).has_point(m.offscreen.marker_pos) and m.offscreen.marker_pos.x > vs.x * 0.5, "marker clamped to the right edge (%s)" % m.offscreen.marker_pos)
	foe.set_hidden("vanish", 1.0)
	await _frames(2)
	check(not m.offscreen.showing, "hidden (vanished) enemies are not revealed")
	m.queue_free()
	await _frames(2)
