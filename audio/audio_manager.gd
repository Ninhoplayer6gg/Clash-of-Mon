extends Node
## Autoload "Audio": tiny procedural sound effects (synthesised at startup,
## no external audio assets) played through a fixed pool of players.

const MIX_RATE := 22050
const POOL_SIZE := 10
const CACHE_DIR := "user://sfx_cache_v2"

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}
var _hit_ids := {}  # move type -> "hit_<type>" (no string building per hit)


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
	for t in RICH_TYPES:
		_hit_ids[t] = "hit_" + t


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
		# The recipe hash in the name refreshes a sound whenever it changes.
		var path := "%s/%s_%x.res" % [CACHE_DIR, id, str(recipes[id]).hash()]
		var cached: AudioStream = null
		if FileAccess.file_exists(path):
			cached = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cached == null:
			var r = recipes[id]
			cached = _synth_rich(r) if r is Dictionary else callv("_synth", r)
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
		"ui": {"len": 0.06, "f0": 1320.0, "f1": 990.0, "wave": "tri", "tone": 0.32, "curve": 3.0},
		"mega": [0.7, 300.0, 1200.0, 0.4, 0.1],
		# v0.2 polish: jingles, KO, cast whoosh, UI and per-type hit variants.
		"win": {"notes": [[523.25, 0.11], [659.25, 0.11], [783.99, 0.11], [1046.5, 0.42]], "wave": "square", "tone": 0.2, "harm": 0.3},
		"lose": {"notes": [[392.0, 0.16], [311.13, 0.16], [261.63, 0.5]], "wave": "tri", "tone": 0.38, "vib": 0.012, "vib_rate": 6.0},
		"ko_big": {"len": 0.65, "f0": 420.0, "f1": 55.0, "wave": "saw", "tone": 0.3, "noise": 0.45, "lp": 0.12, "curve": 1.4},
		"cast": {"len": 0.16, "noise": 0.5, "lp": 0.5, "hp": true, "sweep": 0.8, "curve": 1.6, "attack": 0.04},
		"ui_back": {"len": 0.07, "f0": 880.0, "f1": 660.0, "wave": "tri", "tone": 0.3, "curve": 3.0},
		"hit_normal": {"len": 0.09, "f0": 210.0, "f1": 90.0, "tone": 0.55, "noise": 0.25, "lp": 0.3},
		"hit_fire": {"len": 0.14, "f0": 160.0, "f1": 80.0, "tone": 0.3, "noise": 0.5, "lp": 0.25, "crackle": 0.02},
		"hit_water": {"len": 0.12, "f0": 620.0, "f1": 180.0, "tone": 0.45, "noise": 0.3, "lp": 0.15, "curve": 2.5},
		"hit_electric": {"len": 0.1, "f0": 1200.0, "f1": 500.0, "wave": "square", "tone": 0.22, "noise": 0.3, "lp": 0.8},
		"hit_grass": {"len": 0.1, "f0": 900.0, "f1": 600.0, "tone": 0.2, "noise": 0.4, "lp": 0.6, "hp": true},
		"hit_ice": {"len": 0.12, "f0": 1800.0, "f1": 1500.0, "tone": 0.3, "harm": 0.5, "noise": 0.15, "lp": 0.9, "hp": true, "curve": 2.5},
		"hit_fighting": {"len": 0.1, "f0": 150.0, "f1": 55.0, "tone": 0.7, "noise": 0.35, "lp": 0.4, "curve": 2.2},
		"hit_poison": {"len": 0.14, "f0": 320.0, "f1": 220.0, "tone": 0.45, "vib": 0.25, "vib_rate": 40.0, "noise": 0.15, "lp": 0.2},
		"hit_ground": {"len": 0.16, "f0": 95.0, "f1": 45.0, "tone": 0.55, "noise": 0.5, "lp": 0.06},
		"hit_flying": {"len": 0.13, "noise": 0.55, "lp": 0.55, "hp": true, "sweep": -0.6, "tone": 0.1, "f0": 500.0, "f1": 300.0},
		"hit_psychic": {"len": 0.15, "f0": 700.0, "f1": 1150.0, "tone": 0.35, "vib": 0.06, "vib_rate": 22.0, "noise": 0.08, "lp": 0.3},
		"hit_bug": {"len": 0.1, "f0": 420.0, "f1": 380.0, "wave": "saw", "tone": 0.18, "noise": 0.25, "lp": 0.5, "vib": 0.1, "vib_rate": 60.0},
		"hit_rock": {"len": 0.14, "f0": 120.0, "f1": 70.0, "tone": 0.4, "noise": 0.55, "lp": 0.15, "crackle": 0.03},
		"hit_ghost": {"len": 0.18, "f0": 420.0, "f1": 210.0, "tone": 0.4, "vib": 0.08, "vib_rate": 9.0, "noise": 0.1, "lp": 0.1},
		"hit_dragon": {"len": 0.15, "f0": 170.0, "f1": 85.0, "wave": "saw", "tone": 0.3, "noise": 0.35, "lp": 0.2},
		"hit_dark": {"len": 0.12, "f0": 180.0, "f1": 75.0, "tone": 0.5, "noise": 0.35, "lp": 0.08},
		"hit_steel": {"len": 0.16, "f0": 1320.0, "f1": 1250.0, "tone": 0.3, "harm": 0.7, "harm_ratio": 1.47, "noise": 0.2, "lp": 0.7, "curve": 2.6},
		"hit_fairy": {"len": 0.15, "f0": 1500.0, "f1": 2100.0, "wave": "tri", "tone": 0.3, "vib": 0.03, "vib_rate": 18.0, "noise": 0.05, "lp": 0.5},
	}


