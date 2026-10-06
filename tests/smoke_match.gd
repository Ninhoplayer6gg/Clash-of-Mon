extends SceneTree
## Headless smoke test: bot vs bot match, runs until someone wins or a
## time budget passes. Usage:
##   godot --headless --path . -s tests/smoke_match.gd -- pikachu lucario

var _match: Node
var _frames := 0
var _max_frames := 60 * 150
var _winner := -2


func _initialize() -> void:
	# Autoloads are added after _initialize: start on the first frame.
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	var a := args[0] if args.size() > 0 else "pikachu"
	var b := args[1] if args.size() > 1 else "lucario"
	var mode := args[2] if args.size() > 2 else "1v1"
	var game := root.get_node("/root/Game")
	var team_a: Array = a.split(",")
	var team_b: Array = b.split(",")
	var cfg: Dictionary = game.make_config(mode, team_a, team_b, args[3] if args.size() > 3 else "verdant_glade", false, {"bot_difficulty": 2})
	cfg["teams"][0]["controller"] = "bot"
	game.match_config = cfg
	_match = load("res://core/match.tscn").instantiate()
	root.add_child(_match)
	_match.match_ended.connect(func(w): _winner = w)
	print("SMOKE: %s vs %s (%s)" % [a, b, mode])


func _physics_process(_delta: float) -> bool:
	if _match == null:
		return false
	_frames += 1
	if _frames % 600 == 0:
		for l in _match.debug_lines():
			print("  ", l)
	if _winner != -2:
		print("SMOKE RESULT: winner=%d after %.1fs hits=%d" % [_winner, _frames / 60.0, _match.world.total_hits])
		for t in _match.teams:
			for f in t.fighters:
				print("  team%d %s hp=%d/%d dealt=%d taken=%d" % [t.index, f.species.name, f.hp, f.max_hp, f.damage_dealt, f.damage_taken])
		return true
	if _frames >= _max_frames:
		print("SMOKE RESULT: timeout hits=%d" % _match.world.total_hits)
		return true
	return false
