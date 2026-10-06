class_name ArenaArt
extends RefCounted
## Procedural pixel-art generator for arena tiles and props. Everything here
## is original art created by code for this project (no third-party assets),
## generated once per arena and cached as textures.

const TILE := 16

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func _c(palette: Dictionary, key: String, fallback: String) -> Color:
	return Color.from_string(String(palette.get(key, fallback)), Color.MAGENTA)


static func _new(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


# ------------------------------------------------------------------- tiles

## Builds the ground tile atlas. Returns [texture, tile index map].
## Tiles: grass x6, flowers x3, tuft x3, dirt x4, border x2.
static func ground_atlas(palette: Dictionary, seed_value: int) -> Array:
	var key := "ground_%d_%s" % [seed_value, str(palette.hash())]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grass := _c(palette, "grass", "#4f9a3e")
	var grass_d := _c(palette, "grass_dark", "#3f8232")
	var grass_l := _c(palette, "grass_light", "#6bb84f")
	var dirt := _c(palette, "dirt", "#b98a52")
	var dirt_d := _c(palette, "dirt_dark", "#9a6f3e")
	var border := _c(palette, "border", "#1d4522")
	var flower_cols := [Color("#f2f2f2"), Color("#ffd84a"), Color("#ff7aa8"), Color("#9ad8ff")]
	var names := []
	var count := 18
	var img := _new(TILE * count, TILE)
	var idx := 0
	# Grass
	for v in 6:
		_grass_tile(img, idx * TILE, grass, grass_d, grass_l, rng, v)
		names.append("grass")
		idx += 1
	# Flowers
	for v in 3:
		_grass_tile(img, idx * TILE, grass, grass_d, grass_l, rng, v)
		for n in 2 + v:
			var fx := idx * TILE + rng.randi_range(2, 13)
			var fy := rng.randi_range(2, 13)
			var fc: Color = flower_cols[rng.randi() % flower_cols.size()]
			img.set_pixel(fx, fy, fc)
			img.set_pixel(fx + 1, fy, fc)
			img.set_pixel(fx, fy + 1, fc)
			img.set_pixel(fx + 1, fy + 1, Color("#ffe066"))
		names.append("flower")
		idx += 1
	# Tufts
	for v in 3:
		_grass_tile(img, idx * TILE, grass, grass_d, grass_l, rng, v)
		var bx := idx * TILE + rng.randi_range(3, 10)
		var by := rng.randi_range(6, 11)
		for b in 4:
			var x := bx + b
			var hgt := 2 + (b % 2) * 2
			for y in hgt:
				img.set_pixel(x, by + 3 - y, grass_l if y > 0 else grass_d)
		names.append("tuft")
		idx += 1
	# Dirt
	for v in 4:
		for y in TILE:
			for x in TILE:
				var c := dirt
				var r := rng.randf()
				if r < 0.12:
					c = dirt_d
				elif r < 0.18:
					c = dirt.lightened(0.12)
				img.set_pixel(idx * TILE + x, y, c)
		if v >= 2:
			var px := idx * TILE + rng.randi_range(3, 11)
			var py := rng.randi_range(3, 11)
			img.set_pixel(px, py, Color("#8a8a8a"))
			img.set_pixel(px + 1, py, Color("#b0b0b0"))
		names.append("dirt")
		idx += 1
	# Border (dense forest floor / cliff)
	for v in 2:
		for y in TILE:
			for x in TILE:
				var c := border
				var r := rng.randf()
				if r < 0.2:
					c = border.darkened(0.25)
				elif r < 0.3:
					c = border.lightened(0.1)
				img.set_pixel(idx * TILE + x, y, c)
		names.append("border")
		idx += 1
	var tex := ImageTexture.create_from_image(img)
	var out := [tex, names]
	_cache[key] = out
	return out


static func _grass_tile(img: Image, ox: int, base: Color, dark: Color, light: Color, rng: RandomNumberGenerator, variant: int) -> void:
	for y in TILE:
		for x in TILE:
			var c := base
			var r := rng.randf()
			if r < 0.07:
				c = dark
			elif r < 0.11:
				c = light
			img.set_pixel(ox + x, y, c)
	# A few blade strokes
	for n in 3 + variant:
		var x := ox + rng.randi_range(1, 14)
		var y := rng.randi_range(2, 14)
		img.set_pixel(x, y, dark)
		img.set_pixel(x, y - 1, light if variant % 2 == 0 else dark)


# ------------------------------------------------------------------- props

## Shaded blob: fills an ellipse with simple top-left lighting and outline.
static func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, base: Color, outline: Color, rng: RandomNumberGenerator, speckle: float = 0.06) -> void:
	var x0 := int(floor(cx - rx - 1))
	var x1 := int(ceil(cx + rx + 1))
	var y0 := int(floor(cy - ry - 1))
	var y1 := int(ceil(cy + ry + 1))
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var c := base
			var shade := -(nx * 0.55 + ny * 0.8)
			if shade > 0.45:
				c = base.lightened(0.22)
			elif shade < -0.35:
				c = base.darkened(0.28)
			if rng.randf() < speckle:
				c = c.darkened(0.15)
			if d > 0.78:
				c = outline
			img.set_pixel(x, y, c)


