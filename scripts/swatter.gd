extends Node2D

## Arma equipada que segue o cursor. A mecânica vem de `Weapons.DEFS[...].kind`:
## tap (chinelo, livro; com soco: luva de boxe; com varredura: jornal, vassoura, toalha, taco), field (raquete),
## spray (inseticida), jet (pistola de água), throw (ursinho, tênis, bola)
## e rocket (bazuca). O acerto do tap/throw é pelos pixels visíveis do sprite contra
## `Mosquito.hit_points()`; os outros, por distância.

const SPRAY_CLOUD_SCRIPT := preload("res://scripts/spray_cloud.gd")
const THROWN_SCRIPT      := preload("res://scripts/thrown_weapon.gd")
const ROCKET_SCRIPT      := preload("res://scripts/rocket.gd")
const SPLASH_SCRIPT      := preload("res://scripts/water_splash.gd")

const SMACK_SQUASH    := 0.72   # escala do golpe em relação à de repouso
const SMACK_DURATION  := 0.08
const RETURN_DURATION := 0.12
const SPRAY_INTERVAL  := 0.06   # segundos entre nuvens enquanto segura
const SPRAY_RESTART   := 0.3    # tanque mínimo para voltar a borrifar depois de esvaziar
const BAR_SIZE        := Vector2(120, 12)
const CROSSHAIR_R     := 26.0
const SLAM_FX_TIME    := 0.3    # luva: duração do anel do tapa
const PUNCH_REACH     := 90.0   # luva de boxe: quanto o soco sobe
## Chicote: parado é a MESMA imagem do menu (enrolado), com o cabo logo abaixo da mira.
## Ao chicotear, o sprite some e a corda é desenhada em código com as cores do PNG: o
## cabo fica em pé e a corda desenrola do cabo para a ponta (onda), fica RETA na vertical
## e estala na mira; depois volta a enrolar e o sprite reaparece.
## `crack_coil`: linha central da corda no PNG (px), do topo do cabo até a ponta.
## `crack_coil`: linha central da corda no PNG (px), do topo do cabo até a ponta.
const CRACK_FX_TIME := 0.3
const WHIP_REACH    := 150.0  # raio do dano em volta da mira
const WHIP_ROPE_LEN := 260.0  # corda esticada: do topo do cabo até a mira
const WHIP_PTS      := 48
const WHIP_T_OUT    := 0.2    # desenrola até estalar
const WHIP_T_BACK   := 0.3    # volta a enrolar
const WHIP_END      := WHIP_T_OUT + WHIP_T_BACK
const WHIP_PIX      := 3      # = 1 px do PNG na escala 3
const WHIP_ROPE     := Color("9b5626")
const WHIP_ROPE_HI  := Color("a8642f")
const WHIP_ROPE_DK  := Color("7f4119")
const WHIP_LINE     := Color("301606")
const WHIP_GRIP     := Color("251e17")
const WHIP_GRIP_HI  := Color("4a423a")
const LAUNCHER_BOTTOM := 110.0
## Cores da água do jato = as da marca molhada na parede (`water_splash.gd`: C_WET_D,
## C_WET, C_SHINE), um pouco mais opacas, para jato e parede serem a mesma água.
const WATER_MID   := Color(0.10, 0.38, 0.70, 0.85)
const WATER_LIGHT := Color(0.18, 0.48, 0.78, 0.75)
const WATER_SHINE := Color(0.88, 0.96, 1.0, 0.95)  # pistola/bazuca: altura da arma acima da borda de baixo

@onready var sprite: Sprite2D = $Sprite2D

var weapon: Dictionary
var _scale := 2.9
var _thick := 1.0            # engrossa o sprite na largura (taco)
var _tween: Tween = null