## v0.2 polish: move types with their own hit sound.
const RICH_TYPES := [
	"normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground",
	"flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy",
]


## Hit sound for a move type ("hit" when the type has no variant), with the
## heavy thump layered underneath for big hits.
func play_hit(move_type: String, heavy: bool, pos: Vector2 = Vector2.ZERO) -> void:
	if heavy:
		play("hit_heavy", pos)
	var id: String = _hit_ids.get(move_type, "")
	if id != "" and _streams.has(id):
		play(id, pos, -3.0 if heavy else 0.0)
	elif not heavy:
		play("hit", pos)


## Richer synthesis from a recipe dictionary:
##  len, f0/f1 (sweep), wave sine|square|tri|saw, tone, harm (+harm_ratio),
##  vib/vib_rate (relative vibrato), noise, lp (0..1 smoothing), hp (high
##  pass), sweep (noise filter sweep), crackle (impulse probability),
##  attack, curve (decay exponent) and notes [[freq, dur], ...] (jingles).
func _synth_rich(r: Dictionary) -> AudioStreamWAV:
	var notes: Array = r.get("notes", [])
	var length := float(r.get("len", 0.1))
	if not notes.is_empty():
		length = 0.0
		for nt in notes:
			length += float(nt[1])
	var n := int(length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f0 := float(r.get("f0", 440.0))
	var f1 := float(r.get("f1", f0))
	var wave := String(r.get("wave", "sine"))
	var tone_amp := float(r.get("tone", 0.0))
	var harm := float(r.get("harm", 0.0))
	var harm_ratio := float(r.get("harm_ratio", 2.0))
	var vib := float(r.get("vib", 0.0))
	var vib_rate := float(r.get("vib_rate", 6.0))
	var noise_amp := float(r.get("noise", 0.0))
	var lp := clampf(float(r.get("lp", 1.0)), 0.01, 1.0)
	var hp := bool(r.get("hp", false))
	var sweep := float(r.get("sweep", 0.0))
	var crackle := float(r.get("crackle", 0.0))
	var attack := maxf(float(r.get("attack", 0.003)), 0.001)
	var curve := float(r.get("curve", 2.0))
	var phase := 0.0
	var phase2 := 0.0
	var low := 0.0
	var note_i := 0
	var note_start := 0.0
	var note_len := float(notes[0][1]) if not notes.is_empty() else length
	for i in n:
		var time := float(i) / MIX_RATE
		var t := time / length
		var env := pow(1.0 - t, curve) * minf(1.0, time / attack)
		var f := lerpf(f0, f1, t)
		if not notes.is_empty():
			while note_i < notes.size() - 1 and time >= note_start + note_len:
				note_start += note_len
				note_i += 1
				note_len = float(notes[note_i][1])
			var nt := (time - note_start) / note_len
			f = float(notes[note_i][0])
			# Each note gets its own pluck envelope; the last one rings out.
			env = minf(1.0, (time - note_start) / 0.006) * pow(1.0 - nt, 1.2 if note_i == notes.size() - 1 else 0.6)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * vib_rate * time)
		phase = fmod(phase + f / MIX_RATE, 1.0)
		phase2 = fmod(phase2 + f * harm_ratio / MIX_RATE, 1.0)
		var tone := 0.0
		match wave:
			"square":
				tone = 1.0 if phase < 0.5 else -1.0
			"tri":
				tone = 4.0 * absf(phase - 0.5) - 1.0
			"saw":
				tone = 2.0 * phase - 1.0
			_:
				tone = sin(TAU * phase)
		tone += harm * sin(TAU * phase2)
		var v := tone * tone_amp
		if noise_amp > 0.0:
			var a := clampf(lp * (1.0 + sweep * (t - 0.5) * 2.0), 0.01, 1.0)
			var nz := randf() * 2.0 - 1.0
			low += a * (nz - low)
			var col := nz - low if hp else low
			if crackle > 0.0 and randf() < crackle:
				col += randf_range(-1.0, 1.0) * 2.0
			v += col * noise_amp
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


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