static func rock(palette: Dictionary, radius: float, variant: int) -> Texture2D:
	var key := "rock_%d_%d_%s" % [int(radius), variant, palette.get("rock", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant * 31 + int(radius)
	var w := int(radius * 2.4) + 4
	var h := int(radius * 2.2) + 4
	var img := _new(w, h)
	var base := _c(palette, "rock", "#8d8d96")
	var outline := base.darkened(0.6)
	_blob(img, w * 0.5, h * 0.55, radius * 1.15, radius * 0.95, base, outline, rng)
	_blob(img, w * 0.5 + radius * 0.35 * (1 if variant % 2 == 0 else -1), h * 0.42, radius * 0.6, radius * 0.5, base.lightened(0.05), outline, rng)
	# Cracks
	for n in 2:
		var x := int(w * 0.5 + rng.randf_range(-radius * 0.5, radius * 0.5))
		var y := int(h * 0.55 + rng.randf_range(-radius * 0.3, radius * 0.3))
		for s in 3:
			if x + s < w and y + s / 2 < h and img.get_pixel(x + s, y + s / 2).a > 0.5:
				img.set_pixel(x + s, y + s / 2, outline.lightened(0.15))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func tree(palette: Dictionary, variant: int) -> Texture2D:
	var key := "tree_%d_%s" % [variant, palette.get("leaves", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + variant * 17
	var w := 52
	var h := 66
	var img := _new(w, h)
	var trunk := _c(palette, "trunk", "#6b4a2b")
	var leaves := _c(palette, "leaves", "#2f7d32")
	var outline := leaves.darkened(0.6)
	# Trunk with roots
	for y in range(44, 62):
		for x in range(21, 31):
			var c := trunk
			if x <= 22:
				c = trunk.lightened(0.15)
			elif x >= 29:
				c = trunk.darkened(0.3)
			if x == 21 or x == 30:
				c = trunk.darkened(0.55)
			img.set_pixel(x, y, c)
	for x in range(18, 34):
		img.set_pixel(x, 61, trunk.darkened(0.5))
	# Canopy: layered blobs
	var cx := 26.0 + (variant % 3 - 1) * 1.5
	_blob(img, cx, 30, 22, 17, leaves.darkened(0.08), outline, rng, 0.1)
	_blob(img, cx - 8, 22, 13, 11, leaves, outline, rng, 0.1)
	_blob(img, cx + 9, 21, 12, 10, leaves, outline, rng, 0.1)
	_blob(img, cx, 14, 12, 10, leaves.lightened(0.06), outline, rng, 0.1)
	# Highlights / fruit
	for n in 6:
		var x := int(cx + rng.randf_range(-14, 10))
		var y := int(rng.randf_range(10, 34))
		if img.get_pixel(x, y).a > 0.5 and img.get_pixel(x, y) != outline:
			img.set_pixel(x, y, leaves.lightened(0.35))
	if variant == 2:
		for n in 4:
			var x := int(cx + rng.randf_range(-12, 12))
			var y := int(rng.randf_range(16, 36))
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, Color("#e84a5f"))
				img.set_pixel(x + 1, y, Color("#ff8a9a"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func stump(palette: Dictionary) -> Texture2D:
	var key := "stump_%s" % palette.get("trunk", "")
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var img := _new(24, 22)
	var trunk := _c(palette, "trunk", "#6b4a2b")
	for y in range(8, 20):
		for x in range(3, 21):
			var c := trunk.darkened(0.1)
			if x <= 4:
				c = trunk.lightened(0.1)
			elif x >= 19:
				c = trunk.darkened(0.35)
			img.set_pixel(x, y, c)
	_blob(img, 12, 8, 9, 4.5, Color("#c9a26b"), trunk.darkened(0.5), rng, 0.0)
	for x in range(8, 16):
		img.set_pixel(x, 8, Color("#a87f4a"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func bush(palette: Dictionary, variant: int) -> Texture2D:
	var key := "bush_%d_%s" % [variant, palette.get("leaves", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + variant
	var img := _new(30, 20)
	var leaves := _c(palette, "leaves", "#2f7d32").lightened(0.08)
	var outline := leaves.darkened(0.55)
	_blob(img, 9, 12, 8, 7, leaves, outline, rng, 0.12)
	_blob(img, 20, 12, 8, 7, leaves, outline, rng, 0.12)
	_blob(img, 15, 8, 8, 6, leaves.lightened(0.05), outline, rng, 0.12)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func wall(palette: Dictionary, w: int, h: int) -> Texture2D:
	var key := "wall_%d_%d_%s" % [w, h, palette.get("wall", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 7 + h
	var top_h := 6
	var img := _new(w, h + top_h)
	var base := _c(palette, "wall", "#9a917f")
	var top := base.lightened(0.2)
	var mortar := base.darkened(0.35)
	var outline := base.darkened(0.6)
	for y in h + top_h:
		for x in w:
			var c := base
			if y < top_h:
				c = top if rng.randf() > 0.1 else top.darkened(0.08)
				if y == top_h - 1:
					c = base.darkened(0.15)
			else:
				var ry := y - top_h
				var row := ry / 5
				var off := 0 if row % 2 == 0 else 4
				if ry % 5 == 4 or (x + off) % 9 == 0:
					c = mortar
				elif rng.randf() < 0.08:
					c = base.darkened(0.1)
			if x == 0 or x == w - 1 or y == 0 or y == h + top_h - 1:
				c = outline
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func pond(palette: Dictionary, radius: int) -> Texture2D:
	var key := "pond_%d_%s" % [radius, palette.get("water", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = radius
	var w := radius * 2 + 6
	var h := int(radius * 1.5) + 6
	var img := _new(w, h)
	var water := _c(palette, "water", "#3d7fc4")
	var shore := _c(palette, "dirt", "#b98a52")
	_blob(img, w * 0.5, h * 0.5, radius + 2, radius * 0.72 + 2, shore, shore.darkened(0.4), rng, 0.05)
	_blob(img, w * 0.5, h * 0.5, radius - 1, radius * 0.72 - 1, water, water.darkened(0.3), rng, 0.0)
	for n in 8:
		var x := int(w * 0.5 + rng.randf_range(-radius * 0.6, radius * 0.6))
		var y := int(h * 0.5 + rng.randf_range(-radius * 0.35, radius * 0.35))
		for k in 3:
			if img.get_pixel(x + k, y) == water:
				img.set_pixel(x + k, y, water.lightened(0.3))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
