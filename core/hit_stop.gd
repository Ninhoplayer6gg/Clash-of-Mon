class_name HitStop
extends Node
## Game-feel time dips owned by the match: a short freeze on heavy hits that
## involve the local player and a slow-motion + camera punch-in on the
## match-deciding KO. Implemented with Engine.time_scale, timed on the REAL
## clock (Time.get_ticks_usec) so it ignores the time scale it sets.
##
## Safety: Engine.time_scale is always put back to 1.0 when the effect
## ends, when the tree pauses (never active during pause), when cancel() is
## called, and when this node leaves the tree or is freed (scene change,
## restart, match freed mid-effect).

const FREEZE_SCALE := 0.05
const HEAVY_POWER := 300.0
const COOLDOWN_USEC := 120000  # gap between two freezes (no stutter chains)

## Off when Settings.hit_stop is off, in headless runs (bots/tests: keeps
## simulations independent from wall-clock time) or without a local player.
var enabled := true
var camera: MatchCamera
var slowmo_zoom := 0.16

var _active := false
var _slowmo := false
var _start_usec := 0
var _end_usec := 0
var _ready_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	return _active


func is_slowmo() -> bool:
	return _active and _slowmo


## Hit feedback hook: freezes 40–90 ms scaled by the hit power.
func on_heavy_hit(power: float) -> void:
	if power < HEAVY_POWER:
		return
	var k := clampf((power - HEAVY_POWER) / 400.0, 0.0, 1.0)
	freeze(lerpf(0.04, 0.09, k))


## Near-freeze for `seconds` of real time (ignored while a slow-motion runs).
func freeze(seconds: float) -> void:
	if not _can_start() or _slowmo:
		return
	var now := Time.get_ticks_usec()
	if not _active and now < _ready_usec:
		return
	_begin(now, seconds, FREEZE_SCALE, false)


## Dramatic slow motion (match-deciding KO) with a slight camera zoom.
func slowmo(seconds: float = 0.55, time_scale: float = 0.3) -> void:
	if not _can_start():
		return
	_begin(Time.get_ticks_usec(), seconds, time_scale, true)


## Immediately restores normal time (and camera zoom).
func cancel() -> void:
	_restore()


func _can_start() -> bool:
	return enabled and is_inside_tree() and not get_tree().paused


func _begin(now: int, seconds: float, ts: float, slow: bool) -> void:
	var end := now + int(seconds * 1000000.0)
	if _active and end < _end_usec and not slow:
		return  # a longer effect is already running
	_active = true
	_slowmo = slow
	_start_usec = now
	_end_usec = end
	Engine.time_scale = ts
	set_process(true)


func _process(_delta: float) -> void:
	if not _active:
		set_process(false)
		return
	if get_tree().paused:
		_restore()
		return
	var now := Time.get_ticks_usec()
	if now >= _end_usec:
		_restore()
		return
	if _slowmo and camera and is_instance_valid(camera):
		var t := float(now - _start_usec) / maxf(float(_end_usec - _start_usec), 1.0)
		var env := minf(1.0, t / 0.2) * (1.0 - smoothstep(0.6, 1.0, t))
		camera.set_zoom_mult(1.0 + slowmo_zoom * env)


func _restore() -> void:
	var was_slow := _slowmo
	if _active or Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	if _active and not was_slow:
		_ready_usec = Time.get_ticks_usec() + COOLDOWN_USEC
	_active = false
	_slowmo = false
	if was_slow and camera and is_instance_valid(camera):
		camera.set_zoom_mult(1.0)
	set_process(false)


func _exit_tree() -> void:
	_restore()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _active:
		Engine.time_scale = 1.0
