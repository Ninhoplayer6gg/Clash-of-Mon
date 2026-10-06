class_name Hud
extends Control
## In-match HUD: player/enemy cards (portrait, HP, energy, statuses, passive),
## team bench with switch buttons (3v3), timer, announcements, pause button,
## and a skill bar with cooldowns when touch controls are hidden.

signal pause_pressed
signal switch_pressed(index: int)

var match_node: Node
var teams: Array = []
var _portraits: Array[TextureRect] = []
var _bench_buttons: Array[Button] = []
var _center_text := ""
var _center_time := 0.0
var _font: Font
var _pause_btn: Button
var _trail := [1.0, 1.0]  # delayed HP bars


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	_font = ThemeDB.fallback_font
	_pause_btn = Button.new()
	_pause_btn.text = "II"
	_pause_btn.custom_minimum_size = Vector2(56, 48)
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause_btn)
	get_viewport().size_changed.connect(_layout)


func setup(p_teams: Array) -> void:
	teams = p_teams
	for i in teams.size():
		var tr := TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(60, 60)
		tr.size = Vector2(60, 60)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 1:
			tr.flip_h = true
		add_child(tr)
		_portraits.append(tr)
	var player_team: TeamState = teams[0]
	if player_team.fighters.size() > 1:
		for i in player_team.fighters.size():
			var b := Button.new()
			b.custom_minimum_size = Vector2(54, 54)
			b.size = Vector2(54, 54)
			b.focus_mode = Control.FOCUS_NONE
			b.expand_icon = true
			b.icon = UITheme.portrait_texture(player_team.fighters[i].species)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var idx := i
			b.pressed.connect(func(): switch_pressed.emit(idx))
			add_child(b)
			_bench_buttons.append(b)
	for t in teams:
		refresh_team(t)
	_layout()


func refresh_team(team: TeamState) -> void:
	if team.index >= _portraits.size():
		return
	var f := team.active_fighter()
	if f:
		_portraits[team.index].texture = UITheme.portrait_texture(f.species, f.form.id)
	if not f.form_changed.is_connected(_on_form_changed):
		f.form_changed.connect(_on_form_changed)


func _on_form_changed(f: Fighter) -> void:
	if f.team < _portraits.size():
		_portraits[f.team].texture = UITheme.portrait_texture(f.species, f.form.id)


func _layout() -> void:
	var vs := get_viewport_rect().size
	_pause_btn.position = Vector2(vs.x * 0.5 + 64, 8)
	if _portraits.size() > 0:
		_portraits[0].position = Vector2(20, 14)
	if _portraits.size() > 1:
		_portraits[1].position = Vector2(vs.x - 80, 14)
	for i in _bench_buttons.size():
		_bench_buttons[i].position = Vector2(20 + i * 60, 102)


func set_center_text(t: String, duration: float) -> void:
	_center_text = t
	_center_time = duration


func _process(delta: float) -> void:
	if _center_time > 0.0:
		_center_time -= delta
	for i in teams.size():
		var f: Fighter = teams[i].active_fighter()
		if f:
			_trail[i] = move_toward(_trail[i], f.hp_ratio(), delta * 0.6) if _trail[i] > f.hp_ratio() else f.hp_ratio()
	_update_bench()
	queue_redraw()


func _update_bench() -> void:
	if _bench_buttons.is_empty():
		return
	var team: TeamState = teams[0]
	for i in _bench_buttons.size():
		var b := _bench_buttons[i]
		var f := team.fighters[i]
		b.disabled = not f.is_alive() or i == team.active or team.switch_cd > 0.0
		b.modulate = Color(0.35, 0.35, 0.35) if not f.is_alive() else (Color(1, 1, 0.75) if i == team.active else Color.WHITE)


func _draw() -> void:
	var vs := get_viewport_rect().size
	if teams.size() > 0:
		_draw_card(teams[0], Vector2(14, 10), false)
	if teams.size() > 1:
		_draw_card(teams[1], Vector2(vs.x - 14 - 360 - 70, 10), true)
	_draw_timer(vs)
	_draw_bench_overlays()
	if not Settings.use_touch_controls() and teams.size() > 0:
		_draw_skill_bar(teams[0].active_fighter(), vs)
	if _center_time > 0.0 and _center_text != "":
		var fs := 64
		var a := clampf(_center_time * 3.0, 0.0, 1.0)
		var sz := _font.get_string_size(_center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2((vs.x - sz.x) * 0.5, vs.y * 0.36)
		draw_string_outline(_font, p, _center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.85 * a))
		draw_string(_font, p, _center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.35, a))


