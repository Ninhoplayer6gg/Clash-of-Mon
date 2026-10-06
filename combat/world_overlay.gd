class_name WorldOverlay
extends Node2D
## World-space overlay above everything: small HP/energy bars over fighters
## and floating combat text. Fixed pools, single canvas item.

const MAX_TEXTS := 28

var world: CombatWorld
var _texts: Array = []  # [pos, text, color, life, max, scale]
var _font: Font


func _ready() -> void:
	z_index = 12
	_font = ThemeDB.fallback_font


func add_damage(p: Vector2, amount: int, eff: String, on_player: bool) -> void:
	if not Settings.damage_numbers:
		return
	var col := Color(1, 1, 1)
	var sc := 1.0
	if eff == "super":
		col = Color(1.0, 0.75, 0.25)
		sc = 1.2
	elif eff == "resist":
		col = Color(0.7, 0.75, 0.85)
		sc = 0.9
	if on_player:
		col = col.lerp(Color(1.0, 0.45, 0.45), 0.6)
	add_text(p + Vector2(randf_range(-5, 5), 0), str(amount), col, sc)


func add_text(p: Vector2, text: String, col: Color, sc: float = 1.0) -> void:
	if _texts.size() >= MAX_TEXTS:
		_texts.pop_front()
	_texts.append([p, text, col, 0.75, 0.75, sc])


func _process(delta: float) -> void:
	var i := _texts.size() - 1
	while i >= 0:
		var t: Array = _texts[i]
		t[3] -= delta
		t[0].y -= 26.0 * delta
		if t[3] <= 0.0:
			_texts.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	for f in world.fighters:
		if not f.is_alive() or f.hidden_mode != "":
			continue
		if f.terrain_alpha < 0.3:  # terrain (v0.2): enemy concealed in tall grass
			continue
		_draw_bars(f)
	for t in _texts:
		var k: float = t[3] / t[4]
		var col: Color = t[2]
		col.a = clampf(k * 1.6, 0.0, 1.0)
		var size := int(9 * t[5])
		var pos: Vector2 = t[0] - Vector2(_font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0)
		draw_string_outline(_font, pos, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, col.a))
		draw_string(_font, pos, t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_bars(f: Fighter) -> void:
	var w := 26.0
	var top := f.position + Vector2(-w * 0.5, -f.body_height - 10.0) + f.animator.position
	draw_rect(Rect2(top - Vector2(1, 1), Vector2(w + 2, 5)), Color(0, 0, 0, 0.7))
	var hp_col := f.team_color if f.hp_ratio() > 0.3 else Color(1.0, 0.35, 0.3)
	draw_rect(Rect2(top, Vector2(w * f.hp_ratio(), 3)), hp_col)
	if f.is_player:
		draw_rect(Rect2(top + Vector2(0, 3), Vector2(w * clampf(f.energy / f.max_energy, 0.0, 1.0), 1)), Color(0.4, 0.9, 1.0))
	var ids := f.status.visible_ids()
	for j in ids.size():
		var c := Color.from_string(String(GameData.status_def(ids[j]).get("color", "#ffffff")), Color.WHITE)
		draw_rect(Rect2(top + Vector2(j * 5.0, -4.0), Vector2(4, 3)), c)
