class_name PauseOverlay
extends Control
## Pause menu (works while the tree is paused).

var match_node: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := UITheme.make_label("PAUSA", 40, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := UITheme.make_button("Continuar")
	resume.pressed.connect(func(): match_node.toggle_pause())
	box.add_child(resume)
	var restart := UITheme.make_button("Reiniciar luta")
	restart.pressed.connect(func(): match_node.restart())
	box.add_child(restart)
	var hit := CheckButton.new()
	hit.text = "Mostrar hitboxes"
	hit.button_pressed = Settings.show_hitboxes
	hit.toggled.connect(func(v): Settings.set_value("show_hitboxes", v))
	box.add_child(hit)
	var dbg := CheckButton.new()
	dbg.text = "Modo debug"
	dbg.button_pressed = Settings.debug_overlay
	dbg.toggled.connect(func(v): Settings.set_value("debug_overlay", v))
	box.add_child(dbg)
	var quit := UITheme.make_button("Sair para o menu")
	quit.pressed.connect(func(): match_node.quit_to_menu())
	box.add_child(quit)
	visibility_changed.connect(func(): if visible: resume.grab_focus())
