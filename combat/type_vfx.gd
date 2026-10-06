class_name TypeVfx
extends RefCounted
## Type-specific particle recipes on top of VfxLayer: hit flourishes for
## the 18 types, light projectile trails and the KO burst. Counts scale
## with Settings.particle_scale() (graphics quality) and the layer drops
## particles when full, so nothing here can allocate or overflow.

const PAL := {
	"normal": [Color(1, 1, 1), Color(0.94, 0.93, 0.8)],
	"fire": [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.16), Color(1.0, 0.3, 0.12)],
	"water": [Color(0.6, 0.85, 1.0), Color(0.31, 0.56, 1.0), Color(0.92, 0.97, 1.0)],
	"electric": [Color(1.0, 0.97, 0.63), Color(1.0, 0.85, 0.25)],
	"grass": [Color(0.48, 0.78, 0.3), Color(0.31, 0.6, 0.17), Color(0.71, 0.89, 0.42)],
	"ice": [Color(0.91, 1.0, 1.0), Color(0.59, 0.85, 0.84), Color(0.75, 0.94, 1.0)],
	"fighting": [Color(1.0, 0.7, 0.42), Color(1.0, 0.35, 0.23), Color(1, 1, 1)],
	"poison": [Color(0.76, 0.42, 0.85), Color(0.54, 0.23, 0.66), Color(0.89, 0.65, 0.94)],
	"ground": [Color(0.79, 0.63, 0.35), Color(0.54, 0.42, 0.24), Color(0.89, 0.75, 0.4)],
	"flying": [Color(1, 1, 1), Color(0.81, 0.76, 1.0), Color(0.66, 0.56, 0.95)],
	"psychic": [Color(1.0, 0.48, 0.66), Color(0.98, 0.33, 0.53), Color(1.0, 0.82, 0.88)],
	"bug": [Color(0.78, 0.86, 0.23), Color(0.65, 0.73, 0.1), Color(0.93, 0.94, 0.54)],
	"rock": [Color(0.71, 0.63, 0.21), Color(0.55, 0.48, 0.16), Color(0.85, 0.78, 0.42), Color(0.48, 0.45, 0.41)],
	"ghost": [Color(0.6, 0.49, 0.78), Color(0.45, 0.34, 0.59), Color(0.84, 0.78, 1.0)],
	"dragon": [Color(0.54, 0.36, 1.0), Color(0.44, 0.21, 0.99), Color(0.37, 0.82, 0.88)],
	"dark": [Color(0.23, 0.18, 0.15), Color(0.44, 0.34, 0.27), Color(0.11, 0.08, 0.07)],
	"steel": [Color(1, 1, 1), Color(0.84, 0.84, 0.91), Color(0.6, 0.6, 0.72)],
	"fairy": [Color(1.0, 0.84, 0.93), Color(1.0, 0.61, 0.8), Color(1, 1, 1)],
}


static func _n(base: float, k: float) -> int:
	return maxi(1, int(round(base * k * Settings.particle_scale())))


static func _col(t: String, i: int) -> Color:
	var pal: Array = PAL.get(t, PAL["normal"])
	return pal[i % pal.size()]


static func _rv(r: float) -> Vector2:
	return Vector2(randf_range(-r, r), randf_range(-r, r))


