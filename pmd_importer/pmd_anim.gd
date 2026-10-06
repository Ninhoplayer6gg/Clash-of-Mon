class_name PMDAnim
extends RefCounted
## One animation parsed from a SpriteCollab AnimData.xml entry.
##
## Sheets are laid out as columns = frames, rows = directions. PMD direction
## rows are ordered: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft.
## Durations are in game ticks (1/60 s), as in the original games.

const TICK := 1.0 / 60.0

## Body markers stored in the *-Offsets.png sheets.
enum Point { HEAD, CENTER, HAND_R, HAND_L }

var name := ""
var index := -1
var copy_of := ""
var frame_size := Vector2i.ZERO
var durations := PackedInt32Array()
var rush_frame := -1
var hit_frame := -1
var return_frame := -1
var texture: Texture2D
var offsets_path := ""
var shadow_path := ""
var rows := 1
var columns := 1
## Precomputed start tick of every frame (same length as durations) and total.
var frame_starts := PackedInt32Array()
var total_ticks := 0

## Lazy-loaded marker data: offsets[row][frame] = PackedVector2Array(4) relative
## to the frame centre. Vector2.INF means "marker hidden in this frame".
var _offsets: Array = []
var _offsets_loaded := false


func frame_count() -> int:
	return durations.size()


func duration_seconds() -> float:
	return total_ticks * TICK


## Time (seconds, at speed 1) at which the HitFrame starts. Falls back to the
## middle of the animation when the XML does not define a HitFrame.
func hit_time() -> float:
	if hit_frame >= 0 and hit_frame < frame_starts.size():
		return frame_starts[hit_frame] * TICK
	return total_ticks * TICK * 0.5


func rush_time() -> float:
	if rush_frame >= 0 and rush_frame < frame_starts.size():
		return frame_starts[rush_frame] * TICK
	return 0.0


func return_time() -> float:
	if return_frame >= 0 and return_frame < frame_starts.size():
		return frame_starts[return_frame] * TICK
	return total_ticks * TICK


## Frame index shown at `ticks` since the start (looping or clamped).
func frame_at_tick(ticks: int, loop: bool) -> int:
	if total_ticks <= 0:
		return 0
	var t := ticks
	if loop:
		t = posmod(ticks, total_ticks)
	elif t >= total_ticks:
		return durations.size() - 1
	# Frame counts are tiny (<= ~16), a linear scan beats anything clever.
	for i in range(durations.size() - 1, -1, -1):
		if t >= frame_starts[i]:
			return i
	return 0


func row_for_direction(dir_index: int) -> int:
	if rows <= 1:
		return 0
	return clampi(dir_index, 0, rows - 1)


func region_for(dir_index: int, frame: int) -> Rect2:
	var row := row_for_direction(dir_index)
	return Rect2(frame * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)


## Returns a body marker relative to the frame centre, or Vector2.INF.
func get_point(dir_index: int, frame: int, point: int) -> Vector2:
	if not _offsets_loaded:
		_load_offsets()
	if _offsets.is_empty():
		return Vector2.INF
	var row := row_for_direction(dir_index)
	if row >= _offsets.size():
		return Vector2.INF
	var frames: Array = _offsets[row]
	if frame < 0 or frame >= frames.size():
		return Vector2.INF
	var pts: PackedVector2Array = frames[frame]
	return pts[point]


## Best "emission" point for projectiles: hands at the hit frame, then head,
## then centre. Relative to the frame centre (sprite space).
func get_emit_point(dir_index: int) -> Vector2:
	var f := maxi(hit_frame, 0)
	for p in [Point.HAND_R, Point.HAND_L, Point.HEAD, Point.CENTER]:
		var v := get_point(dir_index, f, p)
		if v != Vector2.INF:
			return v
	return Vector2.INF


func _load_offsets() -> void:
	_offsets_loaded = true
	if offsets_path == "" or not ResourceLoader.exists(offsets_path):
		return
	var tex := load(offsets_path) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	_offsets = PMDSpriteImporter.parse_offsets_image(img, frame_size, rows, durations.size())