var _cooldown_left := 0.0    # vassoura
var _field_left := 0.0       # raquete: tempo restante do campo ligado
var _charges := 0.0          # raquete: cargas da bateria (fracionário enquanto recarrega)
var _drained := false        # raquete: zerou a bateria → espera mais e volta cheia
var _drain_progress := 0.0   # 0→1 durante a recarga longa
var _tank := 1.0             # inseticida
var _spraying := false
var _spray_locked := false
var _spray_t := 0.0
var _thrown := false         # arma arremessada em voo
var _jetting := false        # pistola de água: jato no ar
var _slam_t := -1.0          # luva: tempo do anel do tapa (< 0 = sem anel)
var _crack_t := -1.0         # chicote: tempo do estalo (< 0 = sem estalo)
var _crack_pos := Vector2.ZERO
var _whip_t := -1.0                      # chicote: tempo do golpe (< 0 = em repouso, sprite)
var _whip_hit := false
var _whip_trail: Array = []              # últimos quadros da corda (rastro)
var _whip_rest := PackedVector2Array()   # corda como no PNG (local), reamostrada
var _whip_handle_end := Vector2.ZERO
var _launcher: Sprite2D = null   # pistola/bazuca: a arma fica embaixo da tela e aponta para a mira
## Celular (tela de toque): sem mira e sem arma parada na tela; a arma aparece no ponto
## do toque só durante a animação do golpe (SHOW_TIME) ou enquanto segura (spray/campo).
var _touch := false
var _show_t := 0.0
const SHOW_TIME := 0.5

func _ready() -> void:
	weapon = Weapons.get_def(SaveData.equipped)
	if weapon.texture != "" and ResourceLoader.exists(weapon.texture):
		sprite.texture = load(weapon.texture)
	_scale = weapon.get("scale", 2.9)
	_thick = weapon.get("thick", 1.0)
	sprite.scale = Vector2(_scale * _thick, _scale)
	_charges = weapon.get("charges", 0)
	_touch = DisplayServer.is_touchscreen_available()
	sprite.visible = not weapon.get("crosshair", false) and not _touch
	sprite.flip_h = weapon.get("flip_h", false)
	sprite.flip_v = weapon.get("flip_v", false)
	if weapon.has("launcher_angle"):
		_build_launcher()
	if weapon.has("aim_y") and not weapon.has("sweep"):
		## Desloca o sprite para a parte que acerta (cabeça da raquete, bico do spray) ficar no cursor.
		sprite.position = Vector2(0, (sprite.texture.get_height() / 2.0 - weapon.aim_y) * _scale)
	if weapon.has("crack"):
		_setup_whip()
	if weapon.has("sweep"):
		## Pivô no fim do cabo: o sprite gira a partir dali e a ponta varre o cursor.
		## `aim_y`: linha do PNG que fica no cursor (taco: meio da parte grossa).
		var half_h := sprite.texture.get_height() / 2.0
		var h := float(sprite.texture.get_height())
		sprite.offset   = Vector2(0, -half_h)
		sprite.position = Vector2(0, (h - weapon.get("aim_y", half_h)) * _scale)

func _process(delta: float) -> void:
	global_position = get_viewport().get_mouse_position()
	_tick_resources(delta)
	_tick_field(delta)
	_tick_launcher()
	if _jetting and not _spray_locked:
		_tick_jet()
	if _slam_t >= 0.0:
		_slam_t += delta
		if _slam_t >= SLAM_FX_TIME:
			_slam_t = -1.0
	if _crack_t >= 0.0:
		_crack_t += delta
		if _crack_t >= CRACK_FX_TIME:
			_crack_t = -1.0
	if _whip_t >= 0.0:
		_tick_whip(delta)
	_tick_touch_visibility(delta)
	if _spraying and not _spray_locked:
		_spray_t -= delta
		if _spray_t <= 0.0:
			_spray_t = SPRAY_INTERVAL
			_emit_cloud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch:
			return   # no celular o toque já chega como ScreenTouch; o clique emulado duplicaria
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		global_position = event.position
		return
	if not (pressed or released):
		return
	global_position = event.position
	if pressed and _touch and not weapon.get("crosshair", false):
		sprite.visible = true
		_show_t = SHOW_TIME
	match weapon.get("kind", "tap"):
		"tap":
			if pressed: _tap()
		"field":
			if pressed: _activate_field()
		"spray":
			_spraying = pressed
			_spray_t = 0.0
		"jet":
			if pressed: _squirt()
		"throw":
			if pressed: _throw()
		"rocket":
			if pressed: _fire_rocket()

# ---------------------------------------------------------------------------
# tap: chinelo, vassoura (varredura + espera)

func _tap() -> void:
	if weapon.has("cooldown"):
		if _cooldown_left > 0.0:
			return
		_cooldown_left = weapon.cooldown
	if weapon.has("sweep"):
		_sweep()
	elif weapon.has("crack"):
		_crack()
	elif weapon.has("slam_radius"):
		_slam()
	elif weapon.get("punch", false):
		## O soco sobe PUNCH_REACH px: acerta tudo no caminho, do repouso até o topo.
		for i in 4:
			_hit_at_rest(0.0, Vector2(0, -PUNCH_REACH * i / 3.0))
		_play_punch()
	else:
		_hit_at_rest(0.0)
		_play_smack()

