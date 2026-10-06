extends CanvasLayer
## Autoload "DebugOverlay": F3 toggles the full debug panel, F4 toggles
## hitbox/hurtbox drawing. Shows FPS, frame time, draw calls, objects,
## memory, pools and the local fighter's internal state.

var _label: Label
var _fps_label: Label
var _panel: ColorRect
var _acc := 0.0
var match_ref: Node = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0.45)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)
	_label = Label.new()
	_label.position = Vector2(14, 150)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	Settings.changed.connect(_refresh_visibility)
	_refresh_visibility()


func _refresh_visibility() -> void:
	_fps_label.visible = Settings.show_fps or Settings.debug_overlay
	_label.visible = Settings.debug_overlay
	_panel.visible = Settings.debug_overlay


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		Settings.set_value("debug_overlay", not Settings.debug_overlay)
	elif event.is_action_pressed("hitbox_toggle"):
		Settings.set_value("show_hitboxes", not Settings.show_hitboxes)


func _process(delta: float) -> void:
	if not (_fps_label.visible or _label.visible):
		return
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS  %.2f ms" % [fps, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0]
	# Top centre, under the match timer, so it never covers the HUD cards.
	_fps_label.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 70.0, 56.0)
	if not _label.visible:
		return
	var lines: PackedStringArray = []
	lines.append("frame %.2f ms | physics %.2f ms | alvo %d FPS" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Settings.target_fps])
	lines.append("draw calls %d | objetos %d | nós %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	lines.append("memória estática %.1f MB | vídeo %.1f MB" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	if match_ref and is_instance_valid(match_ref) and match_ref.has_method("debug_lines"):
		lines.append_array(match_ref.debug_lines())
	_label.text = "\n".join(lines)
	_panel.position = _label.position - Vector2(6, 4)
	_panel.size = _label.get_minimum_size() + Vector2(12, 8)
