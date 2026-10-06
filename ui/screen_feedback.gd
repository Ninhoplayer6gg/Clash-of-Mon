class_name ScreenFeedback
extends Control
## Full-screen feedback for the local player, drawn as four thin edge
## strips with vertex colours (no shader, no full-screen fill):
##  - subtle pulsing red vignette while HP < 25%
##  - brief edge flash when a big hit lands on the player

const LOW_HP := 0.25
const BIG_HIT := 0.07  # fraction of max HP that counts as a big hit
const FLASH_TIME := 0.35

var match_node: Node
var _flash := 0.0
var _time := 0.0
var _alpha := 0.0
var _pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _cols := PackedColorArray([Color.RED, Color.RED, Color.RED, Color.RED])
var _no_uvs := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Listens to the combat world's hits.
func watch(world: CombatWorld) -> void:
	world.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(_attacker: Fighter, target: Fighter, amount: int, _eff: String) -> void:
	if target == null or not target.is_player:
		return
	if float(amount) >= float(target.max_hp) * BIG_HIT:
		_flash = 1.0


func _player() -> Fighter:
	if match_node == null or not is_instance_valid(match_node):
		return null
	return match_node.player_fighter()


## Vignette strength for an HP ratio at time t (0 when healthy).
static func low_hp_alpha(hp_ratio: float, t: float) -> float:
	if hp_ratio <= 0.0 or hp_ratio >= LOW_HP:
		return 0.0
	var depth := 1.0 - hp_ratio / LOW_HP
	return (0.2 + 0.18 * depth) * (0.75 + 0.25 * sin(t * (4.0 + 3.0 * depth)))


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	var f := _player()
	var a := 0.0
	if f and f.is_alive():
		a = low_hp_alpha(f.hp_ratio(), _time)
	a = maxf(a, 0.42 * _flash)
	if a > 0.004 or _alpha > 0.0:
		_alpha = a if a > 0.004 else 0.0
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var vs := get_viewport_rect().size
	var th := minf(vs.x, vs.y) * (0.14 + 0.05 * _flash)
	var outer := Color(0.85, 0.05, 0.04, _alpha)
	var inner := Color(0.85, 0.05, 0.04, 0.0)
	_strip(Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x - th, th), Vector2(th, th), outer, inner)
	_strip(Vector2(vs.x, vs.y), Vector2(0, vs.y), Vector2(th, vs.y - th), Vector2(vs.x - th, vs.y - th), outer, inner)
	_strip(Vector2(0, vs.y), Vector2(0, 0), Vector2(th, th), Vector2(th, vs.y - th), outer, inner)
	_strip(Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - th, vs.y - th), Vector2(vs.x - th, th), outer, inner)


func _strip(a: Vector2, b: Vector2, c: Vector2, d: Vector2, outer: Color, inner: Color) -> void:
	_pts[0] = a
	_pts[1] = b
	_pts[2] = c
	_pts[3] = d
	_cols[0] = outer
	_cols[1] = outer
	_cols[2] = inner
	_cols[3] = inner
	draw_primitive(_pts, _cols, _no_uvs)