## Mata todo mosquito debaixo do sprite na pose de repouso, girado `rot` rad.
## Usa a escala de repouso (o que o jogador vê ao mirar), não a da animação.
func _hit_at_rest(rot: float, shift := Vector2.ZERO) -> void:
	var xf := Transform2D(rot, Vector2(_scale * _thick, _scale), 0.0, sprite.position + shift)
	var inv := xf.affine_inverse()
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if not m.alive:
			continue
		for p in m.hit_points():
			if sprite.is_pixel_opaque(inv * (p - global_position)):
				m.squash(weapon.get("death", "smash"), _sweep_dir(m.global_position))
				break

## Para onde o mosquito varrido voa: para fora do pivô e no sentido do golpe.
func _sweep_dir(target: Vector2) -> Vector2:
	if weapon.get("punch", false):
		return Vector2.UP.rotated(randf_range(-0.35, 0.35))   # soco: voa para cima
	if not weapon.has("sweep"):
		return Vector2.ZERO
	var outward := (target - (global_position + sprite.position)).normalized()
	return (outward * 0.5 + outward.rotated(-PI / 2.0)).normalized()

## Golpe de destro: começa inclinado para a direita e varre para a esquerda.
func _sweep() -> void:
	var half := deg_to_rad(weapon.sweep / 2.0)
	var steps := 12
	for i in steps + 1:
		_hit_at_rest(lerpf(half, -half, float(i) / steps))
	if _tween and _tween.is_valid():
		_tween.kill()
	sprite.rotation = half
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(sprite, "rotation", -half, 0.16).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "rotation", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT)

## Luva de pedreiro: tapa gigante — mata tudo num raio em volta do cursor e a tela treme.
func _slam() -> void:
	var r: float = weapon.slam_radius
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and m.global_position.distance_to(global_position) <= r + m.HIT_RADIUS * 0.5:
			m.squash(weapon.get("death", "smash_big"))
	_slam_t = 0.0
	_play_backhand()
	Mosquito.shake_scene(get_tree(), 14.0)

## Luva: tapa com as costas da mão — vem de lado, girada, e chicoteia até a mira.
func _play_backhand() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var rest := sprite.position
	sprite.position = rest + Vector2(170, -60)
	sprite.rotation = deg_to_rad(-75)
	var smack := _scale * 0.85
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "position", rest, 0.09)
	_tween.tween_property(sprite, "rotation", deg_to_rad(12), 0.09)
	_tween.tween_property(sprite, "scale", Vector2(smack * 1.15, smack), 0.09)
	_tween.chain().tween_property(sprite, "rotation", 0.0, 0.15)
	_tween.parallel().tween_property(sprite, "scale", Vector2(_scale, _scale), 0.15)

## Luva de boxe: soco que vai e volta na tela — sobe PUNCH_REACH px e volta para a
## posição de repouso (sem crescer).
func _play_punch() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var rest := sprite.position
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(sprite, "position", rest + Vector2(0, -PUNCH_REACH), 0.07).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "position", rest, 0.14).set_ease(Tween.EASE_IN_OUT)

func _play_smack() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var smack := _scale * SMACK_SQUASH
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(sprite, "scale", Vector2(smack, smack), SMACK_DURATION).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "scale", Vector2(_scale, _scale), RETURN_DURATION).set_ease(Tween.EASE_IN)

func _flash(color: Color) -> void:
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)

# ---------------------------------------------------------------------------
# field: raquete elétrica — clique gasta 1 carga e liga o campo por `field_time`

func _activate_field() -> void:
	if _field_left > 0.0:
		return
	if _charges < 1.0:
		_flash(Color(1, 0.4, 0.4))   # sem carga
		return
	_charges -= 1.0
	if _charges < 1.0:
		_drained = true
		_drain_progress = 0.0
	_field_left = weapon.field_time

func _tick_field(delta: float) -> void:
	if _field_left <= 0.0:
		return
	_field_left -= delta
	var r: float = weapon.field_radius
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and m.global_position.distance_to(global_position) <= r + m.HIT_RADIUS * 0.5:
			m.squash("zap")
	if _field_left <= 0.0:
		_field_left = 0.0

# ---------------------------------------------------------------------------
# spray: inseticida

