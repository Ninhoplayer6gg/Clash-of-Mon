class_name SkillIcons
extends RefCounted
## Procedural vector skill icons (no image assets).
##
## The shape of an ability is INFERRED from its data: id/name keywords,
## action types ("do"), projectile/zone vfx styles and move type. An
## ability may force a shape with the optional "icon_shape" key. Inside a
## kit (one form), shapes are assigned greedily so two buttons of the same
## Pokémon rarely share an icon. Unknown action types or move types simply
## add no hint, so any future ability still gets a valid shape.
##
## Shapes are defined once in a unit box (-1..1, y down), cached as packed
## arrays and drawn with a transform: drawing every frame allocates nothing.

## Every drawable shape. The order is also the tie-break order.
const SHAPES := [
	"bolt", "flame", "droplet", "leaf", "snowflake", "claw", "fist", "fang",
	"bone", "orb", "comet", "beam", "wave", "quake", "storm", "drill", "spin",
	"wing", "dash", "swirl", "ghost", "eye", "bubble", "rock", "shield",
	"heart", "up_arrow", "shuriken", "sparkle", "burst", "star",
]
## Help/tutorial shapes; never inferred for abilities.
const UI_SHAPES := ["joystick", "tap", "drag", "dodge"]
const FALLBACK := "star"

## Move type -> shape used as a weak hint (and for type-only abilities).
const TYPE_SHAPES := {
	"normal": "star", "fire": "flame", "water": "droplet", "electric": "bolt",
	"grass": "leaf", "ice": "snowflake", "fighting": "fist", "poison": "bubble",
	"ground": "quake", "flying": "wing", "psychic": "eye", "bug": "shuriken",
	"rock": "rock", "ghost": "ghost", "dragon": "fang", "dark": "claw",
	"steel": "shield", "fairy": "sparkle",
}

## Strong name keywords (weight 4): they describe the gesture of the move.
const SPECIFIC_WORDS := {
	"claw": ["claw", "slash", "scratch", "cut", "scissor", "blade", "sword", "slice", "swipe", "talon", "rend"],
	"fist": ["punch", "fist", "combo", "chop", "jab", "mach", "uppercut", "knuckle", "hammer", "kick", "karate", "brick", "strike"],
	"fang": ["bite", "crunch", "fang", "chomp", "jaw"],
	"bone": ["bone"],
	"orb": ["ball", "sphere", "orb", "bomb", "globe", "bullet"],
	"comet": ["meteor", "comet", "draco"],
	"beam": ["beam", "ray", "laser", "cannon"],
	"wave": ["pump", "wave", "pulse", "surf", "roar", "scream", "howl", "sing", "sound", "voice", "echo"],
	"quake": ["quake", "bulldoze", "stomp", "magnitude", "tremor", "fissure", "earthquake", "stamp"],
	"storm": ["thunder", "storm", "weather", "rain", "hail", "cloud"],
	"drill": ["dig", "drill", "burrow", "tunnel"],
	"spin": ["spin", "rapid", "whirl", "tornado", "twister", "cyclone", "gyro", "roll", "wheel"],
	"wing": ["wing", "fly", "air", "gust", "hurricane", "feather", "bird", "aerial", "sky", "flap"],
	"dash": ["quick", "speed", "extreme", "rush", "dash", "agility", "tackle", "sprint", "zoom", "charge"],
	"swirl": ["teleport", "blink", "warp", "portal", "vortex", "swirl", "whirlpool", "vanish"],
	"eye": ["hypno", "sleep", "confus", "glare", "stare", "leer", "mind", "gaze", "eye", "dream", "lullaby"],
	"rock": ["rock", "stone", "boulder", "slide", "edge", "pebble", "gem"],
	"shield": ["protect", "shield", "barrier", "withdraw", "harden", "defen", "guard", "detect", "wall", "reflect", "armor", "shell"],
	"heart": ["heal", "recover", "rest", "synthesis", "roost", "wish", "moonlight", "life", "regen", "kiss"],
	"up_arrow": ["dance", "bulk", "plot", "calm", "boost", "growth", "sharpen", "hone", "work", "power"],
	"shuriken": ["shuriken", "cutter", "disc", "disk"],
	"star": ["swift", "star"],
	"sparkle": ["dazzl", "sparkl", "glitter", "twinkle", "sweet"],
	"burst": ["palm", "blast", "explosion", "eruption", "nova", "boom", "burst", "impact", "smash", "outrage", "rampage", "thrash"],
	"bubble": ["bubble"],
	"flame": ["flamethrower"],
}

