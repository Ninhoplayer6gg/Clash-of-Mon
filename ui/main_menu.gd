extends Control
## Title screen: JOGAR, POKÉMON, TREINO, CONFIGURAÇÕES, CRÉDITOS.
## The background parades the roster using the PMD animator.

var _parade: Array = []  # [PMDAnimator, speed]
var _parade_root: Control


func _ready() -> void:
	UITheme.screen_root(self)
	_parade_root = Control.new()
	_parade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parade_root)
	_build_parade()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := UITheme.make_label("CLASH OF MON", 72, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	var sub := UITheme.make_label("Arena fighter Pokémon • fangame gratuito e não-comercial", 18, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)
	var buttons := [
		["JOGAR", func(): Game.goto("select", {"mode": "play"})],
		["POKÉMON", func(): Game.goto("pokedex")],
		["TREINO", func(): Game.goto("select", {"mode": "training"})],
		["CONFIGURAÇÕES", func(): Game.goto("settings")],
		["CRÉDITOS", func(): Game.goto("credits")],
	]
	var first: Button = null
	for b in buttons:
		var btn := UITheme.make_button(b[0], Vector2(340, 62), 28)
		btn.pressed.connect(b[1])
		box.add_child(btn)
		if first == null:
			first = btn
	first.grab_focus()
	var foot := UITheme.make_label("Pokémon © Nintendo / Creatures / GAME FREAK. Sprites: PMDCollab SpriteCollab (ver Créditos). Projeto de fã sem fins lucrativos.", 13, UITheme.MUTED)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position.y -= 28
	add_child(foot)
	var ver := UITheme.make_label("v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 13, UITheme.MUTED)
	ver.position = Vector2(12, 8)
	add_child(ver)


func _build_parade() -> void:
	var vs := get_viewport_rect().size
	var i := 0
	for id in GameData.roster:
		var def := GameData.get_pokemon(id)
		var form := def.base_form()
		var lib := AnimLibrary.new(PMDSpriteImporter.load_sprite_set(form.sprite_folder), form.anim_map)
		var holder := Node2D.new()
		holder.scale = Vector2(3, 3)
		holder.position = Vector2(-120 - i * 230, vs.y - 70)
		_parade_root.add_child(holder)
		var anim := PMDAnimator.new()
		anim.setup(lib)
		anim.set_direction_vector(Vector2.RIGHT)
		anim.play("walk")
		anim.modulate = Color(1, 1, 1, 0.55)
		holder.add_child(anim)
		_parade.append([holder, anim, 60.0])
		i += 1


func _process(delta: float) -> void:
	var vs := get_viewport_rect().size
	for p in _parade:
		var holder: Node2D = p[0]
		var anim: PMDAnimator = p[1]
		holder.position.x += p[2] * delta
		holder.position.y = vs.y - 70
		if holder.position.x > vs.x + 120:
			holder.position.x -= vs.x + 240 + 230 * 2
		anim.advance(delta)
