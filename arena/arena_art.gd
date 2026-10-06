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
		if palette.has("cracks"):
			# Volcanic ground (v0.2): dark cracks with a glowing core instead of tufts.
			_ground_crack(img, idx * TILE, grass_d.darkened(0.4), _c(palette, "cracks", "#ff6a1a"), rng)
			names.append("tuft")
			idx += 1
			continue
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


static func _ground_crack(img: Image, ox: int, dark: Color, glow: Color, rng: RandomNumberGenerator) -> void:
	var x := rng.randi_range(2, 6)
	var y := rng.randi_range(3, 12)
	for s in 9:
		if x < 0 or x > 15 or y < 0 or y > 15:
			break
		img.set_pixel(ox + x, y, glow if s == 4 or s == 5 else dark)
		x += 1
		y += rng.randi_range(-1, 1)


# --------------------------------------------------------- terrain (v0.2)
# Interactive ground terrain art (arena/arena_terrain.gd): lava and shallow
# water regions, tall grass rows, burnt grass. Generated once and cached.

## Height (px) that tall grass blades rise above their own cell row.
const GRASS_OVER := 12
const ATLAS_WIDTH := 1024


static func cache_get(key: String) -> Variant:
	return _cache.get(key)


static func cache_put(key: String, value: Variant) -> void:
	_cache[key] = value


## Shelf-packs images (nulls allowed) into one atlas so a whole layer of
## terrain draws from a single texture (batched draw calls on mobile).
## Returns [Image atlas, Array of Rect2i] (empty Rect2i for nulls).
static func pack_atlas(images: Array) -> Array:
	var order := []
	for i in images.size():
		if images[i] != null:
			order.append(i)
	order.sort_custom(func(a, b): return images[a].get_height() > images[b].get_height())
	var rects := []
	rects.resize(images.size())
	for i in images.size():
		rects[i] = Rect2i()
	var x := 0
	var y := 0
	var shelf := 0
	for i in order:
		var img: Image = images[i]
		if x + img.get_width() > ATLAS_WIDTH:
			x = 0
			y += shelf + 1
			shelf = 0
		rects[i] = Rect2i(x, y, img.get_width(), img.get_height())
		x += img.get_width() + 1
		shelf = maxi(shelf, img.get_height())
	var atlas := _new(ATLAS_WIDTH, maxi(1, y + shelf))
	for i in order:
		var img: Image = images[i]
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), rects[i].position)
	return [atlas, rects]

## Lava / shallow-water / ash region rasterised from a signed distance
## function (`sdf.call(world_pos) -> float`, negative inside) over `box`
## (world px). Returns Images [base, overlay_a, overlay_b] (overlays null for
## ash): lava overlays are two glow/vein layers cross-faded at runtime, water
## overlays two glint frames. Not cached: ArenaTerrain packs and caches an
## atlas per arena.
static func terrain_images(kind: String, palette: Dictionary, box: Rect2i, sdf: Callable) -> Array:
	var base := _new(box.size.x, box.size.y)
	var over_a := _new(box.size.x, box.size.y)
	var over_b := _new(box.size.x, box.size.y)
	match kind:
		"lava":
			_paint_lava(palette, box, sdf, base, over_a, over_b)
		"ash":
			_paint_ash(palette, box, sdf, base)
		_:
			_paint_water(palette, box, sdf, base, over_a, over_b)
	if kind == "ash":
		return [base, null, null]
	return [base, over_a, over_b]


## Signed distances sampled every SD_STEP px (bilinear in between): the
## shape callable is far too slow to call for every pixel.
const SD_STEP := 4


static func _sd_grid(box: Rect2i, sdf: Callable) -> PackedFloat32Array:
	var gw := box.size.x / SD_STEP + 2
	var gh := box.size.y / SD_STEP + 2
	var out := PackedFloat32Array()
	out.resize(gw * gh)
	var o := Vector2(box.position)
	for gy in gh:
		for gx in gw:
			out[gy * gw + gx] = sdf.call(o + Vector2(gx * SD_STEP, gy * SD_STEP))
	return out


## Native smooth noise over `box` in world coordinates: one byte per pixel.
static func _noise_field(box: Rect2i, freq: float, seed_value: int) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.seed = seed_value
	n.frequency = freq
	n.offset = Vector3(box.position.x, box.position.y, 0.0)
	return n.get_image(box.size.x, box.size.y, false, false, false).get_data()