static func _out(speed_min: float, speed_max: float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * randf_range(speed_min, speed_max)


## Extra flourish for a landed hit of `move_type` (k = hit strength 0.6..2.2).
static func hit(vfx: VfxLayer, p: Vector2, move_type: String, k: float) -> void:
	if vfx == null:
		return
	k = clampf(k, 0.6, 2.2)
	var kv := 0.8 + 0.2 * k
	match move_type:
		"fire":
			for i in _n(5, k):
				vfx.emit(VfxLayer.Kind.EMBER, p + _rv(4.0), Vector2(randf_range(-45, 45), randf_range(-95, -30)) * kv, randf_range(0.35, 0.6), randf_range(2.3, 3.9), _col("fire", i))
			for i in _n(1.5, k):
				vfx.emit(VfxLayer.Kind.SMOKE, p + _rv(3.0), Vector2(randf_range(-10, 10), -22), 0.5, 3.6, Color(0.28, 0.24, 0.22, 0.8))
		"water":
			for i in _n(6, k):
				vfx.emit(VfxLayer.Kind.DROP, p + _rv(3.0), Vector2(randf_range(-70, 70), randf_range(-150, -60)) * kv, randf_range(0.35, 0.5), randf_range(2.1, 3.1), _col("water", i))
			vfx.emit(VfxLayer.Kind.RING, p + Vector2(0, 6), Vector2.ZERO, 0.25, 7.0 * kv, Color(0.7, 0.9, 1.0, 0.8))
		"electric":
			for i in _n(3, k):
				vfx.emit(VfxLayer.Kind.ZAP, p + _rv(5.0), Vector2.ZERO, randf_range(0.1, 0.18), randf_range(10.4, 16.9) * kv, _col("electric", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(8.0), _out(10, 30), 0.22, 3.9, _col("electric", 0))
		"grass":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.LEAF, p + _rv(4.0), _out(40, 100) * kv + Vector2(0, -30), randf_range(0.45, 0.7), randf_range(2.3, 3.4), _col("grass", i))
		"ice":
			for i in _n(5, k):
				vfx.emit(VfxLayer.Kind.SHARD, p + _rv(2.0), _out(90, 170) * kv, randf_range(0.18, 0.3), randf_range(2.9, 4.4), _col("ice", i))
			vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(4.0), Vector2.ZERO, 0.3, 5.2, Color(1, 1, 1))
		"fighting":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.STREAK, p + _rv(2.0), _out(140, 220) * kv, randf_range(0.1, 0.16), 2.0, _col("fighting", i))
			vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.2, 10.0 * kv, Color(1.0, 0.85, 0.6, 0.9))
		"poison":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.BUBBLE, p + _rv(6.0), Vector2(randf_range(-25, 25), randf_range(-45, -15)), randf_range(0.4, 0.65), randf_range(2.1, 3.4), _col("poison", i))
		"ground":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.DEBRIS, p + _rv(3.0), Vector2(randf_range(-70, 70), randf_range(-140, -60)) * kv, randf_range(0.35, 0.5), randf_range(2.3, 3.6), _col("ground", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.DUST, p + Vector2(randf_range(-8, 8), 6), Vector2(randf_range(-20, 20), -5), 0.45, 3.9, _col("ground", 2))
		"flying":
			for i in _n(3, k):
				vfx.emit(VfxLayer.Kind.FEATHER, p + _rv(5.0), _out(30, 70) + Vector2(0, -20), randf_range(0.5, 0.75), randf_range(3.4, 4.4), _col("flying", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.STREAK, p + _rv(6.0), Vector2(randf_range(120, 180) * (1.0 if randf() < 0.5 else -1.0), randf_range(-30, 30)), 0.14, 1.2, Color(1, 1, 1, 0.7))
		"psychic":
			vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.3, 9.0 * kv, _col("psychic", 1))
			vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.42, 14.0 * kv, Color(_col("psychic", 2), 0.7))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(9.0), Vector2.ZERO, 0.28, 3.9, _col("psychic", i))
		"bug":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.SHARD, p + _rv(3.0), _out(70, 130) * kv, randf_range(0.14, 0.22), randf_range(1.8, 2.6), _col("bug", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.DOT, p + _rv(4.0), _out(20, 50), 0.4, 2.6, _col("bug", 2))
		"rock":
			for i in _n(5, k):
				vfx.emit(VfxLayer.Kind.DEBRIS, p + _rv(3.0), Vector2(randf_range(-80, 80), randf_range(-160, -70)) * kv, randf_range(0.38, 0.55), randf_range(2.9, 4.4), _col("rock", i))
			vfx.emit(VfxLayer.Kind.DUST, p + Vector2(0, 5), Vector2.ZERO, 0.4, 4.5, Color(0.6, 0.55, 0.45))
		"ghost":
			for i in _n(3, k):
				vfx.emit(VfxLayer.Kind.WISP, p + _rv(6.0), Vector2(randf_range(-15, 15), randf_range(-40, -15)), randf_range(0.5, 0.75), randf_range(2.9, 3.9), _col("ghost", i))
			vfx.emit(VfxLayer.Kind.SMOKE, p, Vector2(0, -12), 0.45, 3.9, Color(0.2, 0.12, 0.28, 0.8))
		"dragon":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.SCALE, p + _rv(3.0), _out(60, 130) * kv, randf_range(0.3, 0.45), randf_range(3.4, 4.4), _col("dragon", i))
			vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.22, 9.0 * kv, Color(0.55, 0.4, 1.0, 0.85))
		"dark":
			for i in _n(3, k):
				vfx.emit(VfxLayer.Kind.SMOKE, p + _rv(5.0), _out(10, 30) + Vector2(0, -10), randf_range(0.4, 0.6), randf_range(3.4, 4.4), _col("dark", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.STREAK, p + _rv(2.0), _out(130, 200), 0.12, 1.8, Color(0.55, 0.4, 0.75))
		"steel":
			for i in _n(5, k):
				vfx.emit(VfxLayer.Kind.SPARK, p, _out(110, 210) * kv, randf_range(0.12, 0.2), 1.2, _col("steel", i))
			vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(3.0), Vector2.ZERO, 0.22, 5.9, Color(1, 1, 1))
		"fairy":
			for i in _n(4, k):
				vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(9.0), _out(15, 45), randf_range(0.3, 0.5), randf_range(3.2, 4.5), _col("fairy", i))
			for i in _n(2, k):
				vfx.emit(VfxLayer.Kind.DOT, p + _rv(5.0), _out(20, 50), 0.4, 2.3, _col("fairy", 1))
		"normal":
			vfx.emit(VfxLayer.Kind.SPARKLE, p, Vector2.ZERO, 0.16, 7.8 * kv, Color(1, 1, 1))
			for i in _n(3, k):
				vfx.emit(VfxLayer.Kind.STREAK, p + _rv(2.0), _out(130, 200) * kv, 0.1, 1.6, _col("normal", i))