func _emit_cloud() -> void:
	var cloud := Node2D.new()
	cloud.set_script(SPRAY_CLOUD_SCRIPT)
	cloud.max_radius = weapon.cloud_radius
	cloud.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	get_parent().add_child(cloud)
	get_parent().move_child(cloud, get_index())   # nuvem por baixo da lata

# ---------------------------------------------------------------------------
# jet: pistola de água — clique solta um jato único da arma até a mira

var _jet_left := 0.0
var _jet_target := Vector2.ZERO   ## o jato vai até onde estava a mira no clique

func _splash() -> void:
	var s: Node2D = SPLASH_SCRIPT.new()
	s.radius = weapon.splash_radius
	s.life = weapon.splash_life
	s.death = weapon.get("death", "wet")
	s.global_position = _jet_target
	get_parent().add_child(s)
	get_parent().move_child(s, get_index())   # mancha por baixo da mira

func _squirt() -> void:
	if _cooldown_left > 0.0 or _jetting:
		return
	_cooldown_left = weapon.cooldown
	_jet_left = weapon.jet_time
	_jetting = true
	_jet_target = global_position

func _tick_jet() -> void:
	_jet_left -= get_process_delta_time()
	if _jet_left <= 0.0:
		_jetting = false
		_splash()
	var a := _muzzle()
	var b := _jet_target
	var width: float = weapon.jet_width
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if not m.alive:
			continue
		var p: Vector2 = m.global_position
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= width + m.HIT_RADIUS * 0.5:
			m.squash(weapon.get("death", "wet"))

# ---------------------------------------------------------------------------
# rocket: bazuca — foguete da arma até o ponto clicado, explosão em área

func _fire_rocket() -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = weapon.cooldown
	var r: Node2D = ROCKET_SCRIPT.new()
	r.position = _muzzle()
	r.target = global_position
	r.speed = weapon.rocket_speed
	r.blast_radius = weapon.blast_radius
	r.death = weapon.get("death", "blast")
	get_parent().add_child(r)
	if _launcher:   # coice
		var back := -Vector2.RIGHT.rotated(_aim_angle()) * 18.0
		var base := _launcher_base()
		_launcher.global_position = base + back
		create_tween().tween_property(_launcher, "global_position", base, 0.2)

# ---------------------------------------------------------------------------
## Celular: esconde a arma de mão quando o golpe acaba (spray e campo seguram enquanto ativos).
func _tick_touch_visibility(delta: float) -> void:
	if not _touch or not sprite.visible or weapon.get("crosshair", false):
		return
	if _spraying or _field_left > 0.0:
		_show_t = SHOW_TIME
	_show_t -= delta
	if _show_t <= 0.0:
		sprite.visible = false

# Arma fixa embaixo da tela (pistola, bazuca), apontando para a mira

func _build_launcher() -> void:
	_launcher = Sprite2D.new()
	_launcher.texture = sprite.texture
	_launcher.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_launcher.top_level = true
	_launcher.scale = Vector2(_scale, _scale)
	add_child(_launcher)
	_launcher.global_position = _launcher_base()

func _launcher_base() -> Vector2:
	var arena := get_viewport_rect()
	return Vector2(arena.size.x / 2.0, arena.size.y - LAUNCHER_BOTTOM)

func _aim_angle() -> float:
	return (global_position - _launcher_base()).angle()

## `launcher_angle`: para onde o cano aponta no PNG (graus, 0 = direita, 90 = baixo).
## Mirando para o lado oposto ao que o cano aponta no PNG, a arma espelha na vertical
## (senão ficaria de cabeça para baixo); espelhada, o cano aponta para -launcher_angle.
func _tick_launcher() -> void:
	if _launcher:
		var aim := _aim_angle()
		var barrel := deg_to_rad(weapon.launcher_angle)
		var flip := cos(aim) * cos(barrel) < 0.0
		_launcher.flip_v = flip
		_launcher.rotation = aim - (-barrel if flip else barrel)

## Boca da arma: um pouco à frente do centro, na direção da mira.
func _muzzle() -> Vector2:
	var base := _launcher_base()
	return base + Vector2.RIGHT.rotated(_aim_angle()) * sprite.texture.get_width() * 0.45 * _scale

# ---------------------------------------------------------------------------
# throw: ursinho, tênis, bola

