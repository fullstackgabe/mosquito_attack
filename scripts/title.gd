extends Control

## Tela inicial: título, moedas e botão para ir à escolha de arma.

const MOSQUITO_TEX := preload("res://art/mosquitos/common/fly/south.png")
const CHINELO_TEX  := preload("res://art/objects/chinelo/chinelo.png")

var _flyers: Array[Sprite2D] = []
var _t := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_background()
	_build_title()
	_build_buttons()
	add_child(_coins_badge())

func _process(delta: float) -> void:
	_t += delta
	for i in _flyers.size():
		var s := _flyers[i]
		s.position.x += (60.0 + i * 25.0) * delta * (1.0 if i % 2 == 0 else -1.0)
		s.position.y += sin(_t * (2.0 + i * 0.3) + i) * 40.0 * delta
		s.flip_h = i % 2 == 0
		if s.position.x > 2020.0: s.position.x = -100.0
		if s.position.x < -100.0: s.position.x = 2020.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start()

# ---------------------------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Styles.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	## Mosquitos decorativos voando ao fundo
	for i in 6:
		var s := Sprite2D.new()
		s.texture = MOSQUITO_TEX
		s.scale = Vector2.ONE * (1.0 + (i % 3) * 0.35)
		s.modulate = Color(1, 1, 1, 0.35 + (i % 3) * 0.15)
		s.position = Vector2(150.0 + i * 320.0, 140.0 + (i * 157) % 800)
		add_child(s)
		_flyers.append(s)

func _build_title() -> void:
	var chinelo := Sprite2D.new()
	chinelo.texture = CHINELO_TEX
	chinelo.scale = Vector2(4.5, 4.5)
	chinelo.rotation_degrees = -20.0
	chinelo.position = Vector2(960, 250)
	add_child(chinelo)

	var title := _label("MOSQUITO ATTACK", 130, Styles.YELLOW)
	title.position = Vector2(0, 390)
	title.size = Vector2(1920, 160)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 18)
	add_child(title)

	var sub := _label("Esmague os mosquitos antes que eles te piquem!", 40, Styles.CREAM)
	sub.position = Vector2(0, 560)
	sub.size = Vector2(1920, 60)
	add_child(sub)

func _build_buttons() -> void:
	var btn := Button.new()
	btn.text = "INICIAR JOGO"
	btn.size = Vector2(460, 110)
	btn.position = Vector2(960 - 230, 700)
	btn.add_theme_font_size_override("font_size", 48)
	Styles.gold_button(btn, Styles.YELLOW, Styles.YELLOW.lightened(0.25))
	btn.pressed.connect(_start)
	add_child(btn)

func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/weapon_select.tscn")

# ---------------------------------------------------------------------------

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _coins_badge() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.bordered(Styles.PANEL, Styles.YELLOW, 12, 3))
	panel.position = Vector2(1920 - 360, 30)
	panel.custom_minimum_size = Vector2(330, 0)
	var l := _label("Moedas: %d" % SaveData.coins, 40, Styles.YELLOW)
	panel.add_child(l)
	return panel
