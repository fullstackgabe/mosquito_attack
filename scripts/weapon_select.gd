extends Control

## Escolha de arma / loja. O chinelo vem de graça; as outras são compradas
## com moedas (1 por mosquito). Armas `locked` aparecem como “Em breve”.

## Grade de cartas: até GRID_COLS por linha, com a mesma quantidade em cada linha
## (14 armas = 2 linhas de 7, cabe sem rolagem).
const CARD_SIZE := Vector2(220, 300)
const CARD_GAP  := 16.0
const GRID_COLS := 8
const GRID_TOP  := 215.0

var _coins_label: Label
var _row: GridContainer   # cards recriados a cada _refresh()

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

	_row = GridContainer.new()
	_row.add_theme_constant_override("h_separation", int(CARD_GAP))
	_row.add_theme_constant_override("v_separation", int(CARD_GAP))
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
	var rows := ceili(float(n) / GRID_COLS)
	var cols := ceili(float(n) / rows)
	_row.columns = cols
	var total_w := cols * CARD_SIZE.x + (cols - 1) * CARD_GAP
	_row.position = Vector2((1920 - total_w) / 2.0, GRID_TOP)
	_coins_label.text = "Moedas: %d" % SaveData.coins

func _build_card(w: Dictionary) -> Control:
	var owned: bool = SaveData.owns(w.id)
	var equipped: bool = SaveData.equipped == w.id
	var border := Styles.YELLOW if equipped else (Styles.MUTED.darkened(0.3) if w.locked else Styles.MUTED)

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", Styles.bordered(Styles.PANEL, border, 14, 5 if equipped else 3))

	## Faixas de altura fixa (ícone, nome, descrição) e botão colado embaixo: tudo fica
	## na mesma posição em todas as cartas, seja qual for o tamanho do texto.
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	vbox.add_child(_build_icon(w))

	var name_lbl := _label(w.name, 22, Styles.MUTED if w.locked else Styles.CREAM)
	name_lbl.custom_minimum_size = Vector2(0, 30)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	## Descrição curta de 1 linha (até ~26 letras), altura fixa.
	var desc := _label(w.desc.replace("\n", " "), 15, Styles.MUTED)
	desc.custom_minimum_size = Vector2(0, 24)
	desc.clip_text = true
	vbox.add_child(desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 19)
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
	box.custom_minimum_size = Vector2(0, 116)
	if w.texture != "" and ResourceLoader.exists(w.texture):
		var tex := TextureRect.new()
		tex.texture = load(w.texture)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(110, 110)
		if w.locked:
			tex.modulate = Color(0.5, 0.52, 0.6, 0.85)   # visível, mas apagada
		box.add_child(tex)
	else:
		var q := _label("?", 90, Styles.MUTED.darkened(0.35))
		box.add_child(q)
	return box

# ---------------------------------------------------------------------------

func _build_bottom_buttons() -> void:
	var play := Button.new()
	play.text = "JOGAR"
	play.size = Vector2(380, 100)
	play.position = Vector2(960 + 20, 950)
	play.add_theme_font_size_override("font_size", 44)
	Styles.gold_button(play, Styles.YELLOW, Styles.YELLOW.lightened(0.25))
	play.pressed.connect(_play)
	add_child(play)

	var back := Button.new()
	back.text = "Voltar"
	back.size = Vector2(260, 100)
	back.position = Vector2(960 - 20 - 260, 950)
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