func _throw() -> void:
	if _thrown:
		return
	var arena := get_viewport_rect()
	## Sai da borda de baixo, passa pelo ponto clicado e segue até sair da tela.
	var start := Vector2(arena.size.x / 2.0, arena.size.y + 80.0)
	var dir := (global_position - start).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var proj: Sprite2D = THROWN_SCRIPT.new()
	proj.texture = sprite.texture
	proj.scale = sprite.scale
	proj.position = start
	proj.velocity = dir * weapon.throw_speed
	proj.arena = arena
	proj.death = weapon.get("death", "smash_big")
	proj.bounces = weapon.get("bounces", 0)
	proj.bounce_time = weapon.get("bounce_time", 0.0)
	proj.boomerang = weapon.get("boomerang", false)
	proj.target = global_position
	proj.home = start
	## raio do desenho: quica quando a borda do sprite (não o centro) encosta na tela
	var used := sprite.texture.get_image().get_used_rect()
	proj.radius = maxf(used.size.x, used.size.y) * _scale / 2.0
	proj.finished.connect(func(): _thrown = false; sprite.visible = not weapon.get("crosshair", false))
	get_parent().add_child(proj)
	_thrown = true
	sprite.visible = false

# ---------------------------------------------------------------------------
# Recursos (bateria, espera, tanque) + barrinha embaixo do cursor

func _tick_resources(delta: float) -> void:
	if weapon.has("charges") and _field_left <= 0.0:
		if _drained:
			_drain_progress += delta / weapon.empty_recharge
			if _drain_progress >= 1.0:
				_drained = false
				_charges = weapon.charges   # volta a bateria inteira de uma vez
		else:
			_charges = minf(weapon.charges, _charges + delta / weapon.recharge)
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if weapon.has("drain"):   # tanque: inseticida
		if (_spraying or _jetting) and not _spray_locked:
			_tank = maxf(0.0, _tank - weapon.drain * delta)
			if _tank <= 0.0:
				_spray_locked = true
		else:
			_tank = minf(1.0, _tank + weapon.refill * delta)
			if _spray_locked and _tank >= SPRAY_RESTART:
				_spray_locked = false

## Logo abaixo da base do sprite (que pode estar deslocado por aim_y / sweep),
## ou da mira nas armas que não mostram o sprite no cursor.
func _bar_y() -> float:
	if weapon.get("crosshair", false):
		return CROSSHAIR_R * 1.5 + 8.0
	if weapon.has("sweep"):
		return sprite.position.y + 16.0
	return sprite.position.y + sprite.texture.get_height() / 2.0 * _scale + 12.0

func _bar_value() -> float:
	if weapon.get("no_bar", false):
		return -1.0   # espera sem barra (taco)
	if weapon.get("kind") == "jet":
		return -1.0   # pistola: sem barra (pedido do usuário)
	if weapon.has("cooldown"):
		return 1.0 - _cooldown_left / weapon.cooldown
	if weapon.has("drain"):
		return _tank
	return -1.0   # sem barra

func _draw() -> void:
	if _jetting and not _spray_locked:
		_draw_jet()
	if _slam_t >= 0.0:
		_draw_slam()
	if _whip_t >= 0.0 and sprite.visible:
		_draw_whip()
	if _crack_t >= 0.0:
		_draw_crack()
	if weapon.get("crosshair", false) and not _touch:
		_draw_crosshair()
	if _field_left > 0.0:
		_draw_field()
	if weapon.has("charges"):
		_draw_battery()
		return
	var v := _bar_value()
	if v < 0.0 or v >= 1.0:
		return
	var pos := Vector2(-BAR_SIZE.x / 2.0, _bar_y())
	draw_rect(Rect2(pos, BAR_SIZE), Color(0, 0, 0, 0.55))
	var fill := Color(0.35, 0.8, 1.0)
	if weapon.get("kind") == "jet":
		fill = Color(0.35, 0.65, 1.0) if not _spray_locked else Color(0.9, 0.3, 0.3)
	elif weapon.has("drain"):
		fill = Color(0.55, 0.85, 0.35) if not _spray_locked else Color(0.9, 0.3, 0.3)
	elif weapon.has("cooldown"):
		fill = Color(1.0, 0.8, 0.2)
	draw_rect(Rect2(pos, Vector2(BAR_SIZE.x * v, BAR_SIZE.y)), fill)

## Campo da raquete: bolha azul com raios que tremem (redesenhada todo frame).
func _draw_field() -> void:
	var r: float = weapon.field_radius
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.03)
	draw_circle(Vector2.ZERO, r * pulse, Color(0.35, 0.75, 1.0, 0.3))
	draw_arc(Vector2.ZERO, r * pulse, 0.0, TAU, 48, Color(0.6, 0.9, 1.0, 1.0), 4.0)
	for i in 6:
		var a := randf() * TAU
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in range(1, 5):
			var p := Vector2.RIGHT.rotated(a + randf_range(-0.35, 0.35)) * r * k / 4.0
			pts.append(p)
		draw_polyline(pts, Color(0.8, 0.95, 1.0, 0.85), 2.0)