## Elemental name keywords (weight 2).
const ELEMENT_WORDS := {
	"bolt": ["shock", "bolt", "volt", "zap", "spark", "electr", "discharge"],
	"flame": ["fire", "flame", "ember", "blaze", "burn", "heat", "inferno", "scorch", "lava", "magma"],
	"droplet": ["water", "hydro", "aqua", "splash", "drip", "drop"],
	"leaf": ["leaf", "grass", "seed", "vine", "petal", "solar", "razor", "wood", "bloom", "flower", "drain", "absorb"],
	"snowflake": ["ice", "icy", "frost", "freez", "snow", "blizzard", "cold", "chill", "glacia", "aurora"],
	"ghost": ["shadow", "ghost", "spirit", "curse", "hex", "haunt", "phantom", "night", "spite"],
	"fang": ["dragon"],
	"bubble": ["poison", "sludge", "toxic", "acid", "venom", "smog", "gunk"],
	"quake": ["ground", "earth", "mud", "sand"],
	"eye": ["psychic", "psy"],
	"sparkle": ["fairy", "moon", "charm"],
	"shield": ["steel", "iron", "metal"],
	"swirl": ["aura"],
}

## vfx "style" -> shape (weak hint, weight 1). "*" = element of the move.
const STYLE_SHAPES := {
	"bolt": "bolt", "fire": "flame", "water": "droplet", "bone": "bone",
	"wave": "wave", "spin": "spin", "slash": "claw", "beam": "beam",
	"burst": "burst", "cone": "*", "ring": "wave", "orb": "orb",
	"thrust": "drill", "ground": "*",
}

## Which action of a timeline best describes the ability.
const ACTION_RANK := {
	"beam": 9, "projectile": 8, "aoe": 7, "melee": 6, "zone": 5, "burrow": 4,
	"leap": 4, "teleport": 4, "vanish": 3, "dash": 2, "heal": 2, "buff": 1,
	"cleanse": 1,
}
const SLOT_ORDER := ["ult", "skill1", "skill2", "skill3", "basic"]
const META_KEY := "_skill_icon_shape"

enum Op { POLY, LINE, CIRCLE }
enum Tone { MAIN, LIGHT, DARK }

static var _ops := {}  # shape -> Array of ops (built lazily, kept forever)


# ------------------------------------------------------------- inference

static func is_valid_shape(shape: String) -> bool:
	return SHAPES.has(shape) or UI_SHAPES.has(shape)


## Shape for one ability, cached on the ability. Pass the form it belongs
## to so the whole kit is resolved together (distinct icons per button).
static func shape_for(ab: AbilityDef, form: FormDef = null) -> String:
	if ab == null:
		return FALLBACK
	if ab.has_meta(META_KEY):
		return String(ab.get_meta(META_KEY))
	if form != null:
		prepare_form(form)
		if ab.has_meta(META_KEY):
			return String(ab.get_meta(META_KEY))
	var s := infer(ab)
	ab.set_meta(META_KEY, s)
	return s


## Resolves and caches the icons of every ability of a form.
static func prepare_form(form: FormDef) -> void:
	if form == null:
		return
	var kit := assign_kit(form.abilities)
	for slot in kit.keys():
		var ab: AbilityDef = form.abilities[slot]
		ab.set_meta(META_KEY, kit[slot])


## Best single shape for an ability (ignores the rest of the kit).
static func infer(ab: AbilityDef) -> String:
	if ab == null:
		return FALLBACK
	return infer_from_dict(ab.raw, ab.move_type, ab.id, ab.name)


## Same as infer() but straight from an ability dictionary (JSON data).
static func infer_from_dict(d: Dictionary, move_type: String = "", id: String = "", display_name: String = "") -> String:
	var forced := str(d.get("icon_shape", ""))
	if is_valid_shape(forced):
		return forced
	var scores := score_dict(d, move_type, id, display_name)
	return _best(scores, {})


## Greedy assignment of distinct shapes inside a kit: slot -> shape.
static func assign_kit(abilities: Dictionary) -> Dictionary:
	var out := {}
	var used := {}
	var candidates: Array = []  # [score, slot_rank, shape_rank, slot, shape]
	var slots: Array = abilities.keys()
	for slot in slots:
		var ab: AbilityDef = abilities[slot]
		if ab == null:
			continue
		var forced := str(ab.raw.get("icon_shape", ""))
		if is_valid_shape(forced):
			out[slot] = forced
			used[forced] = true
			continue
		var scores := score_dict(ab.raw, ab.move_type, ab.id, ab.name)
		var srank := SLOT_ORDER.find(slot)
		if srank < 0:
			srank = SLOT_ORDER.size()
		for shape in scores.keys():
			candidates.append([float(scores[shape]), srank, SHAPES.find(shape), slot, shape])
	candidates.sort_custom(_candidate_before)
	for c in candidates:
		var slot: String = c[3]
		var shape: String = c[4]
		if out.has(slot) or used.has(shape):
			continue
		out[slot] = shape
		used[shape] = true
	# Every candidate taken by a sibling: fall back to the best one anyway.
	for slot in slots:
		if not out.has(slot) and abilities[slot] != null:
			out[slot] = infer(abilities[slot])
	return out


static func _candidate_before(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]