static func _paint_lava(palette: Dictionary, box: Rect2i, sdf: Callable, base: Image, glow_a: Image, glow_b: Image) -> void:
	var lava := _c(palette, "lava", "#ff6a1a")
	var lava_d := _c(palette, "lava_dark", "#c4300e")
	var lava_l := _c(palette, "lava_light", "#ffd04a")
	var crust := _c(palette, "crust", "#2b1b18")
	var crust_l := crust.lightened(0.14)
	var plate := crust.lerp(lava_d, 0.3)
	var plate_edge := crust.lerp(lava_d, 0.7)
	var mid := lava.lerp(lava_d, 0.45)
	var halo := lava.lerp(lava_d, 0.3)
	var rim := Color(lava, 0.35)
	var hot := Color(1.0, 0.96, 0.7)
	var w := box.size.x
	var h := box.size.y
	var gw := w / SD_STEP + 2
	var sdg := _sd_grid(box, sdf)
	var edge := _noise_field(box, 0.15, 11)
	var f1 := _noise_field(box, 0.045, 12)
	var f2 := _noise_field(box, 0.1, 13)
	var f3 := _noise_field(box, 0.045, 14)
	for by in range(0, h, SD_STEP):
		for bx in range(0, w, SD_STEP):
			var gi := (by / SD_STEP) * gw + bx / SD_STEP
			var c00 := sdg[gi]
			var c10 := sdg[gi + 1]
			var c01 := sdg[gi + gw]
			var c11 := sdg[gi + gw + 1]
			if minf(minf(c00, c10), minf(c01, c11)) > 9.0:
				continue
			for yy in SD_STEP:
				var y := by + yy
				if y >= h:
					break
				var ty := yy * 0.25
				var dl := lerpf(c00, c01, ty)
				var dr := lerpf(c10, c11, ty)
				for xx in SD_STEP:
					var x := bx + xx
					if x >= w:
						break
					var i := y * w + x
					var d := lerpf(dl, dr, xx * 0.25) + (edge[i] - 128) * 0.045
					if d > 5.0:
						continue
					if d > 0.0:
						# Heat halo over the surrounding ground (pulses with the glow).
						var ha := (1.0 - d / 5.0) * 0.5
						glow_a.set_pixel(x, y, Color(halo, ha))
						glow_b.set_pixel(x, y, Color(halo, ha * 0.7))
						continue
					if d > -2.5:
						base.set_pixel(x, y, crust if (edge[i] & 4) == 0 else crust_l)
						continue
					if d > -5.0:
						base.set_pixel(x, y, lava_d)
						glow_a.set_pixel(x, y, rim)
						continue
					var n1 := f1[i]
					var n2 := f2[i]
					var c := lava
					if n2 > 172:
						c = plate if n2 > 180 else plate_edge
					elif n2 > 160:
						c = lava_d
					elif n1 < 100:
						c = mid
					base.set_pixel(x, y, c)
					if n2 > 160:
						continue
					# Bright flowing veins: two noise isolines, cross-faded at runtime.
					var v1 := absi(n1 - 128)
					if v1 < 5:
						glow_a.set_pixel(x, y, hot)
					elif v1 < 11:
						glow_a.set_pixel(x, y, lava_l)
					var v2 := absi(f3[i] - 128)
					if v2 < 5:
						glow_b.set_pixel(x, y, hot)
					elif v2 < 11:
						glow_b.set_pixel(x, y, lava_l)