## Bateria da raquete: um gomo por carga; o gomo que está recarregando enche aos poucos.
func _draw_battery() -> void:
	var n: int = weapon.charges
	var gap := 4.0
	var seg_w := (BAR_SIZE.x - gap * (n - 1)) / n
	var pos := Vector2(-BAR_SIZE.x / 2.0, _bar_y())
	if _field_left > 0.0:
		## Campo ligado: barra azul descendo conforme o tempo do campo acaba.
		draw_rect(Rect2(pos, BAR_SIZE), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(pos, Vector2(BAR_SIZE.x * _field_left / weapon.field_time, BAR_SIZE.y)), Color(0.35, 0.8, 1.0))
		return
	if _drained:
		## Zerou: uma barra vermelha única enche até a bateria voltar cheia.
		draw_rect(Rect2(pos, BAR_SIZE), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(pos, Vector2(BAR_SIZE.x * _drain_progress, BAR_SIZE.y)), Color(0.95, 0.3, 0.3, 0.9))
		return
	for i in n:
		var r := Rect2(pos + Vector2(i * (seg_w + gap), 0), Vector2(seg_w, BAR_SIZE.y))
		draw_rect(r, Color(0, 0, 0, 0.55))
		var fill := clampf(_charges - i, 0.0, 1.0)
		if fill > 0.0:
			var col := Color(0.35, 0.8, 1.0) if fill >= 1.0 else Color(0.35, 0.8, 1.0, 0.5)
			draw_rect(Rect2(r.position, Vector2(seg_w * fill, BAR_SIZE.y)), col)

## Jato da pistola: faixa azul da boca da arma até a mira, com gotas tremendo.
func _draw_jet() -> void:
	## Jato em pixel art: quadradinhos ao longo da linha, com ondulação; a ponta sai do
	## cano e chega na mira no primeiro terço do jato.
	var a := to_local(_muzzle())
	var b := to_local(_jet_target)
	var w: float = weapon.jet_width
	var grow := clampf((1.0 - _jet_left / weapon.jet_time) * 3.0, 0.0, 1.0)
	var end := a.lerp(b, grow)
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	var length := a.distance_to(end)
	var t := Time.get_ticks_msec() * 0.02
	var step := 7.0
	for i in int(length / step) + 1:
		var d := i * step
		var wob := sin(d * 0.05 - t) * 4.0
		var p := (a + dir * d + side * wob).snapped(Vector2(3, 3))
		var s_out := w * 0.9
		var s_in := w * 0.4
		draw_rect(Rect2(p - Vector2(s_out, s_out) / 2.0, Vector2(s_out, s_out)), WATER_MID)
		draw_rect(Rect2(p - Vector2(s_in, s_in) / 2.0 + side * 3.0, Vector2(s_in, s_in)), WATER_SHINE)
	for i in 8:   # gotas soltas em volta
		var p := (a + dir * length * randf() + side * randf_range(-w, w)).snapped(Vector2(3, 3))
		draw_rect(Rect2(p, Vector2(6, 6)), WATER_LIGHT)
	if grow >= 1.0:   # respingo onde bate
		for i in 6:
			var p := (b + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10, w * 1.6)).snapped(Vector2(3, 3))
			draw_rect(Rect2(p, Vector2(6, 6)), WATER_MID)

## Luva: anel que se expande e some no raio do tapa.
# ---------------------------------------------------------------------------
# Chicote

func _setup_whip() -> void:
	var tex_c := sprite.texture.get_size() / 2.0
	var handle := Vector2(weapon.crack_handle[0], weapon.crack_handle[1])
	var ctrl: Array = weapon.crack_coil
	var handle_len := _coil_px(ctrl, 0).distance_to(handle) * _scale
	_whip_handle_end = Vector2(0, WHIP_ROPE_LEN + handle_len)   # cabo em pé termina aqui
	sprite.offset   = tex_c - handle
	sprite.position = _whip_handle_end
	## Linha central da corda no PNG (catmull) → local → reamostrada em WHIP_PTS.
	var dense := PackedVector2Array()
	for i in ctrl.size() - 1:
		var p0 := _coil_px(ctrl, i - 1)
		var p1 := _coil_px(ctrl, i)
		var p2 := _coil_px(ctrl, i + 1)
		var p3 := _coil_px(ctrl, i + 2)
		for k in 12:
			var t := k / 12.0
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			dense.append(_whip_handle_end + (q - handle) * _scale)
	dense.append(_whip_handle_end + (_coil_px(ctrl, ctrl.size() - 1) - handle) * _scale)
	_whip_rest = _resample(dense, WHIP_PTS)

