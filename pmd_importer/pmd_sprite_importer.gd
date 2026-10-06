class_name PMDSpriteImporter
extends RefCounted
## PMD Sprite Importer
##
## Reads a SpriteCollab sprite folder (AnimData.xml + <Anim>-Anim.png +
## <Anim>-Offsets.png [+ <Anim>-Shadow.png]) and builds a PMDSpriteSet that
## the animation layer can play directly. No spritesheet is rebuilt by hand:
## frame sizes, frame counts, durations, directions, CopyOf aliases,
## Rush/Hit/Return frames and body markers all come from the source data.
##
## Results are cached per folder so several fighters of the same species share
## one set of textures.

const DIRECTION_COUNT := 8
const _OFFSET_COLORS := {
	# Marker colour -> PMDAnim.Point
	Color8(0, 0, 0): PMDAnim.Point.HEAD,
	Color8(0, 255, 0): PMDAnim.Point.CENTER,
	Color8(255, 0, 0): PMDAnim.Point.HAND_R,
	Color8(0, 0, 255): PMDAnim.Point.HAND_L,
}

static var _cache := {}


static func load_sprite_set(folder: String) -> PMDSpriteSet:
	folder = folder.trim_suffix("/")
	if _cache.has(folder):
		return _cache[folder]
	var sprite_set := PMDSpriteSet.new()
	sprite_set.folder = folder
	var xml_path := folder + "/AnimData.xml"
	if not FileAccess.file_exists(xml_path):
		push_warning("PMDSpriteImporter: missing %s" % xml_path)
		_cache[folder] = sprite_set
		return sprite_set
	_parse_anim_data(xml_path, sprite_set)
	_resolve_copies(sprite_set)
	_attach_textures(sprite_set)
	_read_ground_offset(sprite_set)
	sprite_set.credits = parse_credits(folder + "/credits.txt")
	_cache[folder] = sprite_set
	return sprite_set


static func clear_cache() -> void:
	_cache.clear()


static func is_cached(folder: String) -> bool:
	return _cache.has(folder.trim_suffix("/"))


# --------------------------------------------------------------------------
# AnimData.xml
# --------------------------------------------------------------------------

static func _parse_anim_data(xml_path: String, sprite_set: PMDSpriteSet) -> void:
	var parser := XMLParser.new()
	var err := parser.open(xml_path)
	if err != OK:
		push_warning("PMDSpriteImporter: cannot open %s (%d)" % [xml_path, err])
		return
	var stack: Array[String] = []
	var anim: PMDAnim = null
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				if tag == "Anim":
					anim = PMDAnim.new()
				if not parser.is_empty():
					stack.append(tag)
			XMLParser.NODE_ELEMENT_END:
				var tag := parser.get_node_name()
				if tag == "Anim" and anim != null:
					if anim.name != "":
						sprite_set.anims[anim.name] = anim
					anim = null
				if not stack.is_empty():
					stack.pop_back()
			XMLParser.NODE_TEXT:
				var text := parser.get_node_data().strip_edges()
				if text == "" or stack.is_empty():
					continue
				var tag: String = stack[-1]
				if anim == null:
					if tag == "ShadowSize":
						sprite_set.shadow_size = int(text)
					continue
				match tag:
					"Name": anim.name = text
					"Index": anim.index = int(text)
					"CopyOf": anim.copy_of = text
					"FrameWidth": anim.frame_size.x = int(text)
					"FrameHeight": anim.frame_size.y = int(text)
					"RushFrame": anim.rush_frame = int(text)
					"HitFrame": anim.hit_frame = int(text)
					"ReturnFrame": anim.return_frame = int(text)
					"Duration": anim.durations.append(int(text))


static func _resolve_copies(sprite_set: PMDSpriteSet) -> void:
	for anim_name in sprite_set.anims.keys():
		var a: PMDAnim = sprite_set.anims[anim_name]
		var guard := 0
		var src_name := a.copy_of
		while src_name != "" and guard < 8:
			var src: PMDAnim = sprite_set.anims.get(src_name)
			if src == null:
				break
			if src.copy_of == "":
				a.frame_size = src.frame_size
				a.durations = src.durations.duplicate()
				a.rush_frame = src.rush_frame
				a.hit_frame = src.hit_frame
				a.return_frame = src.return_frame
				break
			src_name = src.copy_of
			guard += 1