## Decorative ash field (no gameplay effect): speckled, dithered edges.
static func _paint_ash(palette: Dictionary, box: Rect2i, sdf: Callable, base: Image) -> void:
	var ash := _c(palette, "ash_light", "#58504e")
	var cols := [ash, ash.darkened(0.12), ash.lightened(0.08), ash.darkened(0.25)]
	var w := box.size.x
	var h := box.size.y
	var gw := w / SD_STEP + 2
	var sdg := _sd_grid(box, sdf)
	var edge := _noise_field(box, 0.09, 31)
	var rng := RandomNumberGenerator.new()
	rng.seed = box.position.x * 17 + box.position.y
	# Speckle tile blitted over blocks far inside the edge (native, fast).
	var tile_key := "ash_tile_%s" % ash.to_html()
	var tile: Image = _cache.get(tile_key)
	if tile == null:
		tile = _new(64, 64)
		for ty in 64:
			for tx in 64:
				var r := rng.randf()
				var c: Color = cols[0] if r > 0.35 else cols[1 + rng.randi() % 3]
				tile.set_pixel(tx, ty, Color(c, 0.85))
		_cache[tile_key] = tile
	for by in range(0, h, SD_STEP):
		for bx in range(0, w, SD_STEP):
			var gi := (by / SD_STEP) * gw + bx / SD_STEP
			var lo := minf(minf(sdg[gi], sdg[gi + 1]), minf(sdg[gi + gw], sdg[gi + gw + 1]))
			if lo > 10.0:
				continue
			var hi := maxf(maxf(sdg[gi], sdg[gi + 1]), maxf(sdg[gi + gw], sdg[gi + gw + 1]))
			if hi < -16.0 and bx + SD_STEP <= w and by + SD_STEP <= h:
				base.blit_rect(tile, Rect2i((box.position.x + bx) & 60, (box.position.y + by) & 60, SD_STEP, SD_STEP), Vector2i(bx, by))
				continue
			for yy in SD_STEP:
				var y := by + yy
				if y >= h:
					break
				var dl := lerpf(sdg[gi], sdg[gi + gw], yy * 0.25)
				var dr := lerpf(sdg[gi + 1], sdg[gi + gw + 1], yy * 0.25)
				for xx in SD_STEP:
					var x := bx + xx
					if x >= w:
						break
					var d := lerpf(dl, dr, xx * 0.25) + (edge[y * w + x] - 128) * 0.08
					if d > 0.0:
						continue
					var r := rng.randf()
					if d > -6.0 and r < 0.5 + d / 12.0:
						continue  # dithered soft edge
					var c: Color = cols[0] if r > 0.35 else cols[1 + rng.randi() % 3]
					base.set_pixel(x, y, Color(c, 0.85))


static func _paint_water(palette: Dictionary, box: Rect2i, sdf: Callable, base: Image, glint_a: Image, glint_b: Image) -> void:
	var water := _c(palette, "shallow_water", "#3fb2df")
	var deep := _c(palette, "shallow_deep", "#2a86c2")
	var foam := Color(0.9, 0.97, 1.0, 0.95)
	var ripple := water.lightened(0.25)
	var ripple_a := Color(ripple, 0.85)
	var w := box.size.x
	var h := box.size.y
	var gw := w / SD_STEP + 2
	var sdg := _sd_grid(box, sdf)
	var edge := _noise_field(box, 0.13, 21)
	var rip := _noise_field(box, 0.08, 22)
	for by in range(0, h, SD_STEP):
		for bx in range(0, w, SD_STEP):
			var gi := (by / SD_STEP) * gw + bx / SD_STEP
			var c00 := sdg[gi]
			var c10 := sdg[gi + 1]
			var c01 := sdg[gi + gw]
			var c11 := sdg[gi + gw + 1]
			if minf(minf(c00, c10), minf(c01, c11)) > 6.0:
				continue
			for yy in SD_STEP:
				var y := by + yy
				if y >= h:
					break
				var ty := yy * 0.25
				var dl := lerpf(c00, c01, ty)
				var dr := lerpf(c10, c11, ty)
				for xx in SD_STEP:
					var x := bx + xx
					if x >= w:
						break
					var i := y * w + x
					var d := lerpf(dl, dr, xx * 0.25) + (edge[i] - 128) * 0.035
					if d > 0.0:
						continue
					if d > -1.6:
						base.set_pixel(x, y, foam)
						continue
					if d > -3.5:
						base.set_pixel(x, y, ripple_a)
						continue
					var depth := clampf(-d / 34.0, 0.0, 1.0)
					var c := water.lerp(deep, depth)
					if absi(rip[i] - 128) < 4:
						c = c.lerp(ripple, 0.6)
					base.set_pixel(x, y, Color(c, 0.66 + 0.24 * depth))
	# Sun glints: short bright dashes, different spots in each frame.
	var rng := RandomNumberGenerator.new()
	rng.seed = box.position.x * 31 + box.position.y * 7 + box.size.x
	var n_glints := maxi(3, w * h / 900)
	for img in [glint_a, glint_b]:
		var placed := 0
		var tries := 0
		while placed < n_glints and tries < n_glints * 12:
			tries += 1
			var x := rng.randi_range(2, w - 6)
			var y := rng.randi_range(2, h - 3)
			if float(sdf.call(Vector2(box.position) + Vector2(x, y))) > -6.0:
				continue
			var ln := rng.randi_range(2, 4)
			for k in ln:
				img.set_pixel(x + k, y, Color(1, 1, 1, 0.85))
			img.set_pixel(x + 1, y - 1, Color(1, 1, 1, 0.45))
			placed += 1