## One trail particle behind a projectile (style first, then move type).
static func trail(vfx: VfxLayer, p: Vector2, dir: Vector2, move_type: String, style: String, c1: Color, c2: Color) -> void:
	if vfx == null:
		return
	var back := -dir
	var t := move_type
	match style:
		"fire":
			t = "fire"
		"water":
			t = "water"
		"bolt":
			t = "electric"
	match t:
		"fire":
			vfx.emit(VfxLayer.Kind.EMBER, p + _rv(2.0), back * 20.0 + Vector2(randf_range(-8, 8), -30), randf_range(0.25, 0.4), randf_range(1.6, 2.4), _col("fire", randi()))
		"water":
			vfx.emit(VfxLayer.Kind.DROP, p + _rv(2.0), back * 30.0 + Vector2(randf_range(-15, 15), -25), 0.3, 1.5, c2 if randf() < 0.5 else c1)
		"electric":
			vfx.emit(VfxLayer.Kind.ZAP, p + _rv(2.0), Vector2.ZERO, randf_range(0.06, 0.1), randf_range(5.0, 7.0), c2)
		"ghost":
			vfx.emit(VfxLayer.Kind.WISP, p + _rv(2.0), back * 10.0 + Vector2(0, -10), 0.35, 2.0, Color(c2, 0.8))
		"poison":
			vfx.emit(VfxLayer.Kind.BUBBLE, p + _rv(3.0), Vector2(randf_range(-10, 10), -16), 0.4, 1.5, c2)
		"psychic", "fairy":
			vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(3.0), back * 10.0, 0.25, 2.4, c2 if randf() < 0.6 else Color(1, 1, 1))
		"grass":
			vfx.emit(VfxLayer.Kind.LEAF, p + _rv(2.0), back * 20.0, 0.45, 1.8, _col("grass", randi()))
		"ice", "steel":
			vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(3.0), back * 15.0, 0.2, 2.0, Color(1, 1, 1))
		"rock", "ground":
			vfx.emit(VfxLayer.Kind.DUST, p + _rv(2.0), back * 10.0, 0.3, 1.8, Color(c2, 0.8))
		"dragon":
			vfx.emit(VfxLayer.Kind.SCALE, p + _rv(2.0), back * 20.0, 0.3, 2.0, c2)
		"dark":
			vfx.emit(VfxLayer.Kind.SMOKE, p + _rv(2.0), back * 10.0, 0.32, 2.2, Color(0.15, 0.1, 0.12, 0.8))
		"flying":
			vfx.emit(VfxLayer.Kind.STREAK, p, back * 60.0, 0.15, 1.0, Color(1, 1, 1, 0.7))
		_:
			vfx.emit(VfxLayer.Kind.DOT, p + _rv(1.5), back * 25.0, 0.22, 2.2, Color(c2, 0.85))


## Big KO flourish: expanding rings + stars in the fighter's team colour.
static func ko(vfx: VfxLayer, p: Vector2, c: Color) -> void:
	if vfx == null:
		return
	vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.45, 22.0, Color(1, 1, 1, 0.95))
	vfx.emit(VfxLayer.Kind.RING, p, Vector2.ZERO, 0.7, 34.0, Color(c, 0.85))
	for i in _n(8, 1.0):
		vfx.emit(VfxLayer.Kind.SPARKLE, p + _rv(6.0), _out(60, 140), randf_range(0.45, 0.7), randf_range(3.0, 4.5), Color(1, 1, 0.85) if i % 2 == 0 else c.lightened(0.3))
	for i in _n(6, 1.0):
		vfx.emit(VfxLayer.Kind.STREAK, p, _out(180, 280), 0.18, 2.0, Color(1, 1, 1, 0.9))
