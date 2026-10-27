class_name Mosquito
extends Area2D

@export var speed_min: float = 80.0
@export var speed_max: float = 220.0
@export var lifetime_min: float = 3.0
@export var lifetime_max: float = 8.0
@export var squish_duration: float = 0.4

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer

const BLOOD_PUDDLE_SCRIPT: Script = preload("res://scripts/blood_puddle.gd")
const DEATH_FX_SCRIPT: Script = preload("res://scripts/death_fx.gd")
## Partes que "quebram" no esmagamento (retângulos no PNG 96×96 do voo):
## asa de trás, pata traseira longa, pata de baixo. O corpo (o frame do voo em que o
## mosquito estava no tapa) é desenhado sem elas e cada parte vira um pedaço solto
## e torto ao lado — idêntico ao voo.
const BROKEN_PARTS: Array[Rect2i] = [Rect2i(55, 29, 14, 9), Rect2i(62, 56, 10, 4), Rect2i(33, 60, 9, 6)]
static var _broken_cache := {}   # Texture2D do voo → mesma textura sem as partes

var velocity: Vector2 = Vector2.ZERO
var alive: bool = true
var arena_rect: Rect2

## Asas batendo: 8 frames gerados no PixelLab (pixminimax, "fly_pixminimax", direção south;
## só as asas mexem),
## em loop rápido. Cada mosquito começa num ponto aleatório do ciclo.
const FLY_FRAMES: Array[Texture2D] = [
	preload("res://art/mosquitos/common/fly/frame_000.png"),
	preload("res://art/mosquitos/common/fly/frame_001.png"),
	preload("res://art/mosquitos/common/fly/frame_002.png"),
	preload("res://art/mosquitos/common/fly/frame_003.png"),
	preload("res://art/mosquitos/common/fly/frame_004.png"),
	preload("res://art/mosquitos/common/fly/frame_005.png"),
	preload("res://art/mosquitos/common/fly/frame_006.png"),
	preload("res://art/mosquitos/common/fly/frame_007.png"),
]
const FLY_FPS := 24.0

## Raio do corpo (px de tela) que conta como acerto.
const HIT_RADIUS := 28.0
## Rebatido pelo taco: voa quicando nas bordas e derruba quem tocar (em cadeia); morre
## esmagado ao acabar os quiques ou o tempo.
const BAT_SPEED   := 1500.0
const BAT_BOUNCES := 3
const BAT_MAX_T   := 2.0
const BAT_DAMP    := 0.85     # velocidade que sobra a cada quique
var _anim_t: float = randf()
var _half_size := Vector2(36, 36)   # metade do corpo visível (px de tela), medida no _ready

func _ready() -> void:
	var angle := randf() * TAU
	var speed := randf_range(speed_min, speed_max)
	velocity = Vector2(cos(angle), sin(angle)) * speed

	lifetime_timer.wait_time = randf_range(lifetime_min, lifetime_max)
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	lifetime_timer.start()

	add_to_group("mosquitos")
	var used := sprite.texture.get_image().get_used_rect()
	_half_size = Vector2(used.size) / 2.0 * sprite.scale + Vector2(4, 4)   # folga p/ a asa (frames variam um pouco)
	_update_facing()

func setup(arena: Rect2) -> void:
	arena_rect = arena

func _physics_process(delta: float) -> void:
	if not alive:
		return
	position += velocity * delta
	_bounce_off_walls()
	_update_facing()
	_anim_t += delta
	sprite.texture = FLY_FRAMES[int(_anim_t * FLY_FPS) % FLY_FRAMES.size()]

## Quica quando a borda do corpo desenhado encosta na borda da tela
## (não o centro), então o mosquito nunca sai nem pela metade.
func _bounce_off_walls() -> void:
	if arena_rect.size == Vector2.ZERO:
		return
	var r := arena_rect.grow_individual(-_half_size.x, -_half_size.y, -_half_size.x, -_half_size.y)
	if position.x < r.position.x and velocity.x < 0.0:
		velocity.x = -velocity.x
		position.x = r.position.x
	elif position.x > r.end.x and velocity.x > 0.0:
		velocity.x = -velocity.x
		position.x = r.end.x
	if position.y < r.position.y and velocity.y < 0.0:
		velocity.y = -velocity.y
		position.y = r.position.y
	elif position.y > r.end.y and velocity.y > 0.0:
		velocity.y = -velocity.y
		position.y = r.end.y

func _update_facing() -> void:
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0

