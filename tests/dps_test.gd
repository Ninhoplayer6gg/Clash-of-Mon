extends SceneTree
## Each Pokémon (bot, active) attacks an idle dummy for N seconds.
## Reports damage and casts per slot. Usage:
##   godot --headless --fixed-fps 60 --path . -s tests/dps_test.gd -- [seconds] [dummy]

var _ids: Array = []
var _i := 0
var _match: Node
var _frames := 0
var _secs := 15.0
var _dummy := "blastoise"
var _casts := {}


func _initialize() -> void:
	process_frame.connect(_setup, CONNECT_ONE_SHOT)


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_secs = float(args[0])
	if args.size() > 1:
		_dummy = args[1]
	_ids = root.get_node("/root/GameData").roster.duplicate()
	_next()


func _next() -> void:
	if _match:
		_match.queue_free()
	if _i >= _ids.size():
		quit()
		return
	var id: String = _ids[_i]
	_i += 1
	var game := root.get_node("/root/Game")
	var cfg: Dictionary = game.make_config("1v1", [id], [_dummy], "verdant_glade", true, {"bot_difficulty": 2})
	cfg["teams"][0]["controller"] = "bot"
	cfg["teams"][0]["behavior"] = "active"
	cfg["teams"][1]["behavior"] = "idle"
	game.match_config = cfg
	_match = load("res://core/match.tscn").instantiate()
	root.add_child(_match)
	_frames = 0
	_casts = {}
	var f = _match.teams[0].fighters[0]
	f.cast_started.connect(func(_f, slot): _casts[slot] = _casts.get(slot, 0) + 1)
	var fails := {}
	f.cast_failed.connect(func(_f, slot, why): fails[slot + ":" + why] = fails.get(slot + ":" + why, 0) + 1)
	f.set_meta("fails", fails)


func _physics_process(_d: float) -> bool:
	if _match == null:
		return false
	_frames += 1
	if _frames >= int(_secs * 60.0):
		var f = _match.teams[0].fighters[0]
		var t = _match.teams[1].fighters[0]
		print("%-10s dealt %5d in %.0fs (%.0f dps) | target hp %d%% | casts %s | fails %s | dist %.0f | bot %s" % [f.species.id, f.damage_dealt, _secs, f.damage_dealt / _secs, int(t.hp_ratio() * 100), str(_casts), str(f.get_meta("fails")), f.position.distance_to(t.position), str(_match.bots[0].stats)])
		_next()
	return false