func _draw_card(team: TeamState, origin: Vector2, mirrored: bool) -> void:
	var f := team.active_fighter()
	if f == null:
		return
	var w := 360.0
	var card := Rect2(origin, Vector2(w + 70, 84))
	draw_style_box(UITheme._box(Color(0.06, 0.08, 0.11, 0.72), Color(team.color, 0.7), 2, 12), card)
	var x0 := origin.x + (8.0 if mirrored else 76.0)
	var name_txt := f.form.name
	draw_string(_font, Vector2(x0, origin.y + 26), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	# Types
	var tx := x0 + _font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 10.0
	for t in f.types:
		var tn := GameData.type_name(t)
		var tw := _font.get_string_size(tn, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0
		draw_rect(Rect2(tx, origin.y + 11, tw, 18), GameData.type_color(t))
		draw_string(_font, Vector2(tx + 5, origin.y + 25), tn, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.08, 0.08))
		tx += tw + 4.0
	# HP
	var bar := Rect2(x0, origin.y + 34, w - 20, 16)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var trail: float = _trail[team.index] if team.index < _trail.size() else f.hp_ratio()
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * trail, bar.size.y)), Color(1.0, 0.85, 0.5, 0.8))
	var hp_col := Color(0.35, 0.9, 0.45) if f.hp_ratio() > 0.5 else (Color(1.0, 0.8, 0.25) if f.hp_ratio() > 0.25 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f.hp_ratio(), bar.size.y)), hp_col)
	var hp_txt := "%d / %d" % [f.hp, f.max_hp]
	draw_string_outline(_font, bar.position + Vector2(6, 13), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
	draw_string(_font, bar.position + Vector2(6, 13), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# Energy
	var eb := Rect2(x0, origin.y + 54, (w - 20) * 0.62, 8)
	draw_rect(eb, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(eb.position, Vector2(eb.size.x * clampf(f.energy / f.max_energy, 0.0, 1.0), eb.size.y)), Color(0.35, 0.8, 1.0))
	# Ultimate meter
	var ub := Rect2(eb.end.x + 8, origin.y + 54, (w - 20) * 0.38 - 8, 8)
	draw_rect(ub, Color(0, 0, 0, 0.6))
	var uc := Color(1.0, 0.85, 0.2) if f.ult_charge >= 100.0 else Color(0.85, 0.7, 0.25)
	draw_rect(Rect2(ub.position, Vector2(ub.size.x * f.ult_charge / 100.0, ub.size.y)), uc)
	# Status chips + passive
	var sx := x0
	for id in f.status.visible_ids():
		var d := GameData.status_def(id)
		var txt := String(d.get("short", id))
		var c := Color.from_string(String(d.get("color", "#ffffff")), Color.WHITE)
		draw_rect(Rect2(sx, origin.y + 66, 38, 15), c)
		draw_string(_font, Vector2(sx + 3, origin.y + 78), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.05))
		sx += 42.0
	var ptxt := f.passive.hud_text()
	if ptxt != "":
		var pt := "%s %s" % [f.passive.display_name, ptxt]
		draw_string(_font, Vector2(x0 + w - 30 - _font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, origin.y + 78), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.88, 1.0))
	if f.mega_enabled and not f.mega_used:
		var mt := "MEGA %d%%" % int(f.mega_charge)
		draw_string(_font, Vector2(sx + 4, origin.y + 78), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1.0, 0.9) if f.can_mega() else Color(0.5, 0.7, 0.7))
	elif f.transform_time > 0.0:
		draw_string(_font, Vector2(sx + 4, origin.y + 78), "MEGA %ds" % int(ceil(f.transform_time)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1.0, 0.9))
	# Remaining team members (dots)
	if team.fighters.size() > 1:
		for i in team.fighters.size():
			var alive := team.fighters[i].is_alive()
			var dc := Vector2(origin.x + (card.size.x - 16 - i * 16 if not mirrored else 16 + i * 16), origin.y + card.size.y + 10)
			draw_circle(dc, 6, Color(team.color, 0.9) if alive else Color(0.3, 0.3, 0.3, 0.8))
			draw_arc(dc, 6, 0, TAU, 16, Color.BLACK, 1.5)


