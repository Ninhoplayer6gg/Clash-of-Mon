extends Control
## Team / opponent / arena selection for "JOGAR" and "TREINO".
## 1v1 = one Pokémon per side; 3v3 = three per side with switching.

var mode := "play"  # play | training
var team_size := 1
var my_team: Array[String] = []
var foe_team: Array[String] = []
var editing := 0  # 0 = my team, 1 = opponent
var arena_id := ""
var difficulty := 1
var opts := {
	"infinite_hp": false, "instant_cooldown": false, "show_hitboxes": false,
	"bot_behavior": "active", "mega_enabled": false,
}

var _cards := {}
var _my_slots: HBoxContainer
var _foe_slots: HBoxContainer
var _info: RichTextLabel
var _fight_btn: Button
var _tab_me: Button
var _tab_foe: Button
var _size_btns: Array[Button] = []


func _ready() -> void:
	mode = String(Game.screen_args.get("mode", "play"))
	var last: Dictionary = Game.last_selection.get(mode, {})
	team_size = int(last.get("size", 1))
	for id in last.get("me", ["pikachu"]):
		if GameData.get_pokemon(id):
			my_team.append(id)
	for id in last.get("foe", ["lucario"]):
		if GameData.get_pokemon(id):
			foe_team.append(id)
	arena_id = String(last.get("arena", GameData.arena_ids[0] if not GameData.arena_ids.is_empty() else ""))
	difficulty = int(last.get("difficulty", 1))
	var lo: Dictionary = last.get("opts", {})
	for k in lo.keys():
		opts[k] = lo[k]
	_trim_teams()
	_build()
	_refresh()


func _trim_teams() -> void:
	while my_team.size() > team_size:
		my_team.pop_back()
	while foe_team.size() > team_size:
		foe_team.pop_back()


