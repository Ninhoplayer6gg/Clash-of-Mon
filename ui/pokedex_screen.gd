extends Control
## "POKÉMON" screen: browse the roster, preview every imported PMD animation
## in all 8 directions, read stats, kit, passive, forms and sprite credits.

var _list: VBoxContainer
var _preview_holder: Node2D
var _animator: PMDAnimator
var _anim_box: HFlowContainer
var _info: RichTextLabel
var _abilities_box: VBoxContainer  # v0.2: one row (icon + text) per ability
var _info_tail: RichTextLabel
var _form_box: HBoxContainer
var _anim_label: Label
var _current_id := ""
var _current_form := ""
var _dir := 0
var _rot_timer := 0.0
var _auto_rotate := true


func _ready() -> void:
	UITheme.screen_root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	# Left list
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	var back := UITheme.make_button("‹ Voltar", Vector2(200, 50), 20)
	back.pressed.connect(func(): Game.goto("main_menu"))
	left.add_child(back)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	left.add_child(_list)
	for id in GameData.roster:
		var def := GameData.get_pokemon(id)
		var b := UITheme.make_button(def.name, Vector2(200, 54), 20)
		b.icon = UITheme.portrait_texture(def)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 40)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _select(id, ""))
		_list.add_child(b)
	# Middle preview
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(360, 0)
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(360, 300)
	mid.add_child(preview)
	var sub := Control.new()
	sub.clip_contents = true
	preview.add_child(sub)
	_preview_holder = Node2D.new()
	_preview_holder.position = Vector2(170, 190)
	_preview_holder.scale = Vector2(4, 4)
	sub.add_child(_preview_holder)
	_animator = PMDAnimator.new()
	_preview_holder.add_child(_animator)
	_animator.finished.connect(func(_n): _animator.play(_animator.current, 1.0, true, 0))
	_anim_label = UITheme.make_label("", 15, UITheme.MUTED)
	mid.add_child(_anim_label)
	var dir_row := HBoxContainer.new()
	dir_row.add_theme_constant_override("separation", 8)
	mid.add_child(dir_row)
	var rot_l := UITheme.make_button("⟲", Vector2(60, 46), 22)
	rot_l.pressed.connect(_rotate.bind(1))
	dir_row.add_child(rot_l)
	var rot_r := UITheme.make_button("⟳", Vector2(60, 46), 22)
	rot_r.pressed.connect(_rotate.bind(-1))
	dir_row.add_child(rot_r)
	var auto := UITheme.make_button("Girar", Vector2(100, 46), 18)
	auto.pressed.connect(func(): _auto_rotate = not _auto_rotate)
	dir_row.add_child(auto)
	_form_box = HBoxContainer.new()
	_form_box.add_theme_constant_override("separation", 8)
	mid.add_child(_form_box)
	var scroll_anims := ScrollContainer.new()
	scroll_anims.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_anims.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll_anims)
	_anim_box = HFlowContainer.new()
	_anim_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_anims.add_child(_anim_box)
	# Right info
	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(info_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 8)
	scroll.add_child(info_box)
	_info = _rich_label()
	info_box.add_child(_info)
	_abilities_box = VBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 8)
	info_box.add_child(_abilities_box)
	_info_tail = _rich_label()
	info_box.add_child(_info_tail)
	if not GameData.roster.is_empty():
		_select(GameData.roster[0], "")


func _select(id: String, form_id: String) -> void:
	_current_id = id
	var def := GameData.get_pokemon(id)
	var form := def.get_form(form_id)
	_current_form = form.id
	var folder := form.sprite_folder if not form.uses_pending_assets() else def.base_form().sprite_folder
	var sprite_set := PMDSpriteImporter.load_sprite_set(folder)
	var lib := AnimLibrary.new(sprite_set, form.anim_map)
	_animator.setup(lib)
	_animator.set_direction_index(_dir)
	for c in _form_box.get_children():
		c.queue_free()
	if def.forms.size() > 1:
		for fid in def.forms.keys():
			var fb := UITheme.make_button(def.forms[fid].name, Vector2(0, 42), 16)
			fb.toggle_mode = true
			fb.button_pressed = fid == _current_form
			fb.pressed.connect(func(): _select(id, fid))
			_form_box.add_child(fb)
	for c in _anim_box.get_children():
		c.queue_free()
	var names := sprite_set.anim_names()
	names.sort()
	for n in names:
		var ab := UITheme.make_button(n, Vector2(0, 38), 14)
		ab.pressed.connect(func(): _play_raw(n))
		_anim_box.add_child(ab)
	_play_raw("Idle")
	_info.text = _describe(def, form, sprite_set)
	_fill_abilities(form)
	_info_tail.text = _describe_assets(form, sprite_set)


