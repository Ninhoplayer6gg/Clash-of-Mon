extends Node
## Autoload "Audio": tiny procedural sound effects (synthesised at startup,
## no external audio assets) played through a fixed pool of players.

const MIX_RATE := 22050
const POOL_SIZE := 10
const CACHE_DIR := "user://sfx_cache_v1"

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	if DisplayServer.get_name() == "headless":
		return
	_build_sounds()


func play(id: String, _pos: Vector2 = Vector2.ZERO, volume_db: float = 0.0) -> void:
	var s: AudioStream = _streams.get(id)
	if s == null:
		return
	# Avoid stacking the same sound many times in one frame.
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -1000)) < 35:
		return
	_last_play[id] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db - 6.0
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _build_sounds() -> void:
	# Synthesis is cheap but not free on low-end phones: cache the results.
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var recipes := _recipes()
	for id in recipes.keys():
		var path := "%s/%s.res" % [CACHE_DIR, id]
		var cached: AudioStream = null
		if FileAccess.file_exists(path):
			cached = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cached == null:
			var r: Array = recipes[id]
			cached = callv("_synth", r)
			ResourceSaver.save(cached, path)
		_streams[id] = cached


func _recipes() -> Dictionary:
	return {
		"hit": [0.09, 220.0, 90.0, 0.55, 0.0],
		"hit_heavy": [0.2, 140.0, 50.0, 0.7, 0.0],
		"swing": [0.1, 0.0, 0.0, 0.0, 0.5, 2400.0],
		"spin": [0.25, 0.0, 0.0, 0.0, 0.35, 1600.0],
		"dash": [0.12, 0.0, 0.0, 0.0, 0.45, 3200.0],
		"zap": [0.08, 1400.0, 700.0, 0.3, 0.35, 0.0, true],
		"zap_big": [0.18, 900.0, 400.0, 0.35, 0.3, 0.0, true],
		"thunder": [0.35, 120.0, 40.0, 0.4, 0.7],
		"charge": [0.3, 200.0, 700.0, 0.35, 0.05],
		"fire": [0.3, 0.0, 0.0, 0.0, 0.55, 900.0],
		"water": [0.25, 0.0, 0.0, 0.0, 0.5, 1800.0],
		"blast": [0.3, 90.0, 40.0, 0.55, 0.6],
		"shadow": [0.25, 300.0, 120.0, 0.4, 0.15],
		"ko": [0.5, 500.0, 80.0, 0.5, 0.2],
		"ui": [0.05, 880.0, 880.0, 0.3, 0.0],
		"mega": [0.7, 300.0, 1200.0, 0.4, 0.1],
		"win": [0.5, 520.0, 1040.0, 0.35, 0.0],
		"lose": [0.5, 400.0, 160.0, 0.35, 0.0],
	}


## Builds a mono 16-bit sample: sine sweep (f0 -> f1) mixed with noise,
## optional low-pass-ish noise colouring and square-wave "buzz".
func _synth(length: float, f0: float, f1: float, tone_amp: float, noise_amp: float, noise_hp: float = 0.0, square: bool = false) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var prev_noise := 0.0
	var alpha := 1.0 if noise_hp <= 0.0 else clampf(noise_hp / MIX_RATE * 4.0, 0.02, 1.0)
	for i in n:
		var t := float(i) / n
		var env := (1.0 - t) * (1.0 - t)
		if i < 60:
			env *= i / 60.0
		var f := lerpf(f0, f1, t)
		phase += TAU * f / MIX_RATE
		var tone := sin(phase)
		if square:
			tone = 1.0 if tone > 0.0 else -1.0
		var nz := randf() * 2.0 - 1.0
		prev_noise = prev_noise + alpha * (nz - prev_noise)
		var v := (tone * tone_amp + prev_noise * noise_amp) * env
		var s := int(clampf(v, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