func _build() -> void:
	UITheme.screen_root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var back := UITheme.make_button("‹ Voltar", Vector2(150, 54), 22)
	back.pressed.connect(func(): Game.goto("main_menu"))
	header.add_child(back)
	var title := UITheme.make_label("TREINO" if mode == "training" else "JOGAR", 38, UITheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for n in [1, 3]:
		var b := UITheme.make_button("%dv%d" % [n, n], Vector2(100, 54), 22)
		b.toggle_mode = true
		b.pressed.connect(func(): _set_team_size(n))
		header.add_child(b)
		_size_btns.append(b)
	# Body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# Left: tabs + roster grid
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	left.add_child(tabs)
	_tab_me = UITheme.make_button("SEU TIME", Vector2(200, 50), 20)
	_tab_me.toggle_mode = true
	_tab_me.pressed.connect(func(): _set_editing(0))
	tabs.add_child(_tab_me)
	_my_slots = HBoxContainer.new()
	tabs.add_child(_my_slots)
	_tab_foe = UITheme.make_button("ADVERSÁRIO", Vector2(200, 50), 20)
	_tab_foe.toggle_mode = true
	_tab_foe.pressed.connect(func(): _set_editing(1))
	tabs.add_child(_tab_foe)
	_foe_slots = HBoxContainer.new()
	tabs.add_child(_foe_slots)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(grid)
	for id in GameData.roster:
		var card := _make_card(id)
		grid.add_child(card)
		_cards[id] = card
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(0, 70)
	_info.add_theme_font_size_override("normal_font_size", 16)
	_info.add_theme_font_size_override("bold_font_size", 17)
	left.add_child(_info)
	# Right: options
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	col.add_child(UITheme.make_label("Arena", 18, UITheme.MUTED))
	var arena_opt := OptionButton.new()
	arena_opt.add_theme_font_size_override("font_size", 20)
	for i in GameData.arena_ids.size():
		var aid: String = GameData.arena_ids[i]
		arena_opt.add_item(String(GameData.get_arena(aid).get("name", aid)), i)
		if aid == arena_id:
			arena_opt.select(i)
	arena_opt.item_selected.connect(func(i): arena_id = GameData.arena_ids[i])
	col.add_child(arena_opt)
	col.add_child(UITheme.make_label("Dificuldade do bot", 18, UITheme.MUTED))
	var diff := OptionButton.new()
	diff.add_theme_font_size_override("font_size", 20)
	for n in ["Fácil", "Normal", "Difícil"]:
		diff.add_item(n)
	diff.select(difficulty)
	diff.item_selected.connect(func(i): difficulty = i)
	col.add_child(diff)
	if mode == "training":
		col.add_child(UITheme.make_label("Comportamento do bot", 18, UITheme.MUTED))
		var beh := OptionButton.new()
		beh.add_theme_font_size_override("font_size", 20)
		var behs := ["idle", "passive", "active"]
		for n in ["Parado", "Só se move", "Luta"]:
			beh.add_item(n)
		beh.select(behs.find(String(opts["bot_behavior"])))
		beh.item_selected.connect(func(i): opts["bot_behavior"] = behs[i])
		col.add_child(beh)
		_add_check(col, "HP infinito", "infinite_hp")
		_add_check(col, "Cooldown instantâneo", "instant_cooldown")
		_add_check(col, "Mostrar hitboxes", "show_hitboxes")
	_add_check(col, "Mega Evolução (experimental)", "mega_enabled")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_fight_btn = UITheme.make_button("LUTAR!", Vector2(300, 72), 32)
	_fight_btn.pressed.connect(_start)
	col.add_child(_fight_btn)


func _add_check(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 18)
	c.button_pressed = bool(opts.get(key, false))
	c.toggled.connect(func(v): opts[key] = v)
	parent.add_child(c)


func _make_card(id: String) -> Button:
	var def := GameData.get_pokemon(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 128)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.pressed.connect(func(): _pick(id))
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -6
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	b.add_child(hb)
	var tr := TextureRect.new()
	tr.texture = UITheme.portrait_texture(def)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(80, 80)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var n := UITheme.make_label(def.name, 22)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(n)
	var r := UITheme.make_label(def.role, 14, UITheme.MUTED)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(r)
	var types := HBoxContainer.new()
	types.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in def.base_form().types:
		var chip := UITheme.make_label(" %s " % GameData.type_name(t), 13, Color(0.08, 0.08, 0.08))
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameData.type_color(t)
		sb.set_corner_radius_all(4)
		chip.add_theme_stylebox_override("normal", sb)
		chip.add_theme_constant_override("outline_size", 0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		types.add_child(chip)
	vb.add_child(types)
	return b


func _set_team_size(n: int) -> void:
	team_size = n
	_trim_teams()
	_refresh()


func _set_editing(i: int) -> void:
	editing = i
	_refresh()


func _pick(id: String) -> void:
	var team := my_team if editing == 0 else foe_team
	if team_size == 1:
		team.clear()
		team.append(id)
	elif team.has(id):
		team.erase(id)
	elif team.size() < team_size:
		team.append(id)
	else:
		team.pop_front()
		team.append(id)
	# After filling your team, jump to the opponent tab automatically.
	if editing == 0 and team.size() >= team_size and foe_team.size() < team_size:
		editing = 1
	_show_info(id)
	_refresh()


func _show_info(id: String) -> void:
	var def := GameData.get_pokemon(id)
	var f := def.base_form()
	var txt := "[b]%s[/b] — %s\n%s\n[color=#9fd3ff]Passiva: %s[/color] — %s" % [def.name, def.role, def.description, f.passive.get("name", ""), f.passive.get("description", "")]
	_info.text = txt


func _refresh() -> void:
	for i in _size_btns.size():
		_size_btns[i].button_pressed = (i == 0 and team_size == 1) or (i == 1 and team_size == 3)
	_tab_me.button_pressed = editing == 0
	_tab_foe.button_pressed = editing == 1
	_fill_slots(_my_slots, my_team)
	_fill_slots(_foe_slots, foe_team)
	var team := my_team if editing == 0 else foe_team
	for id in _cards.keys():
		var card: Button = _cards[id]
		var idx := team.find(id)
		card.modulate = Color(1.0, 0.95, 0.7) if idx >= 0 else Color.WHITE
		card.add_theme_stylebox_override("normal", UITheme._box(Color(0.22, 0.2, 0.12) if idx >= 0 else Color(0.14, 0.17, 0.23), UITheme.ACCENT if idx >= 0 else Color(0.3, 0.36, 0.46), 3 if idx >= 0 else 2))
	_fight_btn.disabled = my_team.size() != team_size or foe_team.size() != team_size
	if _info.text == "" and not my_team.is_empty():
		_show_info(my_team[0])


func _fill_slots(box: HBoxContainer, team: Array[String]) -> void:
	for c in box.get_children():
		c.queue_free()
	for i in team_size:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if i < team.size():
			tr.texture = UITheme.portrait_texture(GameData.get_pokemon(team[i]))
		else:
			tr.modulate = Color(1, 1, 1, 0.2)
		box.add_child(tr)


func _start() -> void:
	var o := opts.duplicate()
	o["bot_difficulty"] = difficulty
	if mode != "training":
		o["infinite_hp"] = false
		o["instant_cooldown"] = false
		o["show_hitboxes"] = false
		o["bot_behavior"] = "active"
	Game.last_selection[mode] = {
		"size": team_size, "me": my_team.duplicate(), "foe": foe_team.duplicate(),
		"arena": arena_id, "difficulty": difficulty, "opts": opts.duplicate(),
	}
	var cfg := Game.make_config("%dv%d" % [team_size, team_size], my_team.duplicate(), foe_team.duplicate(), arena_id, mode == "training", o)
	Game.start_match(cfg)
