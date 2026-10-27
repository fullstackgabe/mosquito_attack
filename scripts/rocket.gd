extends Node2D

## Míssil da bazuca: sai da boca da arma com um clarão, acelera deixando um rastro de
## fumaça até `target` e explode lá, matando tudo num raio de `blast_radius`.
## Sprite: `missil.png` (a arte antiga da bazuca, que na verdade era um míssil).

const BOOM_TIME   := 0.4
const FLASH_TIME  := 0.12
const START_SPEED := 450.0    ## sai devagar da arma para dar para ver o míssil saindo
const ACCEL       := 4200.0
const PUFF_EVERY  := 0.025    ## s entre bolinhas de fumaça
const PUFF_LIFE   := 0.45
const MISSILE_TEX := preload("res://art/objects/bazuca/missil.png")
const MISSILE_NOSE_DEG := 135.0   ## para onde o bico aponta no PNG (graus, 0 = direita)
const MISSILE_SCALE := 1.6

var target := Vector2.ZERO
var speed := 1600.0          ## velocidade máxima
var blast_radius := 220.0
var death := "blast"

var _v := START_SPEED
var _t := 0.0
var _boom_t := -1.0          ## < 0: ainda voando
var _start := Vector2.ZERO
var _dir := Vector2.RIGHT
var _puff_t := 0.0
var _puffs: Array = []       ## [{pos (global), t}]
var _sprite: Sprite2D

func _ready() -> void:
	_start = global_position
	_dir = (target - global_position).normalized()
	_sprite = Sprite2D.new()
	_sprite.texture = MISSILE_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * MISSILE_SCALE
	_sprite.rotation = _dir.angle() - deg_to_rad(MISSILE_NOSE_DEG)
	add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	for p in _puffs:
		p.t += delta
	_puffs = _puffs.filter(func(p): return p.t < PUFF_LIFE)
	if _boom_t < 0.0:
		_v = minf(speed, _v + ACCEL * delta)
		var to := target - global_position
		if to.length() <= _v * delta:
			global_position = target
			_explode()
		else:
			global_position += to.normalized() * _v * delta
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = PUFF_EVERY
				## fumaça sai da cauda (atrás do míssil)
				_puffs.append({"pos": global_position - _dir * 40.0 + Vector2(randf_range(-5, 5), randf_range(-5, 5)), "t": 0.0})
	else:
		_boom_t += delta
		if _boom_t >= BOOM_TIME and _puffs.is_empty():
			queue_free()
	queue_redraw()

func _explode() -> void:
	_boom_t = 0.0
	_sprite.visible = false
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and m.global_position.distance_to(global_position) <= blast_radius + m.HIT_RADIUS * 0.5:
			var away: Vector2 = (m.global_position - global_position).normalized()
			m.squash(death, away if away != Vector2.ZERO else Vector2.UP)
	Mosquito.shake_scene(get_tree(), 16.0)

func _draw() -> void:
	## Rastro: bolinhas cinza que crescem e somem.
	for p in _puffs:
		var k: float = p.t / PUFF_LIFE
		draw_circle(to_local(p.pos), 8.0 + 16.0 * k, Color(0.75, 0.75, 0.72, 0.55 * (1.0 - k)))
	## Clarão na boca da bazuca logo que dispara.
	if _t < FLASH_TIME:
		var a := 1.0 - _t / FLASH_TIME
		var c := to_local(_start)
		draw_circle(c, 34.0 * a + 10.0, Color(1.0, 0.75, 0.2, 0.8 * a))
		draw_circle(c, 18.0 * a + 4.0, Color(1.0, 0.97, 0.7, a))
	## Chama na cauda enquanto voa.
	if _boom_t < 0.0:
		var tail := -_dir * 44.0
		draw_circle(tail, 9.0 + randf() * 5.0, Color(1.0, 0.6, 0.1, 0.9))
		draw_circle(tail, 5.0, Color(1.0, 0.95, 0.6))
		return
	## Explosão: bola de fogo que cresce e some, anel claro na borda.
	if _boom_t < BOOM_TIME:
		var k := _boom_t / BOOM_TIME
		var r := blast_radius * (0.4 + 0.6 * sqrt(k))
		var a2 := 1.0 - k
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.1, 0.55 * a2))
		draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.85, 0.3, 0.7 * a2))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.95, 0.7, a2), 6.0)