func _coil_px(ctrl: Array, i: int) -> Vector2:
	var c: Array = ctrl[clampi(i, 0, ctrl.size() - 1)]
	return Vector2(c[0], c[1])

func _resample(src: PackedVector2Array, n: int) -> PackedVector2Array:
	var total := 0.0
	for i in src.size() - 1:
		total += src[i].distance_to(src[i + 1])
	var out := PackedVector2Array([src[0]])
	var seg := 0
	var acc := 0.0
	for k in range(1, n + 1):
		var want := total * k / n
		while seg < src.size() - 2 and acc + src[seg].distance_to(src[seg + 1]) < want:
			acc += src[seg].distance_to(src[seg + 1])
			seg += 1
		var l := src[seg].distance_to(src[seg + 1])
		out.append(src[seg].lerp(src[seg + 1], clampf((want - acc) / maxf(l, 0.001), 0.0, 1.0)))
	return out

func _crack() -> void:
	_whip_t = 0.0
	_whip_hit = false
	_whip_trail.clear()
	sprite.self_modulate.a = 0.0
	queue_redraw()

func _tick_whip(delta: float) -> void:
	_whip_t += delta
	if not _whip_hit and _whip_t >= WHIP_T_OUT:
		_whip_hit = true
		_crack_hit()
	_whip_trail.push_front(_whip_points(_whip_t))
	if _whip_trail.size() > 4:
		_whip_trail.pop_back()
	if _whip_t >= WHIP_END:
		_whip_t = -1.0
		_whip_trail.clear()
		sprite.self_modulate.a = 1.0