static func _attach_textures(sprite_set: PMDSpriteSet) -> void:
	var dead: Array[String] = []
	for anim_name in sprite_set.anims.keys():
		var a: PMDAnim = sprite_set.anims[anim_name]
		# CopyOf animations share the source sheet (follow alias chains).
		var sheet_name := a.copy_of if a.copy_of != "" else a.name
		var guard := 0
		while guard < 8:
			var src: PMDAnim = sprite_set.anims.get(sheet_name)
			if src == null or src.copy_of == "":
				break
			sheet_name = src.copy_of
			guard += 1
		var tex_path := "%s/%s-Anim.png" % [sprite_set.folder, sheet_name]
		if not ResourceLoader.exists(tex_path):
			dead.append(anim_name)
			continue
		a.texture = load(tex_path)
		a.offsets_path = "%s/%s-Offsets.png" % [sprite_set.folder, sheet_name]
		a.shadow_path = "%s/%s-Shadow.png" % [sprite_set.folder, sheet_name]
		if a.durations.is_empty() or a.frame_size.x <= 0 or a.frame_size.y <= 0:
			dead.append(anim_name)
			continue
		var tex_size := a.texture.get_size()
		a.columns = maxi(1, int(tex_size.x) / a.frame_size.x)
		a.rows = maxi(1, int(tex_size.y) / a.frame_size.y)
		# Some sheets carry fewer columns than durations; trust the sheet.
		if a.durations.size() > a.columns:
			a.durations.resize(a.columns)
		a.frame_starts.resize(a.durations.size())
		var acc := 0
		for i in a.durations.size():
			a.frame_starts[i] = acc
			acc += maxi(1, a.durations[i])
		a.total_ticks = acc
	for d in dead:
		sprite_set.anims.erase(d)


static func _read_ground_offset(sprite_set: PMDSpriteSet) -> void:
	# Shadow sheets are optional (this project ships without them). When
	# present, the white pixel marks the exact ground point.
	var idle: PMDAnim = sprite_set.anims.get("Idle")
	if idle == null or not ResourceLoader.exists(idle.shadow_path):
		return
	var img := (load(idle.shadow_path) as Texture2D).get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var cell := img.get_region(Rect2i(Vector2i.ZERO, idle.frame_size))
	var used := cell.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := cell.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
				sprite_set.ground_offset = Vector2(x, y) - Vector2(idle.frame_size) * 0.5
				return


# --------------------------------------------------------------------------
# Offsets sheets
# --------------------------------------------------------------------------

## Returns offsets[row][frame] = PackedVector2Array(4) relative to frame centre.
static func parse_offsets_image(img: Image, frame_size: Vector2i, rows: int, frames: int) -> Array:
	var out: Array = []
	if frame_size.x <= 0 or frame_size.y <= 0:
		return out
	var half := Vector2(frame_size) * 0.5
	for r in rows:
		var row_arr: Array = []
		for f in frames:
			var pts := PackedVector2Array([Vector2.INF, Vector2.INF, Vector2.INF, Vector2.INF])
			var cell_rect := Rect2i(f * frame_size.x, r * frame_size.y, frame_size.x, frame_size.y)
			if cell_rect.end.x > img.get_width() or cell_rect.end.y > img.get_height():
				row_arr.append(pts)
				continue
			var cell := img.get_region(cell_rect)
			# Native bounding box first: only a handful of marker pixels exist.
			var used := cell.get_used_rect()
			for y in range(used.position.y, used.end.y):
				for x in range(used.position.x, used.end.x):
					var c := cell.get_pixel(x, y)
					if c.a < 0.5:
						continue
					var key := Color8(int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0)))
					if _OFFSET_COLORS.has(key):
						pts[_OFFSET_COLORS[key]] = Vector2(x, y) - half
			row_arr.append(pts)
		out.append(row_arr)
	return out


# --------------------------------------------------------------------------
# Credits
# --------------------------------------------------------------------------

## Parses a SpriteCollab credits.txt (tab separated:
## date, author id, CUR/OLD, license, comma separated animations).
static func parse_credits(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		return rows
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var cols := line.split("\t")
		if cols.size() < 5:
			continue
		rows.append({
			"date": cols[0],
			"author": cols[1],
			"status": cols[2],
			"license": cols[3],
			"anims": cols[4].split(","),
			"official": cols[1] == "CHUNSOFT",
		})
	return rows


# --------------------------------------------------------------------------
# Directions
# --------------------------------------------------------------------------

## Maps a vector (screen space, y down) to a PMD direction row.
static func direction_index(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return 0
	var deg := rad_to_deg(atan2(v.y, v.x))
	return posmod(int(round((90.0 - deg) / 45.0)), DIRECTION_COUNT)


## Unit vector for a PMD direction row.
static func direction_vector(index: int) -> Vector2:
	var deg := 90.0 - float(posmod(index, DIRECTION_COUNT)) * 45.0
	return Vector2.from_angle(deg_to_rad(deg))
