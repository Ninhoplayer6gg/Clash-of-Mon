extends Node
## Drives the real player path: InputMap actions (keyboard/gamepad) and the
## touch controls (joystick + drag-to-aim skill button) on a player fighter.

var _fail := 0
var _pass := 0
var _match: Node
var _frames := 0
var _start_pos := Vector2.ZERO


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: ", label)


func _ready() -> void:
	var game := get_node("/root/Game")
	var cfg: Dictionary = game.make_config("1v1", ["pikachu"], ["blastoise"], "verdant_glade", true, {"bot_behavior": "idle"})
	game.match_config = cfg
	get_node("/root/Settings").touch_controls = "on"
	_match = load("res://core/match.tscn").instantiate()
	get_tree().root.add_child(_match)
	print("[input]")


func _physics_process(_d: float) -> void:
	_frames += 1
	var me: Fighter = _match.player_fighter()
	var controls: MobileControls = _match.controls
	match _frames:
		110:
			_start_pos = me.position
			Input.action_press("move_right")
		150:
			Input.action_release("move_right")
			check(me.position.x > _start_pos.x + 40.0, "keyboard move_right moves the fighter (%.0f px)" % (me.position.x - _start_pos.x))
			check(me.facing.x > 0.9, "facing follows movement")
			Input.action_press("basic")
		152:
			Input.action_release("basic")
		160:
			check(me.cooldowns["basic"] > 0.0 or me.state == Fighter.State.CASTING, "basic attack from InputMap")
			Input.action_press("dash")
		162:
			Input.action_release("dash")
			check(me.state == Fighter.State.DASHING or me.dash_cd > 0.0, "dash from InputMap")
		200:
			# Touch: joystick drag on the left half moves the fighter.
			_start_pos = me.position
			var vs := controls.get_viewport_rect().size
			controls._touch_down(1, Vector2(200, vs.y - 160))
			controls._touch_move(1, Vector2(200, vs.y - 230))
		240:
			check(me.position.y < _start_pos.y - 30.0, "virtual joystick moves the fighter up (%.0f px)" % (_start_pos.y - me.position.y))
			controls._touch_up(1, Vector2(200, 0))
			# Touch: drag skill1 button to aim left, release to cast.
			var b: Dictionary = controls._buttons[1]
			controls._touch_down(2, b["center"])
			controls._touch_move(2, b["center"] + Vector2(-80, 0))
		242:
			check(_match.ground_fx.aim_active, "drag on skill button shows aim preview")
			check(_match.ground_fx.aim_dir.x < -0.9, "aim preview points where the thumb drags")
			var b: Dictionary = controls._buttons[1]
			controls._touch_up(2, b["center"] + Vector2(-80, 0))
		246:
			check(me.cooldowns["skill1"] > 0.0, "released drag casts the skill")
			check(me.aim_dir.x < -0.9, "skill cast in the dragged direction")
			check(not _match.ground_fx.aim_active, "aim preview hidden after release")
			# Drag out and back to the centre cancels.
			var b2: Dictionary = controls._buttons[2]
			controls._touch_down(3, b2["center"])
			controls._touch_move(3, b2["center"] + Vector2(60, 0))
			controls._touch_move(3, b2["center"])
			controls._touch_up(3, b2["center"])
		250:
			check(me.cooldowns["skill2"] <= 0.0, "drag back to centre cancels the skill")
			# Tap = quick cast with auto aim toward the enemy.
			var b3: Dictionary = controls._buttons[3]
			controls._touch_down(4, b3["center"])
			controls._touch_up(4, b3["center"])
		254:
			check(me.cooldowns["skill3"] > 0.0, "tap quick-casts skill3")
		300:
			me.ult_charge = 100.0
			Input.action_press("ult")
		302:
			Input.action_release("ult")
		310:
			check(me.ult_charge < 100.0, "ultimate cast from InputMap consumes charge")
			_match.toggle_pause()
			check(get_tree().paused and _match._pause.visible, "pause opens the pause menu")
			_match.toggle_pause()
			check(not get_tree().paused, "unpause")
			print("INPUT TESTS: %d passed, %d failed" % [_pass, _fail])
			set_physics_process(false)
			_match.queue_free()
			await get_tree().process_frame
			get_tree().quit(_fail)