## Pontos (globais) do corpo do mosquito usados pelo swatter para testar o acerto:
## o centro + um anel de raio HIT_RADIUS (corpo, sem a ponta das patas/asas).
func hit_points() -> PackedVector2Array:
	var pts := PackedVector2Array([global_position])
	for i in 8:
		pts.append(global_position + Vector2.RIGHT.rotated(TAU * i / 8.0) * HIT_RADIUS)
	return pts

## Chamado pelo swatter quando a sola acerta o mosquito.
## Chamado pela arma quando acerta. `style` define a animação de morte:
##   smash     — esmagado: achata, poça de sangue (chinelo)
##   zap       — eletrocutado: pisca, carboniza, treme e vira pó (raquete)
##   swept     — varrido: sai voando girando na direção `dir` (vassoura)
##   poison    — envenenado: fica verde, se debate e cai sumindo (inseticida)
##   smash_big — esmagado forte: achata muito, sangue grande, tela treme (luva)
##   batted    — rebatido: voa quicando nas bordas, derruba quem tocar (cadeia) e morre esmagado (taco)
##   wet       — encharcado: fica azul, se debate e cai sumindo (pistola de água)
##   blast     — explodido: chamuscado, voa para longe do centro da explosão (bazuca)
func squash(style: String = "smash", dir: Vector2 = Vector2.ZERO) -> void:
	if alive:
		_die(style, dir)

func _die(style: String, dir: Vector2) -> void:
	alive = false
	velocity = Vector2.ZERO
	lifetime_timer.stop()
	GameState.add_kill()
	SaveData.add_coins(1)
	match style:
		"zap":       await _die_zap()
		"swept":     await _die_swept(dir)
		"batted":    await _die_batted(dir)
		"blast":     await _die_swept(dir, false, Color(0.25, 0.2, 0.18))
		"poison":    await _die_poison()
		"wet":       await _die_poison(Color(0.45, 0.7, 1.0), Color(0.3, 0.45, 0.8, 0.0))
		"smash_big": await _die_smash(true)
		_:           await _die_smash(false)
	queue_free()

## Esmagado pelo chinelo: o mosquito fica no mesmo ângulo do voo, como se tivesse
## sido esmagado contra a tela, com asa e patas quebradas soltas e a poça por baixo.
func _die_smash(big: bool) -> void:
	var body: Texture2D = sprite.texture   # frame do voo no instante do tapa
	sprite.texture = _broken_body_texture(body)
	sprite.modulate = Color(0.85, 0.7, 0.7)   # morto: cores mais apagadas, puxando pro vermelho
	_spawn_blood_puddle(big)
	_spawn_broken_parts(body, big)
	if big:
		sprite.scale *= 1.15
		_shake_screen(10.0)
	await get_tree().create_timer(squish_duration * (1.6 if big else 1.0)).timeout

static func _broken_body_texture(body: Texture2D) -> Texture2D:
	if not _broken_cache.has(body):
		var img := body.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for r in BROKEN_PARTS:
			img.fill_rect(r, Color(0, 0, 0, 0))
		_broken_cache[body] = ImageTexture.create_from_image(img)
	return _broken_cache[body]

func _spawn_broken_parts(body: Texture2D, big: bool) -> void:
	var half := Vector2(body.get_size()) / 2.0
	for r in BROKEN_PARTS:
		var piece := Sprite2D.new()
		piece.texture = body
		piece.region_enabled = true
		piece.region_rect = Rect2(r)
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		piece.scale = sprite.scale
		piece.flip_h = sprite.flip_h
		piece.modulate = sprite.modulate
		var offset := (Vector2(r.get_center()) - half) * sprite.scale.x
		if sprite.flip_h:
			offset.x = -offset.x
		## desloca para fora do corpo e entorta
		var push := randf_range(8.0, 16.0) * (1.8 if big else 1.0)
		piece.position = offset + offset.normalized() * push + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		piece.rotation = randf_range(-0.9, 0.9)
		add_child(piece)

func _die_zap() -> void:
	_spawn_fx("sparks")
	sprite.modulate = Color(2.2, 2.4, 3.0)          # clarão do choque
	var tw := create_tween()
	for k in 6:                                     # treme eletrocutado
		tw.tween_property(sprite, "position", Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.035)
	tw.tween_property(sprite, "modulate", Color(0.12, 0.12, 0.15), 0.08)   # carbonizado
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.03)
	await tw.finished
	await get_tree().create_timer(0.12).timeout
	_spawn_fx("ash")                                # vira pó
	sprite.visible = false
	await get_tree().create_timer(0.1).timeout

