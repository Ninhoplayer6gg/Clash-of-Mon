extends Control
## CONFIGURAÇÕES: performance, controls and accessibility options.


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
	header.add_child(UITheme.make_label("CONFIGURAÇÕES", 38, UITheme.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 10)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(a)
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(b)

	a.add_child(UITheme.make_label("Desempenho", 24, UITheme.ACCENT2))
	_option(a, "Taxa de quadros", ["30 FPS (economia)", "60 FPS"], 1 if Settings.target_fps >= 60 else 0,
		func(i): Settings.set_value("target_fps", 60 if i == 1 else 30))
	_option(a, "Qualidade gráfica", ["Baixa", "Média", "Alta"], Settings.quality,
		func(i): Settings.set_value("quality", i))
	_check(a, "Tremor de tela", "screen_shake")
	_check(a, "Números de dano", "damage_numbers")
	_check(a, "Mostrar FPS", "show_fps")
	_check(a, "Modo debug (F3)", "debug_overlay")
	_check(a, "Mostrar hitboxes (F4)", "show_hitboxes")

	b.add_child(UITheme.make_label("Controles", 24, UITheme.ACCENT2))
	var modes := ["auto", "on", "off"]
	_option(b, "Controles de toque", ["Automático", "Sempre", "Nunca"], maxi(0, modes.find(Settings.touch_controls)),
		func(i): Settings.set_value("touch_controls", modes[i]))
	_slider(b, "Tamanho dos botões", 0.75, 1.35, Settings.controls_scale, func(v): Settings.set_value("controls_scale", v))
	_slider(b, "Opacidade dos botões", 0.3, 1.0, Settings.controls_opacity, func(v): Settings.set_value("controls_opacity", v))
	_check(b, "Mira assistida (toque rápido)", "aim_assist")
	_check(b, "Vibração", "vibration")
	_slider(b, "Volume", 0.0, 1.0, Settings.sfx_volume, func(v): Settings.set_value("sfx_volume", v))
	var help := UITheme.make_label("Teclado: WASD move • mouse mira • J/clique ataque • K L U skills • I/R ultimate • Espaço dash • Q/E troca • M mega • Esc pausa\nGamepad: analógico esq. move • dir. mira • A ataque • X Y B skills • RB ultimate • LB/LT dash • D-pad troca", 14, UITheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(help)


func _option(parent: Control, label: String, items: Array, selected: int, cb: Callable) -> void:
	parent.add_child(UITheme.make_label(label, 18, UITheme.MUTED))
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 20)
	for it in items:
		o.add_item(it)
	o.select(selected)
	o.item_selected.connect(cb)
	parent.add_child(o)


func _check(parent: Control, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.add_theme_font_size_override("font_size", 19)
	c.button_pressed = bool(Settings.get(key))
	c.toggled.connect(func(v): Settings.set_value(key, v))
	parent.add_child(c)


func _slider(parent: Control, label: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := UITheme.make_label(label, 18, UITheme.MUTED)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.drag_ended.connect(func(_changed): cb.call(s.value))
	row.add_child(s)
