class_name TutorialOverlay
extends Control
## "Como jogar" card: explains the controls for touch or keyboard/gamepad.
## Shown automatically at the start of the first match (Settings key
## "tutorial_seen") and re-openable from the pause menu and Configurações.
## Any tap, click, key or gamepad button closes it.

signal closed

## Ignore input right after opening so a stray tap does not skip it.
const INPUT_GRACE_MS := 350

var touch_mode := true
var _panel: PanelContainer
var _rows: GridContainer
var _title: Label
var _footer: Label
var _opened_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title = UITheme.make_label("COMO JOGAR", 34, UITheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 14)
	_rows.add_theme_constant_override("v_separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rows)
	_footer = UITheme.make_label("", 18, UITheme.ACCENT2)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer)
	_fill()
	visibility_changed.connect(_on_visibility_changed)


## Rebuilds the text for touch (true) or keyboard/gamepad (false).
func open(p_touch: bool) -> void:
	touch_mode = p_touch
	if is_inside_tree() and _rows:
		_fill()
	visible = true
	_opened_at = Time.get_ticks_msec()


func _on_visibility_changed() -> void:
	if visible:
		_opened_at = Time.get_ticks_msec()


static func touch_lines() -> Array:
	return [
		["joystick", "Mover", "Toque e arraste na metade esquerda da tela: o analógico aparece sob o dedo."],
		["tap", "Toque rápido", "Num botão de habilidade = lança com mira automática no inimigo mais próximo."],
		["drag", "Arrastar para mirar", "Arraste a partir do botão e solte para lançar. Volte o dedo ao centro do botão para cancelar."],
		["fist", "Ataque básico", "O botão grande: segure para atacar sem parar, arraste para escolher a direção."],
		["dodge", "Dash  »", "Esquiva rápida com invencibilidade curta. Gasta energia (barra azul)."],
		["burst", "Ultimate", "O anel dourado enche ao causar e receber dano. Quando brilhar, toque para soltar!"],
		["spin", "Troca (3v3)", "Toque nos retratos no alto da tela para trocar de Pokémon (tem tempo de recarga)."],
		["sparkle", "Mega Evolução", "Opção experimental: quando o botão M acender, toque para evoluir por um tempo."],
	]


static func keyboard_lines() -> Array:
	return [
		["joystick", "Mover", "WASD ou setas  •  analógico esquerdo"],
		["drag", "Mirar", "Mouse  •  analógico direito  (sem mirar = mira automática)"],
		["fist", "Ataque básico", "J ou clique  •  A / RT  (segure para repetir)"],
		["orb", "Habilidades", "K  L  U  (ou 1 2 3)  •  X  Y  B"],
		["dodge", "Dash", "Espaço / Shift  •  LB / LT — esquiva com invencibilidade curta, gasta energia"],
		["burst", "Ultimate", "I / R  •  RB — carrega ao causar e receber dano"],
		["spin", "Troca (3v3)", "Q / E  •  D-pad ← →  (tem tempo de recarga)"],
		["sparkle", "Mega Evolução", "M  •  L3 — quando a carga MEGA chegar a 100% (opção experimental)"],
	]


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var lines := touch_lines() if touch_mode else keyboard_lines()
	for l in lines:
		var icon := _TutorialIcon.new()
		icon.shape = l[0]
		icon.custom_minimum_size = Vector2(46, 46)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_rows.add_child(icon)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(minf(760.0, get_viewport_rect().size.x - 180.0), 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("normal_font_size", 18)
		text.add_theme_font_size_override("bold_font_size", 19)
		text.text = "[b][color=#ffcc40]%s[/color][/b]  %s" % [l[1], l[2]]
		_rows.add_child(text)
	_footer.text = "Toque em qualquer lugar para continuar" if touch_mode else "Pressione qualquer tecla ou botão para continuar"


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var press := false
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		press = event.pressed
	elif event is InputEventKey:
		press = event.pressed and not event.echo
	elif event is InputEventJoypadButton:
		press = event.pressed
	if not press:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_at < INPUT_GRACE_MS:
		return
	close()


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.play("ui_back")
	closed.emit()


## Small vector icon cell (uses SkillIcons shapes).
class _TutorialIcon:
	extends Control
	var shape := "star"

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.08, 0.1, 0.14, 0.9))
		draw_arc(c, r, 0, TAU, 32, Color(UITheme.ACCENT, 0.8), 2.0)
		SkillIcons.draw_icon(self, shape, c, r * 1.2, UITheme.ACCENT2.lerp(Color.WHITE, 0.25))