## `chain`: no caminho, derruba (rebatido também) os mosquitos em que encostar.
func _die_swept(dir: Vector2, chain := false, tint := Color(0.8, 0.8, 0.8)) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var fx := _spawn_fx("drops")
	fx.direction = -dir
	sprite.modulate = tint
	var tw := create_tween().set_parallel()
	if chain:
		tw.tween_method(func(_v: float): _knock_others(dir), 0.0, 1.0, 0.55)
	tw.tween_property(self, "position", position + dir * 360.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "rotation", TAU * 2.0 * signf(dir.x if dir.x != 0.0 else 1.0), 0.55)
	tw.tween_property(sprite, "scale", sprite.scale * 0.6, 0.55)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.55).set_delay(0.15)
	await tw.finished

func _die_batted(dir: Vector2) -> void:
	var v := (dir if dir != Vector2.ZERO else Vector2.RIGHT).normalized() * BAT_SPEED
	var spin := signf(v.x) if v.x != 0.0 else 1.0
	var bounces := 0
	var t := 0.0
	while bounces < BAT_BOUNCES and t < BAT_MAX_T and is_inside_tree():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		position += v * dt
		sprite.rotation += 16.0 * spin * dt
		## Quica na borda do corpo desenhado, como no voo normal.
		var r := arena_rect.grow_individual(-_half_size.x, -_half_size.y, -_half_size.x, -_half_size.y)
		var hit_wall := false
		if (position.x < r.position.x and v.x < 0.0) or (position.x > r.end.x and v.x > 0.0):
			v.x = -v.x
			hit_wall = true
		if (position.y < r.position.y and v.y < 0.0) or (position.y > r.end.y and v.y > 0.0):
			v.y = -v.y
			hit_wall = true
		if hit_wall:
			bounces += 1
			v *= BAT_DAMP
			spin = -spin
			position = position.clamp(r.position, r.end)
			_shake_screen(3.0)
		## Derruba quem estiver no caminho; cada um sai voando para longe e faz o mesmo.
		for m in get_tree().get_nodes_in_group("mosquitos"):
			if m != self and m.alive and m.global_position.distance_to(global_position) <= HIT_RADIUS * 2.4:
				var away: Vector2 = (m.global_position - global_position).normalized()
				m.squash("batted", (away + v.normalized() * 0.5).normalized())
	sprite.rotation = 0.0
	await _die_smash(false)

func _knock_others(dir: Vector2) -> void:
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m != self and m.alive and m.global_position.distance_to(global_position) <= HIT_RADIUS * 2.0:
			m.squash("batted", dir.rotated(randf_range(-0.6, 0.6)))

func _die_poison(tint := Color(0.55, 1.0, 0.4), fade_to := Color(0.35, 0.6, 0.25, 0.0)) -> void:
	sprite.modulate = tint
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", position + Vector2(0, 110), 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "modulate", fade_to, 1.0).set_delay(0.3)
	var wiggle := create_tween()                    # se debatendo
	for k in 8:
		wiggle.tween_property(sprite, "rotation", 0.5 if k % 2 == 0 else -0.5, 0.06)
	wiggle.tween_property(sprite, "rotation", PI, 0.4)   # cai de barriga pra cima
	await tw.finished

func _spawn_blood_puddle(big: bool) -> void:
	var puddle := Node2D.new()
	puddle.set_script(BLOOD_PUDDLE_SCRIPT)
	if big:   # antes do add_child: o _ready da poça já desenha com esses valores
		puddle.main_radius = 50.0
		puddle.nearby_splats = 11
		puddle.far_droplets = 26
	add_child(puddle)
	move_child(puddle, 0)

func _spawn_fx(kind: String) -> Node2D:
	var fx := Node2D.new()
	fx.set_script(DEATH_FX_SCRIPT)
	fx.kind = kind
	fx.area = _half_size
	fx.global_position = global_position
	get_parent().add_child(fx)
	return fx

func _shake_screen(strength: float) -> void:
	shake_scene(get_tree(), strength)

## Tremidinha rápida da cena (o HUD fica num CanvasLayer e não treme).
## Estática para as armas (luva, bazuca) também usarem.
static func shake_scene(tree: SceneTree, strength: float) -> void:
	var scene := tree.current_scene as Node2D
	if scene == null:
		return
	var tw := scene.create_tween()
	for k in 6:
		tw.tween_property(scene, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.03)
	tw.tween_property(scene, "position", Vector2.ZERO, 0.03)

func _on_lifetime_expired() -> void:
	if alive:
		queue_free()
