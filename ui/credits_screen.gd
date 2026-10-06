extends Control
## CRÉDITOS: generated from the credits files shipped with the sprites, so
## every artist of every used asset is always listed.


func _ready() -> void:
	UITheme.screen_root(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var back := UITheme.make_button("‹ Voltar", Vector2(150, 54), 22)
	back.pressed.connect(func(): Game.goto("main_menu"))
	header.add_child(back)
	header.add_child(UITheme.make_label("CRÉDITOS", 38, UITheme.ACCENT))
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 18)
	text.text = _build_text()
	scroll.add_child(text)


func _build_text() -> String:
	var s := PackedStringArray()
	s.append("[b]Clash of Mon[/b] é um fangame [b]gratuito e não-comercial[/b]. Pokémon e todos os nomes relacionados são marcas de Nintendo, Creatures Inc. e GAME FREAK inc. Este projeto não é afiliado nem endossado por eles.")
	s.append("")
	s.append("[b]Sprites e retratos:[/b] PMDCollab / SpriteCollab — https://github.com/PMDCollab/SpriteCollab (http://sprites.pmdcollab.org/)")
	s.append("Contribuições da comunidade: CC BY-NC 4.0 / licenças PMDCollab (crédito obrigatório, uso não-comercial). Sprites [color=#ffd23f]OFICIAIS[/color] (Spike Chunsoft, de Pokémon Mystery Dungeon) não são cobertos por licença Creative Commons e são usados apenas neste contexto de fã, sem fins lucrativos. Nenhum sprite foi redesenhado ou alterado.")
	s.append("")
	for id in GameData.roster:
		var def := GameData.get_pokemon(id)
		for fid in def.forms.keys():
			var form: FormDef = def.forms[fid]
			s.append("[font_size=22][b]%s[/b][/font_size]  [color=#9aa6b8]%s[/color]" % [form.name, form.sprite_folder.replace("res://assets/pmd/", "")])
			s.append(CreditsDB.summary_bbcode(form.sprite_folder))
			if form.portrait != "":
				s.append("[i]Retrato[/i]")
				s.append(CreditsDB.summary_bbcode(form.portrait.get_base_dir(), PackedStringArray(["Normal"])))
			s.append("")
	s.append("[b]Arte das arenas, efeitos visuais e sons:[/b] gerados proceduralmente por código neste projeto.")
	s.append("[b]Motor:[/b] Godot Engine (MIT) — https://godotengine.org")
	s.append("")
	s.append("Lista completa e detalhada: CREDITS.md no repositório.")
	return "\n".join(s)
