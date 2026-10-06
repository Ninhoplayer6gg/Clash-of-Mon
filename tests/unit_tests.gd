extends SceneTree
## Runs a test suite Node after autoloads are ready.
##   godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd [-- res://tests/input_suite.gd]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var suite := args[0] if args.size() > 0 else "res://tests/unit_suite.gd"
	process_frame.connect(func(): root.add_child(load(suite).new()), CONNECT_ONE_SHOT)
