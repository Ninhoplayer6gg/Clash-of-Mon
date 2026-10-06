extends Node
## Autoload "InputActions": registers the default keyboard and gamepad
## bindings at startup (kept in code so they are easy to read and rebind).

const DEADZONE := 0.2

## action -> list of bindings. "k:" key, "m:" mouse button, "jb:" joypad
## button, "ja:" joypad axis "<axis>:<sign>".
const BINDINGS := {
	"move_left": ["k:A", "k:Left", "ja:0:-1"],
	"move_right": ["k:D", "k:Right", "ja:0:1"],
	"move_up": ["k:W", "k:Up", "ja:1:-1"],
	"move_down": ["k:S", "k:Down", "ja:1:1"],
	"aim_left": ["ja:2:-1"],
	"aim_right": ["ja:2:1"],
	"aim_up": ["ja:3:-1"],
	"aim_down": ["ja:3:1"],
	"basic": ["k:J", "jb:0", "ja:5:1"],
	"skill1": ["k:K", "k:1", "jb:2"],
	"skill2": ["k:L", "k:2", "jb:3"],
	"skill3": ["k:U", "k:3", "jb:1"],
	"ult": ["k:I", "k:R", "k:4", "jb:10"],
	"dash": ["k:Space", "k:Shift", "jb:9", "ja:4:1"],
	"mega": ["k:M", "jb:7"],
	"switch_prev": ["k:Q", "jb:13"],
	"switch_next": ["k:E", "jb:14"],
	"pause": ["k:Escape", "k:P", "jb:6"],
	"debug_toggle": ["k:F3"],
	"hitbox_toggle": ["k:F4"],
}

const SKILL_ACTIONS := ["basic", "skill1", "skill2", "skill3", "ult"]


func _ready() -> void:
	for action in BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for b in BINDINGS[action]:
			var ev := _make_event(b)
			if ev:
				InputMap.action_add_event(action, ev)


func _make_event(spec: String) -> InputEvent:
	var parts := spec.split(":")
	match parts[0]:
		"k":
			var e := InputEventKey.new()
			e.physical_keycode = OS.find_keycode_from_string(parts[1])
			return e
		"m":
			var e := InputEventMouseButton.new()
			e.button_index = int(parts[1]) as MouseButton
			return e
		"jb":
			var e := InputEventJoypadButton.new()
			e.button_index = int(parts[1]) as JoyButton
			return e
		"ja":
			var e := InputEventJoypadMotion.new()
			e.axis = int(parts[1]) as JoyAxis
			e.axis_value = float(parts[2])
			return e
	return null
