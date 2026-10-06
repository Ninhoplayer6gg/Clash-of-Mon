class_name MatchCamera
extends Camera2D
## Top-down follow camera: smooth follow with slight look-ahead, zoom that
## keeps a minimum visible world area on any aspect ratio (16:9, 18:9,
## 19.5:9, tablets), arena limits and lightweight screen shake.

const MIN_VISIBLE := Vector2(480, 270)

var target: Node2D
var lookahead := 26.0
var _shake := 0.0
var _shake_time := 0.0
var _base_offset := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	get_viewport().size_changed.connect(_fit_zoom)
	_fit_zoom()


func set_bounds(r: Rect2, margin: float = 48.0) -> void:
	limit_left = int(r.position.x - margin)
	limit_top = int(r.position.y - margin)
	limit_right = int(r.end.x + margin)
	limit_bottom = int(r.end.y + margin)


func _fit_zoom() -> void:
	var vs := get_viewport_rect().size
	var z := minf(vs.x / MIN_VISIBLE.x, vs.y / MIN_VISIBLE.y)
	zoom = Vector2(z, z)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position
		reset_smoothing()


func shake(amount: float, time: float) -> void:
	_shake = maxf(_shake, amount)
	_shake_time = maxf(_shake_time, time)


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var ahead := Vector2.ZERO
		if target is Fighter:
			var f := target as Fighter
			ahead = f.velocity.limit_length(lookahead * 4.0) * 0.25
		global_position = target.global_position + ahead
	if _shake_time > 0.0:
		_shake_time -= delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, 0.25)
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