func _draw_timer(vs: Vector2) -> void:
	if match_node == null:
		return
	var t: float = match_node.time_left
	var txt := "TREINO" if t < 0.0 else "%d:%02d" % [int(t) / 60, int(t) % 60]
	var fs := 26
	var sz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(Vector2((vs.x - sz.x) * 0.5 - 14, 12), Vector2(sz.x + 28, 38))
	draw_style_box(UITheme._box(Color(0.06, 0.08, 0.11, 0.75), Color(1, 1, 1, 0.25), 2, 18), r)
	var col := Color(1.0, 0.4, 0.35) if t >= 0.0 and t < 15.0 else Color.WHITE
	draw_string(_font, Vector2(r.position.x + 14, r.position.y + 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_bench_overlays() -> void:
	if _bench_buttons.is_empty():
		return
	var team: TeamState = teams[0]
	for i in _bench_buttons.size():
		var b := _bench_buttons[i]
		var f := team.fighters[i]
		var r := Rect2(b.position, b.size)
		draw_rect(Rect2(r.position + Vector2(4, r.size.y - 8), Vector2((r.size.x - 8) * f.hp_ratio(), 4)), Color(0.35, 0.9, 0.45))
		if not f.is_alive():
			draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), Color(1, 0.3, 0.3), 3.0)
			draw_line(Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8), Color(1, 0.3, 0.3), 3.0)
		elif i != team.active and team.switch_cd > 0.0:
			var txt := str(int(ceil(team.switch_cd)))
			draw_string_outline(_font, r.get_center() + Vector2(-6, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color.BLACK)
			draw_string(_font, r.get_center() + Vector2(-6, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if _bench_buttons.size() > 0:
		draw_string(_font, Vector2(24 + _bench_buttons.size() * 60, 136), "Q/E: trocar", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.MUTED)


## Desktop skill bar (keyboard/gamepad) with cooldowns and key hints.
func _draw_skill_bar(f: Fighter, vs: Vector2) -> void:
	if f == null:
		return
	var slots := ["basic", "skill1", "skill2", "skill3", "ult", "dash"]
	var keys := ["J/Clique", "K/1", "L/2", "U/3", "I/R", "Espaço"]
	var size := 62.0
	var gap := 10.0
	var total := slots.size() * size + (slots.size() - 1) * gap
	var x := (vs.x - total) * 0.5
	var y := vs.y - size - 26.0
	for i in slots.size():
		var slot: String = slots[i]
		var r := Rect2(x + i * (size + gap), y, size, size)
		var label := "»"
		var ring := Color(0.6, 0.95, 1.0)
		var frac := 0.0
		var ready := true
		if slot == "dash":
			frac = f.dash_cd / maxf(f._dash_cfg("cooldown", 0.55), 0.01)
			ready = f.dash_cd <= 0.0 and f.energy >= f._dash_cfg("energy_cost", 30.0)
		else:
			var ab := f.ability(slot)
			if ab == null:
				continue
			label = ab.icon
			ring = GameData.type_color(ab.move_type)
			frac = f.cooldown_ratio(slot)
			ready = f.is_ready(slot)
			if slot == "ult":
				frac = 1.0 - f.ult_charge / 100.0
		draw_style_box(UITheme._box(Color(0.06, 0.08, 0.11, 0.8), ring if ready else Color(0.4, 0.4, 0.45), 3, 10), r)
		if frac > 0.0:
			draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, (r.size.y - 6) * frac)), Color(0, 0, 0, 0.55))
		var sz := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(_font, r.get_center() + Vector2(-sz.x * 0.5, 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE if ready else Color(0.6, 0.6, 0.6))
		var kz := _font.get_string_size(keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(_font, Vector2(r.get_center().x - kz.x * 0.5, r.end.y + 16), keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.MUTED)