## One image per cell row of a tall grass patch (null for empty rows).
## Each row is TILE px per column and TILE + GRASS_OVER tall: a streaked
## body plus tufts of blades rising above it, so stacked y-sorted rows
## overlap the lower body of a fighter standing inside the patch.
static func tall_grass_rows(palette: Dictionary, cells: PackedByteArray, cols: int, rows: int, key: String) -> Array:
	var ck := "tallgrass_%s_%d" % [key, palette.hash()]
	var body := _c(palette, "tall_grass", "#2e7d32")
	var light := _c(palette, "tall_grass_light", "#" + body.lightened(0.45).to_html(false))
	var shades := [body, body.darkened(0.14), body.lightened(0.07), body.darkened(0.07)]
	var shadow := body.darkened(0.38)
	var outline := body.darkened(0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)
	var out := []
	for r in rows:
		var any := false
		for c in cols:
			if cells[r * cols + c] == 1:
				any = true
		if not any:
			out.append(null)
			continue
		var img := _new(cols * TILE, TILE + GRASS_OVER)
		for c in cols:
			if cells[r * cols + c] != 1:
				continue
			var left_edge := c == 0 or cells[r * cols + c - 1] != 1
			var right_edge := c == cols - 1 or cells[r * cols + c + 1] != 1
			var bottom_edge := r == rows - 1 or cells[(r + 1) * cols + c] != 1
			# Body: vertical streaks, ragged outer edges.
			for x in TILE:
				var cut_bottom := rng.randi_range(0, 2) if bottom_edge else 0
				var y := 0
				while y < TILE - cut_bottom:
					var run := rng.randi_range(2, 5)
					var col: Color = shades[rng.randi() % shades.size()]
					for k in run:
						if y + k >= TILE - cut_bottom:
							break
						var yy := y + k
						var edge_cut := (left_edge and x < 1 + yy % 3 / 2) or (right_edge and x > 14 - (yy + 1) % 3 / 2)
						if bottom_edge and ((left_edge and x + (TILE - 1 - yy) < 4) or (right_edge and (TILE - 1 - x) + (TILE - 1 - yy) < 4)):
							edge_cut = true  # rounded bottom corners
						if not edge_cut:
							img.set_pixel(c * TILE + x, GRASS_OVER + y + k, col)
					y += run
			# Tufts of blades fanning up from inside the body: a dark shadow
			# pass first (offset right) so each tuft reads on the body.
			var tufts: Array = []
			for k in 2:
				var bx := c * TILE + 4 + k * 7 + rng.randi_range(-1, 1)
				var by := GRASS_OVER + rng.randi_range(6, 10)
				var out_lean := 0
				if left_edge and k == 0:
					out_lean = -1
				elif right_edge and k == 1:
					out_lean = 1
				for b in 5:
					tufts.append([bx + (b - 2), by, 13 - absi(b - 2) * 2 + rng.randi_range(-1, 1), b - 2 + out_lean])
			for t in tufts:
				_grass_blade(img, t[0] + 1, t[1], t[2] - 2, t[3], shadow, shadow, shadow, GRASS_OVER)
			for t in tufts:
				_grass_blade(img, t[0], t[1], t[2], t[3], body, light, shades[1], 0)
		# Outline the silhouette; blades poking into a filled row above are
		# left without outline so rows blend instead of striping.
		var data := img.get_data()
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				# Inner body pixels of fully surrounded cells are always opaque.
				if y >= GRASS_OVER + 1 and y < h - 4:
					var cc := x / TILE
					var lx := x % TILE
					if cells[r * cols + cc] == 1 and lx > 2 and lx < TILE - 3:
						continue
				var i := (y * w + x) * 4 + 3
				if data[i] > 25:
					continue
				if y < GRASS_OVER and r > 0 and cells[(r - 1) * cols + x / TILE] == 1:
					continue
				if (x > 0 and data[i - 4] > 127) or (x < w - 1 and data[i + 4] > 127) \
						or (y > 0 and data[i - w * 4] > 127) or (y < h - 1 and data[i + w * 4] > 127):
					img.set_pixel(x, y, outline)
		out.append(img)
	return out


## One blade from (x0, y0) upward; pixels above `min_y` are skipped.
static func _grass_blade(img: Image, x0: int, y0: int, hgt: int, lean: int, body: Color, light: Color, dark: Color, min_y: int) -> void:
	for i in hgt:
		var t := float(i) / float(hgt)
		var x := x0 + int(round(lean * t * t * 2.5))
		var y := y0 - i
		if y < min_y or x < 0 or x >= img.get_width():
			continue
		var c := body.lightened(0.12)
		if t > 0.72:
			c = light
		elif t < 0.3:
			c = dark
		img.set_pixel(x, y, c)


