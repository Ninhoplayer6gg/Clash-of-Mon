class_name ResultOverlay
extends Control
## Victory / defeat screen with per-Pokémon stats and quick restart.

var match_node: Node
var _title: Label
var _sub: Label
var _stats: VBoxContainer
var _rematch: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = UITheme.make_label("", 56, UITheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_sub = UITheme.make_label("", 20, UITheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	_stats = VBoxContainer.new()
	box.add_child(_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_rematch = UITheme.make_button("Revanche", Vector2(200, 60))
	_rematch.pressed.connect(func(): match_node.restart())
	row.add_child(_rematch)
	var change := UITheme.make_button("Trocar", Vector2(160, 60))
	change.pressed.connect(func():
		get_tree().paused = false
		Game.goto("select", {"mode": "training" if match_node.training else "play"}))
	row.add_child(change)
	var menu := UITheme.make_button("Menu", Vector2(160, 60))
	menu.pressed.connect(func(): match_node.quit_to_menu())
	row.add_child(menu)


func show_result(winner: int, reason: String, teams: Array) -> void:
	visible = true
	get_tree().paused = true
	if winner == 0:
		_title.text = "VITÓRIA!"
		_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif winner == 1:
		_title.text = "DERROTA"
		_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_title.text = "EMPATE"
		_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_sub.text = reason
	for c in _stats.get_children():
		c.queue_free()
	for t in teams:
		var head := UITheme.make_label("Você" if t.controller == "player" else "Adversário", 20, t.color)
		_stats.add_child(head)
		for f in t.fighters:
			var l := UITheme.make_label("  %s  —  dano causado %d  |  recebido %d  |  HP %d%%" % [f.species.name, f.damage_dealt, f.damage_taken, int(f.hp_ratio() * 100.0)], 17)
			_stats.add_child(l)
	_rematch.grab_focus()
