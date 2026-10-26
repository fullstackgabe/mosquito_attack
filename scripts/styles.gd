class_name Styles
extends RefCounted

# Paleta Mosquito Attack
const NIGHT  := Color(0.08, 0.10, 0.18)   # fundo das telas de menu
const PANEL  := Color(0.13, 0.16, 0.26)   # cards e painéis
const CREAM  := Color(0.92, 0.92, 0.88)   # fundo da arena, texto claro
const YELLOW := Color(1.00, 0.80, 0.20)   # destaque, botões principais
const BLOOD  := Color(0.72, 0.08, 0.10)   # sangue, perigo
const MUTED  := Color(0.55, 0.58, 0.66)   # itens bloqueados, texto secundário

static func flat(color: Color, radius := 10, padding := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(padding)
	s.set_corner_radius_all(radius)
	return s

static func bordered(bg: Color, border: Color, radius := 12, border_px := 4) -> StyleBoxFlat:
	var s := flat(bg, radius)
	s.border_color = border
	s.set_border_width_all(border_px)
	return s

static func gold_button(btn: Button, normal: Color, hover: Color) -> void:
	btn.add_theme_stylebox_override("normal",   flat(normal, 10))
	btn.add_theme_stylebox_override("hover",    flat(hover, 10))
	btn.add_theme_stylebox_override("pressed",  flat(normal.darkened(0.15), 10))
	btn.add_theme_stylebox_override("disabled", flat(normal.darkened(0.55), 10))
	btn.add_theme_color_override("font_color", NIGHT)
	btn.add_theme_color_override("font_hover_color", NIGHT)
	btn.add_theme_color_override("font_disabled_color", NIGHT.lightened(0.25))