## Shape -> score from every hint found in the ability data.
static func score_dict(d: Dictionary, move_type: String = "", id: String = "", display_name: String = "") -> Dictionary:
	var scores := {}
	var mt := move_type if move_type != "" else str(d.get("type", "normal"))
	var element: String = TYPE_SHAPES.get(mt, "")
	# 1) keywords in id + name
	var words := _words("%s %s" % [id if id != "" else str(d.get("id", "")), display_name if display_name != "" else str(d.get("name", ""))])
	var kw := {}
	_collect_keywords(kw, words, SPECIFIC_WORDS, 4.0)
	_collect_keywords(kw, words, ELEMENT_WORDS, 2.0)
	for shape in kw.keys():
		_add(scores, shape, float(kw[shape]))
	# 2) actions (main timeline or the first combo stage)
	var actions: Array = d.get("actions", [])
	var combo: Array = d.get("combo", [])
	if actions.is_empty() and not combo.is_empty() and combo[0] is Dictionary:
		actions = combo[0].get("actions", [])
	var best_rank := -1
	var primary: Dictionary = {}
	for a in actions:
		if not a is Dictionary:
			continue
		var rank := int(ACTION_RANK.get(str(a.get("do", "")), -1))
		if rank > best_rank:
			best_rank = rank
			primary = a
	var action_scores := {}
	for a in actions:
		if not a is Dictionary:
			continue
		var cue := _action_cue(a, element)
		if cue == "":
			continue
		var w := 3.0 if a == primary else 2.0
		action_scores[cue] = maxf(float(action_scores.get(cue, 0.0)), w)
		var style := _style_of(a)
		if style != "":
			var st: String = STYLE_SHAPES.get(style, "")
			if st == "*":
				st = element
			if st != "":
				action_scores["~" + st] = 1.0
	for k in action_scores.keys():
		var shape: String = k.trim_prefix("~")
		_add(scores, shape, float(action_scores[k]))
	# 3) move type
	if element != "":
		_add(scores, element, 1.0)
	# 4) generic fallbacks so there is always something left to pick
	_add(scores, FALLBACK, 0.2)
	_add(scores, "burst", 0.15)
	_add(scores, "orb", 0.1)
	return scores


static func _add(scores: Dictionary, shape: String, w: float) -> void:
	if not SHAPES.has(shape):
		return
	scores[shape] = float(scores.get(shape, 0.0)) + w


## Keywords of one table: shape -> max weight (tables never stack).
static func _collect_keywords(kw: Dictionary, words: PackedStringArray, table: Dictionary, w: float) -> void:
	for shape in table.keys():
		for k in table[shape]:
			if _matches(words, k):
				kw[shape] = maxf(float(kw.get(shape, 0.0)), w)
				break


static func _matches(words: PackedStringArray, kw: String) -> bool:
	for w in words:
		if w.begins_with(kw) or (kw.length() >= 4 and w.ends_with(kw)):
			return true
	return false