## Quanto cada ponto já desenrolou (0 = como no PNG, 1 = reto): a onda sai do cabo e
## corre até a ponta; na volta, enrola de novo da ponta para o cabo.
func _whip_points(t: float) -> PackedVector2Array:
	var u: float
	if t < WHIP_T_OUT:
		u = t / WHIP_T_OUT
	else:
		u = 1.0 - (t - WHIP_T_OUT) / WHIP_T_BACK
	var pts := PackedVector2Array()
	for i in WHIP_PTS + 1:
		var f := float(i) / WHIP_PTS
		var w := clampf(u * 1.6 - f * 0.6, 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		var straight := Vector2(0, WHIP_ROPE_LEN * (1.0 - f))
		var wave := sin(f * PI * 2.0 - u * PI * 3.0) * 26.0 * sin(w * PI) * f
		pts.append(_whip_rest[i].lerp(straight, w) + Vector2(wave, 0))
	return pts

## Estalo na mira: mata tudo num raio em volta dela e solta o efeito.
func _crack_hit() -> void:
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and m.global_position.distance_to(global_position) <= WHIP_REACH:
			var away: Vector2 = (m.global_position - global_position).normalized()
			m.squash(weapon.get("death", "swept"), away if away != Vector2.ZERO else Vector2.UP)
	_crack_pos = Vector2.ZERO
	_crack_t = 0.0
	Mosquito.shake_scene(get_tree(), 9.0)

func _draw_whip() -> void:
	## Rastro: quadros anteriores da corda, apagados.
	for k in range(_whip_trail.size() - 1, 0, -1):
		var trail: PackedVector2Array = _whip_trail[k]
		draw_polyline(trail, Color(WHIP_ROPE, 0.25 / k), 6.0)
	var pts := _whip_points(_whip_t)
	var cells := {}
	## Cabo preto com X cinza e aros: do fim (fixo) até o começo da corda.
	var top := pts[0]
	var hdir := (top - _whip_handle_end).normalized()
	_whip_stroke(cells, _whip_handle_end, top, 7.5, "grip")
	_whip_stroke(cells, _whip_handle_end - hdir * 2.0, _whip_handle_end + hdir * 2.0, 9.5, "cap")
	_whip_stroke(cells, top - hdir * 2.0, top + hdir * 2.0, 9.5, "cap")
	for i in WHIP_PTS:
		_whip_stroke(cells, pts[i], pts[i + 1], 3.6, "rope")
	var tip := pts[WHIP_PTS]
	var tdir := (pts[WHIP_PTS] - pts[WHIP_PTS - 1]).normalized()
	for a in [-0.6, 0.0, 0.6]:
		_whip_stroke(cells, tip, tip + tdir.rotated(a) * 14.0, 2.2, "rope")
	var outline := {}
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(c + d):
				outline[c + d] = true
	var px := Vector2(WHIP_PIX, WHIP_PIX)
	for c in outline:
		draw_rect(Rect2(Vector2(c) * WHIP_PIX, px), WHIP_LINE)
	for c in cells:
		draw_rect(Rect2(Vector2(c) * WHIP_PIX, px), cells[c])

func _whip_stroke(cells: Dictionary, a: Vector2, b: Vector2, r: float, kind: String) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len if len > 0.0 else Vector2.UP
	var nrm := dir.orthogonal()
	var n := maxi(1, ceili(len / 2.0))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var lo := Vector2i(floori((p.x - r) / WHIP_PIX), floori((p.y - r) / WHIP_PIX))
		var hi := Vector2i(floori((p.x + r) / WHIP_PIX), floori((p.y + r) / WHIP_PIX))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var off := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * WHIP_PIX - p
				if off.length() > r:
					continue
				var across := off.dot(nrm) / r
				var col: Color
				match kind:
					"grip":
						var along := (Vector2(cx, cy) * WHIP_PIX - a).dot(dir)
						var u1 := fposmod(along + across * 9.0, 15.0)
						var u2 := fposmod(along - across * 9.0, 15.0)
						col = WHIP_GRIP_HI if (u1 < 3.0 or u2 < 3.0) else WHIP_GRIP
					"cap":
						col = WHIP_GRIP_HI if across < -0.2 else WHIP_GRIP
					_:
						col = WHIP_ROPE_HI if across < -0.35 else (WHIP_ROPE_DK if across > 0.5 else WHIP_ROPE)
				cells[Vector2i(cx, cy)] = col

## Estalo: clarão, estrela de riscos, onda de choque e faíscas, some rápido.
func _draw_crack() -> void:
	var k := _crack_t / CRACK_FX_TIME
	var fade := 1.0 - k
	draw_circle(_crack_pos, 46.0 * (1.0 - k * 0.5), Color(1.0, 1.0, 0.85, 0.55 * fade))
	draw_arc(_crack_pos, 30.0 + 150.0 * k, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.9 * fade), 7.0)
	draw_arc(_crack_pos, 20.0 + 95.0 * k, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.6 * fade), 4.0)
	for i in 12:
		var d := Vector2.RIGHT.rotated(TAU * i / 12.0 + 0.15)
		var r := (60.0 if i % 2 == 0 else 38.0) + 70.0 * k
		draw_line(_crack_pos + d * r * 0.35, _crack_pos + d * r, Color(1.0, 0.95, 0.6, fade), 8.0 if i % 2 == 0 else 5.0)
	for i in 8:
		var d := Vector2.RIGHT.rotated(TAU * i / 8.0 + 0.6)
		draw_rect(Rect2(_crack_pos + d * (40.0 + 130.0 * k) - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.8, 0.3, fade))
	draw_circle(_crack_pos, 16.0 * fade, Color(1.0, 0.85, 0.3, fade))

func _draw_slam() -> void:
	var k := _slam_t / SLAM_FX_TIME
	var r: float = weapon.slam_radius * (0.5 + 0.5 * k)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.9, 0.3, 0.25 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.95, 0.6, 1.0 - k), 8.0)

## Mira das armas de arremesso/tiro: círculo + cruz com contorno escuro; fica cinza
## enquanto a arma está no ar ou recarregando.
func _draw_crosshair() -> void:
	var busy: bool = _thrown or (weapon.get("kind") in ["rocket", "jet"] and _cooldown_left > 0.0)
	var col := Color(1.0, 0.25, 0.2) if not busy else Color(0.6, 0.6, 0.6, 0.7)
	for pass_i in 2:
		var c := Color(0, 0, 0, 0.6) if pass_i == 0 else col
		var w := 5.0 if pass_i == 0 else 2.5
		draw_arc(Vector2.ZERO, CROSSHAIR_R, 0.0, TAU, 40, c, w)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * (CROSSHAIR_R * 0.45), d * (CROSSHAIR_R * 1.4), c, w)
	draw_circle(Vector2.ZERO, 2.5, col)