## 1 px outline around every opaque pixel (4-neighbourhood).
static func _outline(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()  # RGBA8: alpha at 4 * i + 3
	for y in h:
		for x in w:
			var i := (y * w + x) * 4 + 3
			if data[i] > 25:
				continue
			if (x > 0 and data[i - 4] > 127) or (x < w - 1 and data[i + 4] > 127) \
					or (y > 0 and data[i - w * 4] > 127) or (y < h - 1 and data[i + w * 4] > 127):
				img.set_pixel(x, y, col)


## Burnt ground left by a tall grass patch: ash with a few dying embers.
static func ash_patch(palette: Dictionary, cells: PackedByteArray, cols: int, rows: int, key: String) -> Image:
	var ck := "ash_%s_%d" % [key, palette.hash()]
	var ash := _c(palette, "ash", "#34302c")
	var ash_c := Color(ash, 0.92)
	var ash_d := Color(ash.darkened(0.35), 0.92)
	var ash_l := Color(ash.lightened(0.12), 0.92)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)
	var img := _new(cols * TILE, rows * TILE)
	for r in rows:
		for c in cols:
			if cells[r * cols + c] != 1:
				continue
			var open_l := c == 0 or cells[r * cols + c - 1] != 1
			var open_r := c == cols - 1 or cells[r * cols + c + 1] != 1
			var open_t := r == 0 or cells[(r - 1) * cols + c] != 1
			var open_b := r == rows - 1 or cells[(r + 1) * cols + c] != 1
			for y in TILE:
				for x in TILE:
					# Dithered, ragged border where the patch ends.
					var border := 9
					if open_l:
						border = mini(border, x)
					if open_r:
						border = mini(border, TILE - 1 - x)
					if open_t:
						border = mini(border, y)
					if open_b:
						border = mini(border, TILE - 1 - y)
					if border < 4 and rng.randf() > 0.25 + border * 0.22:
						continue
					var n := rng.randf()
					var col := ash_c
					if n > 0.8:
						col = ash_d
					elif n < 0.12:
						col = ash_l
					img.set_pixel(c * TILE + x, r * TILE + y, col)
			for e in 2:
				var ex := c * TILE + rng.randi_range(2, 13)
				var ey := r * TILE + rng.randi_range(2, 13)
				img.set_pixel(ex, ey, Color("#ff8a2f") if e == 0 else Color("#ffcf5a"))
				img.set_pixel(ex + 1, ey, Color("#b8401a"))
	return img


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


