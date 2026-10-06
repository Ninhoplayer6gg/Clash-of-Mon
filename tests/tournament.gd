extends SceneTree
## Bot vs bot round robin for balance checks. Run with:
##   godot --headless --fixed-fps 60 --path . -s tests/tournament.gd -- [rounds] [difficulty] [arena]

var _pairs: Array = []
var _idx := 0
var _round := 0
var _rounds := 2
var _difficulty := 2
var _arena := "verdant_glade"
var _match: Node
var _frames := 0
var _winner := -2
var _results := {}  # id -> [wins, losses, draws]
var _durations: Array = []
var _log: PackedStringArray = []


func _initialize() -> void:
	process_frame.connect(_setup, CONNECT_ONE_SHOT)


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_rounds = int(args[0])
	if args.size() > 1:
		_difficulty = int(args[1])
	if args.size() > 2:
		_arena = args[2]
	var gd := root.get_node("/root/GameData")
	var roster: Array = gd.roster
	for a in roster:
		_results[a] = [0, 0, 0]
	for i in roster.size():
		for j in roster.size():
			if i != j:
				_pairs.append([roster[i], roster[j]])
	_next()


func _next() -> void:
	if _match:
		_match.queue_free()
		_match = null
	if _idx >= _pairs.size():
		_idx = 0
		_round += 1
		if _round >= _rounds:
			_report()
			quit()
			return
	var p: Array = _pairs[_idx]
	_idx += 1
	var game := root.get_node("/root/Game")
	var cfg: Dictionary = game.make_config("1v1", [p[0]], [p[1]], _arena, false, {"bot_difficulty": _difficulty})
	cfg["teams"][0]["controller"] = "bot"
	game.match_config = cfg
	_match = load("res://core/match.tscn").instantiate()
	root.add_child(_match)
	_match.match_ended.connect(func(w): _winner = w)
	_frames = 0
	_winner = -2


func _physics_process(_delta: float) -> bool:
	if _match == null:
		return false
	_frames += 1
	if _winner != -2 or _frames > 60 * 130:
		var p: Array = _pairs[_idx - 1]
		var t := _frames / 60.0
		var w := _winner
		if w == 0:
			_results[p[0]][0] += 1
			_results[p[1]][1] += 1
		elif w == 1:
			_results[p[1]][0] += 1
			_results[p[0]][1] += 1
		else:
			_results[p[0]][2] += 1
			_results[p[1]][2] += 1
		_durations.append(t)
		var f0 = _match.teams[0].fighters[0]
		var f1 = _match.teams[1].fighters[0]
		_log.append("%-10s vs %-10s -> %s  %.1fs  hp %d%% / %d%%  dealt %d / %d" % [p[0], p[1], (p[0] if w == 0 else (p[1] if w == 1 else "draw")), t, int(f0.hp_ratio() * 100), int(f1.hp_ratio() * 100), f0.damage_dealt, f1.damage_dealt])
		_next()
	return false


func _report() -> void:
	for l in _log:
		print(l)
	print("---- standings ----")
	for id in _results.keys():
		var r: Array = _results[id]
		print("%-10s W %2d  L %2d  D %2d" % [id, r[0], r[1], r[2]])
	var avg := 0.0
	for d in _durations:
		avg += d
	print("avg duration %.1fs over %d matches" % [avg / maxf(_durations.size(), 1), _durations.size()])
