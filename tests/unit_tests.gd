extends SceneTree
## Runs tests/unit_suite.gd after autoloads are ready.
##   godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd


func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tests/unit_suite.gd").new()), CONNECT_ONE_SHOT)