## Palm tree (v0.2, tropical arenas): curved ringed trunk and drooping
## fronds. Trunk base at (30, 74) of a 60x78 image.
static func palm(palette: Dictionary, variant: int) -> Texture2D:
	var key := "palm_%d_%s_%s" % [variant, palette.get("palm_leaves", palette.get("leaves", "")), palette.get("palm_trunk", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000 + variant * 13
	var w := 60
	var h := 78
	var img := _new(w, h)
	var trunk := _c(palette, "palm_trunk", "#a0794a")
	var leaves := _c(palette, "palm_leaves", String(palette.get("leaves", "#3f9a3a")))
	var lean := 7.0 if variant % 2 == 0 else -7.0
	var crown := Vector2(30.0 + lean, 24.0)
	# Trunk: quadratic curve from the base to the crown, ringed segments.
	for i in 52:
		var t := float(i) / 51.0
		var y := lerpf(74.0, crown.y + 2.0, t)
		var x := 30.0 + lean * t * t
		var half := lerpf(3.2, 2.2, t)
		for dx in range(int(floor(x - half)), int(ceil(x + half))):
			var c := trunk
			if dx <= x - half + 1.0:
				c = trunk.lightened(0.18)
			elif dx >= x + half - 1.5:
				c = trunk.darkened(0.3)
			if i % 5 == 0:
				c = c.darkened(0.25)
			img.set_pixel(clampi(dx, 0, w - 1), int(y), c)
	# Fronds radiating from the crown, drooping with length.
	var angles := [-172.0, -138.0, -100.0, -64.0, -28.0, 8.0, 158.0, 40.0]
	for a in angles:
		var dir := Vector2.from_angle(deg_to_rad(a + rng.randf_range(-6.0, 6.0)))
		var length := rng.randf_range(20.0, 27.0)
		var steps := int(length * 1.5)
		for s in steps:
			var t := float(s) / float(steps)
			var p := crown + dir * t * length + Vector2(0, 9.0 * t * t)
			var rad := 2.6 * sin(PI * (0.12 + 0.88 * t)) + 0.4
			var col := leaves if t < 0.75 else leaves.lightened(0.12)
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					if ox * ox + oy * oy <= rad * rad:
						var qx := int(p.x) + ox
						var qy := int(p.y) + oy
						if qx >= 0 and qx < w and qy >= 0 and qy < h:
							img.set_pixel(qx, qy, col.darkened(0.18) if oy > 0 else col)
			# Light midrib.
			var mx := int(p.x)
			var my := int(p.y)
			if mx >= 0 and mx < w and my >= 0 and my < h and t > 0.1:
				img.set_pixel(mx, my, leaves.lightened(0.3))
	# Coconuts under the crown.
	for k in 3:
		var cp := crown + Vector2(-3.0 + k * 3.0, 4.0 + (k % 2))
		_blob(img, cp.x, cp.y, 2.0, 2.0, Color("#6b4a2b"), Color("#3a2716"), rng, 0.0)
	_outline(img, leaves.darkened(0.65))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Columnar basalt wall (v0.2, volcanic arenas): hexagonal column tops
## seen from above plus a short front face. Same footprint and top band as
## wall() so collision and y-sorting are unchanged.
static func basalt_wall(palette: Dictionary, w: int, h: int) -> Texture2D:
	var key := "basalt_%d_%d_%s" % [w, h, palette.get("wall", "")]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 13 + h * 5
	var top_h := 6
	var total := h + top_h
	var face := mini(10, total / 2)
	var img := _new(w, total)
	var base := _c(palette, "wall", "#433b3e")
	var top := base.lightened(0.22)
	var seam := base.darkened(0.45)
	var glow := _c(palette, "lava", "#ff6a1a")
	# Top surface: polygonal column tops (jittered-grid Voronoi cells).
	var cs := 7
	var gx_n := w / cs + 2
	var gy_n := (total - face) / cs + 2
	var seeds := PackedVector2Array()
	var shade := PackedFloat32Array()
	for gy in gy_n:
		for gx in gx_n:
			seeds.append(Vector2((gx + rng.randf_range(0.2, 0.8)) * cs, (gy + rng.randf_range(0.2, 0.8)) * cs))
			shade.append(rng.randf_range(-0.08, 0.1))
	for y in total - face:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := int(p.x / cs)
			var cy := int(p.y / cs)
			var d1 := INF
			var d2 := INF
			var best := 0
			for oy in range(maxi(cy - 1, 0), mini(cy + 2, gy_n)):
				for ox in range(maxi(cx - 1, 0), mini(cx + 2, gx_n)):
					var si := oy * gx_n + ox
					var d := p.distance_to(seeds[si])
					if d < d1:
						d2 = d1
						d1 = d
						best = si
					elif d < d2:
						d2 = d
			if d2 - d1 < 1.1:
				img.set_pixel(x, y, seam)
				continue
			var sh := shade[best]
			var c := top.lightened(sh) if sh > 0.0 else top.darkened(-sh)
			var rel := p - seeds[best]
			if rel.x + rel.y < -3.0:
				c = c.lightened(0.1)  # lit top-left of each column
			elif rel.x + rel.y > 3.5:
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	# Front face: the columns' sides, darker toward the ground.
	var seams := PackedByteArray()
	seams.resize(w)
	var sx := rng.randi_range(2, 5)
	while sx < w:
		seams[sx] = 1
		sx += rng.randi_range(5, 8)
	for y in range(total - face, total):
		var k := float(y - (total - face)) / float(face)
		for x in w:
			var c := base.darkened(0.1 + 0.25 * k)
			var m := 0 if seams[x] == 1 else (1 if x > 0 and seams[x - 1] == 1 else 2)
			if m == 0:
				c = seam
				if k > 0.6 and rng.randf() < 0.35:
					c = glow.darkened(0.2)  # magma glimpsed through the cracks
			elif m == 1:
				c = c.lightened(0.12)
			elif y == total - face:
				c = base.lightened(0.05)
			img.set_pixel(x, y, c)
	var outline := base.darkened(0.7)
	for y in total:
		for x in w:
			if x == 0 or x == w - 1 or y == 0 or y == total - 1:
				img.set_pixel(x, y, outline)
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
