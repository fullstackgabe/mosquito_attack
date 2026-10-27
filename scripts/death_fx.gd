extends Node2D

## Partículas simples (quadradinhos/linhas em pixel art) das mortes dos mosquitos.
## Criado no Arena, independente do mosquito, e se apaga sozinho.
##   sparks — faíscas azuis saindo do centro (choque da raquete)
##   ash    — pó de cinza que se espalha e cai (mosquito eletrocutado virando pó)
##   drops  — gotinhas de sangue espirrando numa direção (vassoura)
##   splat  — respingos de sangue saindo em todas as direções e freando (chinelo)

const GRAVITY := 420.0

var kind := "sparks"
var direction := Vector2.ZERO   # viés de direção (drops)
var area := Vector2(36, 36)      # meia-largura/altura do corpo (ash nasce espalhado nele)

var _p: Array = []   # cada partícula: {pos, vel, life, max, size, color}
var _t := 0.0

func _ready() -> void:
	match kind:
		"sparks":
			for i in 10:
				var a := randf() * TAU
				_add(Vector2.ZERO, Vector2.RIGHT.rotated(a) * randf_range(180, 420), randf_range(0.15, 0.3),
					3.0, Color(0.7, 0.95, 1.0) if i % 2 == 0 else Color.WHITE)
		"ash":
			for i in 46:
				var p := Vector2(randf_range(-area.x, area.x), randf_range(-area.y, area.y)) * 0.75
				var v := Vector2(randf_range(-50, 50), randf_range(-90, 10))
				var g := randf_range(0.12, 0.35)
				_add(p, v, randf_range(0.6, 1.1), [3.0, 4.0, 5.0][i % 3], Color(g, g, g * 1.1))
		"splat":
			for i in 14:
				var a := TAU * i / 14.0 + randf_range(-0.2, 0.2)
				_add(Vector2.ZERO, Vector2.RIGHT.rotated(a) * randf_range(220, 520), randf_range(0.25, 0.45),
					randf_range(3.0, 7.0), Color(0.72, 0.08, 0.1) if i % 3 else Color(0.85, 0.15, 0.15))
		"drops":
			for i in 12:
				var d := (direction + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))).normalized()
				_add(Vector2.ZERO, d * randf_range(150, 380), randf_range(0.35, 0.6),
					randf_range(3.0, 6.0), Color(0.72, 0.08, 0.1))

func _add(pos: Vector2, vel: Vector2, life: float, size: float, color: Color) -> void:
	_p.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": size, "color": color})

func _process(delta: float) -> void:
	_t += delta
	var alive := 0
	for p in _p:
		if p.life <= 0.0:
			continue
		p.life -= delta
		var gravity := GRAVITY if kind in ["ash", "drops"] else 0.0
		p.vel.y += gravity * delta
		if kind == "ash":
			p.vel.x *= 0.96   # pó freia no ar
		elif kind == "splat":
			p.vel *= pow(0.86, delta * 60.0)   # respingo freia rápido (vista de cima, sem gravidade)
		p.pos += p.vel * delta
		alive += 1
	if alive == 0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	for p in _p:
		if p.life <= 0.0:
			continue
		var c: Color = p.color
		c.a = clampf(p.life / p.max, 0.0, 1.0)
		if kind == "sparks":
			draw_line(p.pos, p.pos - p.vel.normalized() * 14.0, c, p.size)
		else:
			var s: float = p.size
			draw_rect(Rect2(p.pos - Vector2(s, s) / 2.0, Vector2(s, s)), c)