static func _words(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			cur += ch
		elif cur != "":
			out.append(cur)
			cur = ""
	if cur != "":
		out.append(cur)
	return out


static func _style_of(a: Dictionary) -> String:
	var v = a.get("vfx")
	if v is Dictionary:
		return str(v.get("style", ""))
	return ""


## Shape suggested by one timeline action ("" when it says nothing).
static func _action_cue(a: Dictionary, element: String) -> String:
	var style := _style_of(a)
	match str(a.get("do", "")):
		"projectile":
			if a.has("explode"):
				return "comet"
			match style:
				"bolt": return "bolt"
				"fire": return "flame"
				"water": return "droplet"
				"bone": return "bone"
				"wave": return "wave"
			return "orb"
		"melee":
			match style:
				"spin": return "spin"
				"cone": return element if element != "" else "wave"
				"burst": return "burst"
				"thrust": return "drill"
			match str(a.get("shape", "circle")):
				"sector", "cone", "arc":
					return "fist" if element == "fist" else "claw"
				"line":
					return "beam"
			return "burst"
		"aoe":
			if style == "bolt":
				return "storm"
			if style == "ring":
				return "quake" if element == "quake" or element == "rock" else "wave"
			return "burst"
		"beam":
			return "beam"
		"zone":
			return element if element != "" else "burst"
		"dash":
			return "dash"
		"leap":
			return "wing"
		"burrow":
			return "drill"
		"teleport":
			return "swirl"
		"vanish":
			return "ghost"
		"buff":
			var mods: Dictionary = a.get("mods", {}) if a.get("mods") is Dictionary else {}
			if mods.has("armor") or mods.has("super_armor") or mods.has("defense"):
				return "shield"
			return "up_arrow"
		"heal":
			return "heart"
		"cleanse":
			return "sparkle"
	return ""


static func _best(scores: Dictionary, used: Dictionary) -> String:
	var best := FALLBACK
	var best_score := -1.0
	var best_rank := 999
	for shape in scores.keys():
		if used.has(shape):
			continue
		var s := float(scores[shape])
		var r := SHAPES.find(shape)
		if s > best_score or (s == best_score and r < best_rank):
			best = shape
			best_score = s
			best_rank = r
	return best


# ---------------------------------------------------------------- colours

## Type colour adjusted to stay readable on dark buttons.
static func icon_color(move_type: String) -> Color:
	return readable(GameData.type_color(move_type))


static func readable(c: Color) -> Color:
	var lum := c.get_luminance()
	if lum < 0.5:
		c = c.lerp(Color.WHITE, clampf((0.5 - lum) * 1.3, 0.0, 0.6))
	return c


# ---------------------------------------------------------------- drawing

## Draws `shape` centred at `center`, `size` pixels wide, tinted with
## `col`. Leaves the canvas transform reset to identity.
static func draw_icon(ci: CanvasItem, shape: String, center: Vector2, size: float, col: Color, outline: bool = true) -> void:
	var ops := _get_ops(shape)
	var half := size * 0.5
	var light := col.lerp(Color(1, 1, 1, col.a), 0.62)
	var dark := Color(col.darkened(0.62), col.a)
	if outline:
		var oc := Color(0.02, 0.03, 0.05, 0.8 * col.a)
		ci.draw_set_transform(center + Vector2(0, size * 0.035), 0.0, Vector2(half, half))
		for op in ops:
			match op[0]:
				Op.POLY:
					ci.draw_polyline(op[3], oc, 0.2)
					ci.draw_colored_polygon(op[2], oc)
				Op.LINE:
					ci.draw_polyline(op[2], oc, op[3] + 0.2)
				Op.CIRCLE:
					ci.draw_circle(op[2], op[3] + 0.1, oc)
	ci.draw_set_transform(center, 0.0, Vector2(half, half))
	for op in ops:
		var c: Color = col
		match op[1]:
			Tone.LIGHT:
				c = light
			Tone.DARK:
				c = dark
		match op[0]:
			Op.POLY:
				ci.draw_colored_polygon(op[2], c)
			Op.LINE:
				ci.draw_polyline(op[2], c, op[3])
			Op.CIRCLE:
				ci.draw_circle(op[2], op[3], c)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _get_ops(shape: String) -> Array:
	if not _ops.has(shape):
		_ops[shape] = _build(shape if is_valid_shape(shape) else FALLBACK)
	return _ops[shape]


# ------------------------------------------------------------ geometry

static func _poly(tone: int, pts: Array) -> Array:
	var p := PackedVector2Array(pts)
	var closed := p.duplicate()
	closed.append(p[0])
	return [Op.POLY, tone, p, closed]


static func _poly_p(tone: int, p: PackedVector2Array) -> Array:
	var closed := p.duplicate()
	closed.append(p[0])
	return [Op.POLY, tone, p, closed]


static func _line(tone: int, pts: Array, w: float) -> Array:
	return [Op.LINE, tone, PackedVector2Array(pts), w]


static func _circle(tone: int, c: Vector2, r: float) -> Array:
	return [Op.CIRCLE, tone, c, r]


static func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	return out


static func _star_pts(points: int, r_out: float, r_in: float, rot: float, c: Vector2 = Vector2.ZERO, skew: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * float(i) / points
		if i % 2 == 1:
			a += skew
		out.append(c + Vector2.from_angle(a) * (r_out if i % 2 == 0 else r_in))
	return out


## Crescent stroke along a quadratic curve (claw marks).
static func _crescent(p0: Vector2, p1: Vector2, p2: Vector2, w: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var t := float(i) / n
		var p := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var dv := (p1 - p0).lerp(p2 - p1, t).normalized()
		var off := dv.orthogonal() * w * sin(PI * t)
		left.append(p + off)
		# The tips are shared with the outer edge: no duplicated points.
		if i > 0 and i < n:
			right.append(p - off * 0.25)
	right.reverse()
	left.append_array(right)
	return left


static func _build(shape: String) -> Array:
	match shape:
		"bolt":
			return [_poly(Tone.MAIN, [Vector2(0.0, -0.95), Vector2(0.5, -0.95), Vector2(0.12, -0.22), Vector2(0.52, -0.22),
				Vector2(-0.32, 0.98), Vector2(-0.04, 0.1), Vector2(-0.46, 0.1)]),
				_line(Tone.LIGHT, [Vector2(0.3, -0.82), Vector2(0.05, -0.32)], 0.09)]
		"flame":
			return [_poly(Tone.MAIN, [Vector2(0.02, -1.0), Vector2(0.28, -0.5), Vector2(0.48, -0.72), Vector2(0.7, -0.1),
				Vector2(0.66, 0.38), Vector2(0.42, 0.78), Vector2(0.0, 0.95), Vector2(-0.42, 0.78), Vector2(-0.68, 0.38),
				Vector2(-0.66, -0.08), Vector2(-0.42, -0.48), Vector2(-0.22, -0.22)]),
				_poly(Tone.LIGHT, [Vector2(0.02, -0.2), Vector2(0.3, 0.3), Vector2(0.22, 0.66), Vector2(0.0, 0.76),
				Vector2(-0.22, 0.66), Vector2(-0.3, 0.3)])]
		"droplet":
			var c := Vector2(0, 0.3)
			var pts := PackedVector2Array([Vector2(0, -1.0)])
			pts.append_array(_arc_pts(c, 0.64, deg_to_rad(-28.0), deg_to_rad(208.0), 16))
			return [_poly_p(Tone.MAIN, pts), _line(Tone.LIGHT, [Vector2(-0.34, 0.1), Vector2(-0.36, 0.38), Vector2(-0.22, 0.6)], 0.11)]
		"leaf":
			var axis := Vector2(1, -1).normalized()
			var n := axis.orthogonal()
			var a := PackedVector2Array()
			var b := PackedVector2Array()
			for i in 11:
				var u := -1.0 + 2.0 * i / 10.0
				var p := axis * u * 1.0
				a.append(p + n * 0.46 * (1.0 - u * u))
				if i > 0 and i < 10:
					b.append(p - n * 0.46 * (1.0 - u * u))
			b.reverse()
			a.append_array(b)
			return [_poly_p(Tone.MAIN, a), _line(Tone.DARK, [-axis * 0.95, axis * 0.62], 0.08),
				_line(Tone.DARK, [axis * 0.05, axis * 0.3 + n * 0.25], 0.06), _line(Tone.DARK, [-axis * 0.3, -axis * 0.05 - n * 0.25], 0.06)]
		"snowflake":
			var ops := []
			for k in 3:
				var d := Vector2.from_angle(PI * 0.5 + k * PI / 3.0)
				ops.append(_line(Tone.MAIN, [-d * 0.92, d * 0.92], 0.16))
			for k in 6:
				var d := Vector2.from_angle(PI * 0.5 + k * PI / 3.0)
				var p := d * 0.55
				ops.append(_line(Tone.MAIN, [p + d.rotated(0.8) * 0.3, p, p + d.rotated(-0.8) * 0.3], 0.11))
			ops.append(_circle(Tone.LIGHT, Vector2.ZERO, 0.16))
			return ops
		"claw":
			var ops := []
			for i in 3:
				var o := Vector2((i - 1) * 0.42, (i - 1) * 0.05)
				ops.append(_poly_p(Tone.MAIN, _crescent(Vector2(0.45, -0.88) + o, Vector2(0.3, 0.05) + o, Vector2(-0.5, 0.88) + o, 0.2)))
			return ops
		"fist":
			var ops := []
			ops.append(_poly(Tone.MAIN, [Vector2(-0.42, 0.4), Vector2(0.42, 0.4), Vector2(0.36, 0.92), Vector2(-0.36, 0.92)]))
			ops.append(_poly(Tone.MAIN, [Vector2(-0.66, -0.42), Vector2(0.66, -0.42), Vector2(0.66, 0.26), Vector2(0.5, 0.48),
				Vector2(-0.5, 0.48), Vector2(-0.66, 0.26)]))
			for i in 4:
				ops.append(_circle(Tone.MAIN, Vector2(-0.49 + i * 0.327, -0.45), 0.19))
			for i in 3:
				var x := -0.33 + i * 0.327
				ops.append(_line(Tone.DARK, [Vector2(x, -0.58), Vector2(x, -0.18)], 0.07))
			ops.append(_line(Tone.DARK, [Vector2(-0.66, 0.02), Vector2(0.12, 0.02), Vector2(0.26, 0.2)], 0.09))
			ops.append(_line(Tone.DARK, [Vector2(-0.38, 0.66), Vector2(0.38, 0.66)], 0.06))
			return ops
		"fang":
			return [_poly(Tone.MAIN, [Vector2(-0.88, -0.86), Vector2(0.88, -0.86), Vector2(0.8, -0.42), Vector2(-0.8, -0.42)]),
				_poly(Tone.LIGHT, [Vector2(-0.64, -0.46), Vector2(-0.06, -0.46), Vector2(-0.34, 0.9)]),
				_poly(Tone.LIGHT, [Vector2(0.06, -0.46), Vector2(0.64, -0.46), Vector2(0.34, 0.9)])]
		"bone":
			var n := Vector2(0.707, 0.707) * 0.19
			var e1 := Vector2(-0.55, 0.55)
			var e2 := Vector2(0.55, -0.55)
			return [_line(Tone.MAIN, [e1, e2], 0.28), _circle(Tone.MAIN, e1 + n, 0.23), _circle(Tone.MAIN, e1 - n, 0.23),
				_circle(Tone.MAIN, e2 + n, 0.23), _circle(Tone.MAIN, e2 - n, 0.23)]
		"orb":
			return [_circle(Tone.MAIN, Vector2.ZERO, 0.8),
				_line(Tone.DARK, _arc_pts(Vector2.ZERO, 0.6, deg_to_rad(10.0), deg_to_rad(110.0), 8), 0.12),
				_circle(Tone.LIGHT, Vector2(-0.28, -0.28), 0.22)]
		"comet":
			var h := Vector2(0.36, -0.36)
			var nn := Vector2(0.707, 0.707) * 0.46
			return [_poly(Tone.MAIN, [h + nn, h - nn, Vector2(-0.9, 0.9)]),
				_circle(Tone.MAIN, h, 0.48), _circle(Tone.LIGHT, h + Vector2(-0.14, -0.14), 0.16),
				_line(Tone.LIGHT, [Vector2(-0.18, 0.5), Vector2(-0.55, 0.87)], 0.07)]
		"beam":
			var s := Vector2(-0.62, 0.62)
			var e := Vector2(0.92, -0.92)
			return [_line(Tone.MAIN, [s, e], 0.48), _circle(Tone.MAIN, s, 0.36),
				_line(Tone.LIGHT, [s, e], 0.16), _circle(Tone.LIGHT, s, 0.17)]
		"wave":
			var c := Vector2(-0.78, 0.0)
			return [_circle(Tone.MAIN, c, 0.17),
				_line(Tone.MAIN, _arc_pts(c, 0.5, -0.75, 0.75, 8), 0.17),
				_line(Tone.MAIN, _arc_pts(c, 0.98, -0.72, 0.72, 10), 0.17),
				_line(Tone.MAIN, _arc_pts(c, 1.46, -0.66, 0.66, 12), 0.17)]
		"quake":
			return [_poly(Tone.MAIN, [Vector2(-0.68, 0.46), Vector2(-0.3, 0.46), Vector2(-0.5, -0.2)]),
				_poly(Tone.MAIN, [Vector2(-0.26, 0.46), Vector2(0.26, 0.46), Vector2(0.02, -0.72)]),
				_poly(Tone.MAIN, [Vector2(0.3, 0.46), Vector2(0.7, 0.46), Vector2(0.52, -0.1)]),
				_poly(Tone.MAIN, [Vector2(-0.96, 0.42), Vector2(0.96, 0.42), Vector2(0.9, 0.78), Vector2(-0.9, 0.78)]),
				_line(Tone.DARK, [Vector2(-0.5, 0.42), Vector2(-0.38, 0.58), Vector2(-0.48, 0.78)], 0.07),
				_line(Tone.DARK, [Vector2(0.18, 0.42), Vector2(0.3, 0.6), Vector2(0.22, 0.78)], 0.07),
				_poly(Tone.LIGHT, [Vector2(-0.72, -0.62), Vector2(-0.54, -0.68), Vector2(-0.5, -0.5), Vector2(-0.68, -0.45)]),
				_poly(Tone.LIGHT, [Vector2(0.56, -0.86), Vector2(0.72, -0.82), Vector2(0.68, -0.66), Vector2(0.53, -0.7)])]
		"storm":
			return [_circle(Tone.MAIN, Vector2(-0.42, -0.3), 0.33), _circle(Tone.MAIN, Vector2(0.04, -0.5), 0.42),
				_circle(Tone.MAIN, Vector2(0.48, -0.26), 0.32),
				_poly(Tone.MAIN, [Vector2(-0.62, -0.28), Vector2(0.64, -0.28), Vector2(0.78, -0.02), Vector2(0.64, 0.1), Vector2(-0.62, 0.1), Vector2(-0.78, -0.08)]),
				_poly(Tone.LIGHT, [Vector2(0.02, 0.02), Vector2(0.34, 0.02), Vector2(0.14, 0.4), Vector2(0.34, 0.4),
				Vector2(-0.14, 0.98), Vector2(-0.02, 0.56), Vector2(-0.22, 0.56)])]
		"drill":
			return [_poly(Tone.MAIN, [Vector2(-0.56, -0.55), Vector2(0.56, -0.55), Vector2(0.0, 0.98)]),
				_poly(Tone.DARK, [Vector2(-0.4, -0.95), Vector2(0.4, -0.95), Vector2(0.4, -0.58), Vector2(-0.4, -0.58)]),
				_line(Tone.DARK, [Vector2(-0.44, -0.36), Vector2(0.36, -0.04)], 0.08),
				_line(Tone.DARK, [Vector2(-0.3, 0.06), Vector2(0.22, 0.3)], 0.08),
				_line(Tone.DARK, [Vector2(-0.16, 0.46), Vector2(0.1, 0.6)], 0.07)]
		"spin":
			var ops := []
			for k in 2:
				var a0 := deg_to_rad(-160.0 + k * 180.0)
				var a1 := deg_to_rad(-25.0 + k * 180.0)
				ops.append(_line(Tone.MAIN, _arc_pts(Vector2.ZERO, 0.66, a0, a1, 10), 0.18))
				var p := Vector2.from_angle(a1) * 0.66
				var t := Vector2.from_angle(a1 + PI * 0.5)
				var r := Vector2.from_angle(a1)
				ops.append(_poly(Tone.MAIN, [p + t * 0.34, p + r * 0.27, p - r * 0.27]))
			ops.append(_circle(Tone.LIGHT, Vector2.ZERO, 0.14))
			return ops
		"wing":
			return [_poly(Tone.MAIN, [Vector2(-0.92, 0.6), Vector2(-0.62, -0.08), Vector2(-0.15, -0.6), Vector2(0.45, -0.9),
				Vector2(0.96, -0.9), Vector2(0.7, -0.62), Vector2(0.92, -0.5), Vector2(0.58, -0.24), Vector2(0.8, -0.1),
				Vector2(0.4, 0.16), Vector2(0.58, 0.32), Vector2(0.1, 0.5), Vector2(0.18, 0.7), Vector2(-0.34, 0.68)]),
				_line(Tone.DARK, [Vector2(-0.5, 0.42), Vector2(0.62, -0.62)], 0.06),
				_line(Tone.DARK, [Vector2(-0.38, 0.52), Vector2(0.5, -0.12)], 0.06),
				_line(Tone.DARK, [Vector2(-0.3, 0.62), Vector2(0.3, 0.3)], 0.06)]
		"dash":
			var ops := []
			for k in 2:
				var x := 0.02 + k * 0.46
				ops.append(_poly(Tone.MAIN, [Vector2(x - 0.12, -0.72), Vector2(x + 0.42, 0.0), Vector2(x - 0.12, 0.72),
					Vector2(x - 0.38, 0.72), Vector2(x + 0.14, 0.0), Vector2(x - 0.38, -0.72)]))
			ops.append(_line(Tone.LIGHT, [Vector2(-0.95, -0.36), Vector2(-0.5, -0.36)], 0.11))
			ops.append(_line(Tone.LIGHT, [Vector2(-0.95, 0.0), Vector2(-0.38, 0.0)], 0.11))
			ops.append(_line(Tone.LIGHT, [Vector2(-0.95, 0.36), Vector2(-0.5, 0.36)], 0.11))
			return ops
		"swirl":
			var pts := PackedVector2Array()
			for i in 29:
				var t := float(i) / 28.0
				pts.append(Vector2.from_angle(-PI * 0.5 + t * PI * 3.3) * (0.1 + 0.8 * t))
			return [_line(Tone.MAIN, pts, 0.18), _circle(Tone.LIGHT, Vector2.ZERO, 0.12)]
		"ghost":
			var pts := _arc_pts(Vector2(0, -0.15), 0.68, PI, TAU, 14)
			pts.append_array(PackedVector2Array([Vector2(0.68, 0.72), Vector2(0.45, 0.94), Vector2(0.23, 0.72),
				Vector2(0.0, 0.94), Vector2(-0.23, 0.72), Vector2(-0.45, 0.94), Vector2(-0.68, 0.72)]))
			return [_poly_p(Tone.MAIN, pts), _circle(Tone.DARK, Vector2(-0.24, -0.18), 0.14), _circle(Tone.DARK, Vector2(0.24, -0.18), 0.14),
				_circle(Tone.LIGHT, Vector2(-0.2, -0.22), 0.05), _circle(Tone.LIGHT, Vector2(0.28, -0.22), 0.05)]
		"eye":
			var top := PackedVector2Array()
			for i in 13:
				var s := float(i) / 12.0
				top.append(Vector2(lerpf(-0.96, 0.96, s), -0.6 * sin(PI * s)))
			for i in range(11, 0, -1):
				var s := float(i) / 12.0
				top.append(Vector2(lerpf(-0.96, 0.96, s), 0.6 * sin(PI * s)))
			return [_poly_p(Tone.MAIN, top), _circle(Tone.DARK, Vector2.ZERO, 0.38), _circle(Tone.LIGHT, Vector2.ZERO, 0.15),
				_circle(Tone.LIGHT, Vector2(0.16, -0.16), 0.07)]
		"bubble":
			return [_circle(Tone.MAIN, Vector2(-0.24, 0.3), 0.56), _circle(Tone.MAIN, Vector2(0.5, -0.3), 0.32),
				_circle(Tone.MAIN, Vector2(0.02, -0.74), 0.2), _circle(Tone.LIGHT, Vector2(-0.44, 0.08), 0.14),
				_circle(Tone.LIGHT, Vector2(0.4, -0.42), 0.08)]
		"rock":
			return [_poly(Tone.MAIN, [Vector2(-0.75, 0.72), Vector2(-0.94, 0.05), Vector2(-0.5, -0.64), Vector2(0.15, -0.88),
				Vector2(0.8, -0.46), Vector2(0.94, 0.3), Vector2(0.5, 0.8)]),
				_poly(Tone.LIGHT, [Vector2(-0.5, -0.64), Vector2(0.15, -0.88), Vector2(0.1, -0.26), Vector2(-0.44, -0.1)]),
				_line(Tone.DARK, [Vector2(0.28, 0.78), Vector2(0.38, 0.24), Vector2(0.12, -0.02)], 0.08)]
		"shield":
			var outer := [Vector2(-0.74, -0.8), Vector2(0.0, -0.96), Vector2(0.74, -0.8), Vector2(0.72, 0.04),
				Vector2(0.4, 0.62), Vector2(0.0, 0.96), Vector2(-0.4, 0.62), Vector2(-0.72, 0.04)]
			var inner := []
			for p in outer:
				inner.append(p * 0.58 + Vector2(0, -0.02))
			return [_poly(Tone.MAIN, outer), _poly(Tone.DARK, inner), _line(Tone.LIGHT, [Vector2(0, -0.5), Vector2(0, 0.48)], 0.1)]
		"heart":
			var pts := PackedVector2Array()
			for i in 28:
				var t := TAU * i / 28.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(Vector2(x, y) / 17.0 * 0.95 + Vector2(0, -0.1))
			return [_poly_p(Tone.MAIN, pts), _circle(Tone.LIGHT, Vector2(-0.4, -0.38), 0.14)]
		"up_arrow":
			return [_poly(Tone.MAIN, [Vector2(0.0, -0.96), Vector2(0.74, -0.16), Vector2(0.3, -0.16), Vector2(0.3, 0.92),
				Vector2(-0.3, 0.92), Vector2(-0.3, -0.16), Vector2(-0.74, -0.16)]),
				_line(Tone.LIGHT, [Vector2(0.0, -0.58), Vector2(0.0, 0.7)], 0.1)]
		"shuriken":
			return [_poly_p(Tone.MAIN, _star_pts(4, 0.98, 0.34, -PI * 0.5, Vector2.ZERO, 0.62)), _circle(Tone.DARK, Vector2.ZERO, 0.17)]
		"sparkle":
			return [_poly_p(Tone.MAIN, _star_pts(4, 0.9, 0.22, -PI * 0.5, Vector2(-0.12, 0.12))),
				_poly_p(Tone.LIGHT, _star_pts(4, 0.36, 0.1, -PI * 0.5, Vector2(0.6, -0.6)))]
		"burst":
			return [_poly_p(Tone.MAIN, _star_pts(8, 0.98, 0.5, -PI * 0.5 + PI / 8.0)), _circle(Tone.LIGHT, Vector2.ZERO, 0.32)]
		"star":
			return [_poly_p(Tone.MAIN, _star_pts(5, 0.98, 0.44, -PI * 0.5, Vector2(0, 0.06))), _circle(Tone.LIGHT, Vector2(0, 0.08), 0.14)]
		"joystick":
			return [_line(Tone.MAIN, _arc_pts(Vector2.ZERO, 0.88, 0.0, TAU, 28), 0.1), _circle(Tone.MAIN, Vector2(0.22, -0.22), 0.42),
				_circle(Tone.LIGHT, Vector2(0.12, -0.32), 0.12)]
		"tap":
			return [_circle(Tone.MAIN, Vector2.ZERO, 0.26), _line(Tone.MAIN, _arc_pts(Vector2.ZERO, 0.56, 0.0, TAU, 24), 0.09),
				_line(Tone.MAIN, _arc_pts(Vector2.ZERO, 0.86, 0.0, TAU, 28), 0.06)]
		"dodge":
			# Hop arrow (generic dash button), distinct from "dash" skills.
			var c := Vector2(0.08, 0.32)
			var a1 := deg_to_rad(345.0)
			var arc := _arc_pts(c, 0.74, deg_to_rad(185.0), a1, 14)
			var e := arc[arc.size() - 1]
			var t := Vector2.from_angle(a1 + PI * 0.5)
			var r := Vector2.from_angle(a1)
			return [_line(Tone.MAIN, arc, 0.22), _poly(Tone.MAIN, [e + t * 0.44, e + r * 0.32, e - r * 0.32]),
				_line(Tone.LIGHT, [Vector2(-0.95, 0.62), Vector2(-0.45, 0.62)], 0.11),
				_line(Tone.LIGHT, [Vector2(-0.82, 0.86), Vector2(-0.3, 0.86)], 0.11)]
		"drag":
			var s := Vector2(-0.55, 0.55)
			var e := Vector2(0.58, -0.58)
			var d := (e - s).normalized()
			return [_circle(Tone.MAIN, s, 0.28), _line(Tone.MAIN, [s, e], 0.12),
				_poly(Tone.MAIN, [e + d * 0.3, e + d.orthogonal() * 0.24, e - d.orthogonal() * 0.24])]
	return _build(FALLBACK)
