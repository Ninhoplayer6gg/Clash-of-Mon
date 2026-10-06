class_name PMDAnimator
extends Sprite2D
## Plays PMD animations on a single Sprite2D by moving its region rect.
## One draw call per fighter, no per-frame allocations.

signal finished(logical: String)

var library: AnimLibrary
var current := ""
var current_anim: PMDAnim
var dir_index := 0
var speed := 1.0
var loop := true
var _ticks_f := 0.0
var _frame := -1
var _done := false
var _hold_last := false


func _init() -> void:
	centered = true
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(p_library: AnimLibrary) -> void:
	library = p_library
	offset = -library.sprite_set.ground_offset
	current = ""
	play("idle")


func play(logical: String, p_speed: float = 1.0, restart: bool = false, p_loop: int = -1) -> void:
	if library == null:
		return
	var anim := library.get_anim(logical)
	if anim == null:
		return
	speed = p_speed
	if logical == current and anim == current_anim and not restart and not _done:
		return
	current = logical
	current_anim = anim
	loop = library.is_looping(logical) if p_loop < 0 else p_loop == 1
	_ticks_f = 0.0
	_frame = -1
	_done = false
	texture = anim.texture
	_apply_frame()


## Plays an animation stretched/compressed to last `seconds`.
func play_for(logical: String, seconds: float, restart: bool = true) -> void:
	if library == null:
		return
	var anim := library.get_anim(logical)
	if anim == null:
		return
	var dur := anim.duration_seconds()
	var spd := 1.0 if seconds <= 0.0 else clampf(dur / seconds, 0.35, 3.0)
	play(logical, spd, restart, 0)


func set_direction_vector(v: Vector2) -> void:
	if v.length_squared() < 0.0001:
		return
	var idx := PMDSpriteImporter.direction_index(v)
	if idx != dir_index:
		dir_index = idx
		_frame = -1
		_apply_frame()


func set_direction_index(idx: int) -> void:
	if idx != dir_index:
		dir_index = idx
		_frame = -1
		_apply_frame()


func advance(delta: float) -> void:
	if current_anim == null or _done:
		return
	_ticks_f += delta * 60.0 * speed
	if not loop and _ticks_f >= current_anim.total_ticks:
		_ticks_f = current_anim.total_ticks
		_done = true
		_apply_frame()
		finished.emit(current)
		return
	_apply_frame()


func is_done() -> bool:
	return _done


func current_frame() -> int:
	return maxi(_frame, 0)


## Body marker of the current frame in this node's local space.
func get_marker(point: int) -> Vector2:
	if current_anim == null:
		return Vector2.INF
	var p := current_anim.get_point(dir_index, current_frame(), point)
	if p == Vector2.INF:
		return p
	return p + offset


func _apply_frame() -> void:
	if current_anim == null:
		return
	var f := current_anim.frame_at_tick(int(_ticks_f), loop)
	if f == _frame:
		return
	_frame = f
	region_rect = current_anim.region_for(dir_index, f)
