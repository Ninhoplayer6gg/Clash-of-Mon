extends SceneTree
## Renders a scene for N frames and saves screenshots (needs a display,
## e.g. xvfb-run). Usage:
##   godot --path . -s tests/screenshot.gd -- <scene|match> <out_prefix> [frames] [a] [b] [mode] [arena] [touch]

var _frames := 0
var _target := 120
var _out := "user://shot"
var _shots := []
var _node: Node


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	var what := args[0] if args.size() > 0 else "match"
	_out = args[1] if args.size() > 1 else "/tmp/shot"
	_target = int(args[2]) if args.size() > 2 else 120
	_shots = [_target / 4, _target / 2, _target * 3 / 4, _target]
	if what == "match":
		var game := root.get_node("/root/Game")
		var a: Array = (args[3] if args.size() > 3 else "pikachu").split(",")
		var b: Array = (args[4] if args.size() > 4 else "lucario").split(",")
		var cfg: Dictionary = game.make_config(args[5] if args.size() > 5 else "1v1", a, b, args[6] if args.size() > 6 else "verdant_glade", false, {})
		cfg["teams"][0]["controller"] = "bot"
		game.match_config = cfg
		if args.size() > 7:
			root.get_node("/root/Settings").touch_controls = args[7]
		if args.size() > 8 and args[8] == "debug":
			var st := root.get_node("/root/Settings")
			st.debug_overlay = true
			st.show_hitboxes = true
			st.apply()
			cfg["training"] = true
		_node = load("res://core/match.tscn").instantiate()
	else:
		_node = load(what).instantiate()
	root.add_child(_node)


func _process(_delta: float) -> bool:
	if _node == null:
		return false
	_frames += 1
	if _shots.has(_frames):
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [_out, _frames])
		print("saved %s_%d.png" % [_out, _frames])
	return _frames >= _target
