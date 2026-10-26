extends Control

## Escolha de arma / loja. O chinelo vem de graça; as outras são compradas
## com moedas (1 por mosquito). Armas `locked` aparecem como “Em breve”.

const CARD_SIZE := Vector2(320, 470)
const CARD_GAP  := 30.0

var _coins_label: Label
var _row: HBoxContainer   # cards recriados a cada _refresh()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Styles.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("ESCOLHA SUA ARMA", 80, Styles.YELLOW)
	title.position = Vector2(0, 60)
	title.size = Vector2(1920, 110)
	add_child(title)

	add_child(_build_coins_badge())

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(CARD_GAP))
	add_child(_row)

	_build_bottom_buttons()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
	elif event.is_action_pressed("ui_accept"):
		_play()

# ---------------------------------------------------------------------------
# Cards

func _refresh() -> void:
	for c in _row.get_children():
		c.queue_free()
	for w in Weapons.DEFS:
		_row.add_child(_build_card(w))
	var n := Weapons.DEFS.size()
	var total_w := n * CARD_SIZE.x + (n - 1) * CARD_GAP
	_row.position = Vector2((1920 - total_w) / 2.0, 220)
	_coins_label.text = "Moedas: %d" % SaveData.coins

func _build_card(w: Dictionary) -> Control:
	var owned: bool = SaveData.owns(w.id)
	var equipped: bool = SaveData.equipped == w.id
	var border := Styles.YELLOW if equipped else (Styles.MUTED.darkened(0.3) if w.locked else Styles.MUTED)

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", Styles.bordered(Styles.PANEL, border, 14, 5 if equipped else 3))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	vbox.add_child(_build_icon(w))

	var name_lbl := _label(w.name, 34, Styles.MUTED if w.locked else Styles.CREAM)
	vbox.add_child(name_lbl)

	var desc := _label(w.desc, 22, Styles.MUTED)
	desc.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 26)
	if equipped:
		btn.text = "Equipada"
		btn.disabled = true
		Styles.gold_button(btn, Styles.YELLOW, Styles.YELLOW)
		btn.add_theme_stylebox_override("disabled", Styles.flat(Styles.YELLOW.darkened(0.25), 10))
	elif owned:
		btn.text = "Equipar"
		Styles.gold_button(btn, Styles.CREAM, Color.WHITE)
		btn.pressed.connect(func(): SaveData.equip(w.id); _refresh())
	elif w.locked:
		btn.text = "Em breve · %d" % w.price
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", Styles.flat(Styles.NIGHT, 10))
		btn.add_theme_color_override("font_disabled_color", Styles.MUTED)
	else:
		btn.text = "Comprar · %d" % w.price
		btn.disabled = SaveData.coins < w.price
		Styles.gold_button(btn, Styles.YELLOW, Styles.YELLOW.lightened(0.25))
		btn.pressed.connect(func():
			if SaveData.buy(w.id):
				SaveData.equip(w.id)
			_refresh())
	vbox.add_child(btn)
	return card

## Sprite da arma; arma sem sprite ainda mostra um “?” provisório.
func _build_icon(w: Dictionary) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(0, 190)
	if w.texture != "" and ResourceLoader.exists(w.texture):
		var tex := TextureRect.new()
		tex.texture = load(w.texture)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(180, 180)
		if w.locked:
			tex.modulate = Color(0, 0, 0, 0.6)
		box.add_child(tex)
	else:
		var q := _label("?", 140, Styles.MUTED.darkened(0.35))
		box.add_child(q)
	return box

# ---------------------------------------------------------------------------

func _build_bottom_buttons() -> void:
	var play := Button.new()
	play.text = "JOGAR"
	play.size = Vector2(380, 100)
	play.position = Vector2(960 + 20, 880)
	play.add_theme_font_size_override("font_size", 44)
	Styles.gold_button(play, Styles.YELLOW, Styles.YELLOW.lightened(0.25))
	play.pressed.connect(_play)
	add_child(play)

	var back := Button.new()
	back.text = "Voltar"
	back.size = Vector2(260, 100)
	back.position = Vector2(960 - 20 - 260, 880)
	back.add_theme_font_size_override("font_size", 36)
	Styles.gold_button(back, Styles.MUTED, Styles.CREAM)
	back.pressed.connect(_back)
	add_child(back)

func _play() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _build_coins_badge() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.bordered(Styles.PANEL, Styles.YELLOW, 12, 3))
	panel.position = Vector2(1920 - 360, 30)
	panel.custom_minimum_size = Vector2(330, 0)
	_coins_label = _label("", 40, Styles.YELLOW)
	panel.add_child(_coins_label)
	return panel

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