func _play_raw(n: String) -> void:
	_animator.play(n, 1.0, true, 1 if n in ["Idle", "Walk", "Sleep"] else 0)
	var a := _animator.current_anim
	if a:
		_anim_label.text = "%s • %dx%d px • %d frames • %.2fs • %d direções%s" % [
			a.name, a.frame_size.x, a.frame_size.y, a.frame_count(), a.duration_seconds(), a.rows,
			(" • HitFrame %d" % a.hit_frame) if a.hit_frame >= 0 else ""]


func _rotate(step: int) -> void:
	_auto_rotate = false
	_set_dir(_dir + step)


func _set_dir(d: int) -> void:
	_dir = posmod(d, 8)
	_animator.set_direction_index(_dir)


func _process(delta: float) -> void:
	_animator.advance(delta)
	if _auto_rotate:
		_rot_timer += delta
		if _rot_timer > 1.2:
			_rot_timer = 0.0
			_set_dir(_dir - 1)


func _describe(def: PokemonDef, form: FormDef, sprite_set: PMDSpriteSet) -> String:
	var s := PackedStringArray()
	s.append("[font_size=28][b]%s[/b][/font_size]  #%03d  [color=#9aa6b8]%s • dificuldade %s[/color]" % [form.name, def.dex, def.role, "★".repeat(def.difficulty)])
	var types := PackedStringArray()
	for t in form.types:
		types.append("[color=%s]%s[/color]" % [GameData.type_color(t).to_html(false), GameData.type_name(t)])
	s.append("Tipos: " + " / ".join(types))
	s.append(def.description)
	s.append("")
	s.append("[b]Atributos[/b]")
	var table := "[table=3]"
	for k in [["hp", "HP"], ["attack", "Ataque"], ["defense", "Defesa"], ["sp_attack", "At. Esp."], ["sp_defense", "Def. Esp."], ["move_speed", "Velocidade"]]:
		var v := form.stat(k[0])
		var bar_max := 4400.0 if k[0] == "hp" else 150.0
		var n := int(clampf(v / bar_max, 0.0, 1.0) * 20.0)
		table += "[cell]%s  [/cell][cell][right]%d  [/right][/cell][cell][color=#ffd23f]%s[/color][color=#333a44]%s[/color][/cell]" % [k[1], int(v), "█".repeat(n), "█".repeat(20 - n)]
	table += "[/table]"
	s.append(table)
	s.append("")
	s.append("[b]Passiva — %s[/b]\n%s" % [form.passive.get("name", ""), form.passive.get("description", "")])
	return "\n".join(s)


## v0.2 polish: one row per ability with its procedural icon.
func _fill_abilities(form: FormDef) -> void:
	for c in _abilities_box.get_children():
		c.queue_free()
	var labels := {"basic": "Ataque básico", "skill1": "Skill 1", "skill2": "Skill 2", "skill3": "Skill 3", "ult": "Ultimate"}
	for slot in FormDef.SLOTS:
		var ab := form.ability(slot)
		if ab == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_abilities_box.add_child(row)
		var icon := _AbilityIcon.new()
		icon.shape = SkillIcons.shape_for(ab, form)
		icon.tint = SkillIcons.icon_color(ab.move_type)
		icon.ring = GameData.type_color(ab.move_type)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text := _rich_label()
		var cost := ("  • %d energia" % int(ab.energy)) if ab.energy > 0 else ""
		var cd := ("  • recarga %.1fs" % ab.cooldown) if slot != "ult" else "  • carga por dano"
		text.text = "[b]%s: %s[/b] [color=%s](%s)[/color][color=#9aa6b8]%s%s[/color]\n%s" % [
			labels[slot], ab.name, GameData.type_color(ab.move_type).to_html(false), GameData.type_name(ab.move_type), cd, cost, ab.description]
		row.add_child(text)


func _describe_assets(form: FormDef, sprite_set: PMDSpriteSet) -> String:
	var s := PackedStringArray()
	s.append("[b]Sprites (PMD Sprite Importer)[/b]: %d animações importadas de [code]%s[/code]" % [sprite_set.anims.size(), sprite_set.folder])
	s.append(CreditsDB.summary_bbcode(sprite_set.folder))
	if form.portrait != "":
		s.append("[b]Retrato[/b]")
		s.append(CreditsDB.summary_bbcode(form.portrait.get_base_dir(), PackedStringArray(["Normal"])))
	return "\n".join(s)


func _rich_label() -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("normal_font_size", 16)
	l.add_theme_font_size_override("bold_font_size", 17)
	return l


## Small round ability icon (type ring + SkillIcons shape).
class _AbilityIcon:
	extends Control
	var shape := "star"
	var tint := Color.WHITE
	var ring := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.06, 0.08, 0.11, 0.95))
		draw_arc(c, r - 1.0, 0, TAU, 32, ring, 2.0)
		SkillIcons.draw_icon(self, shape, c, r * 1.25, tint)
