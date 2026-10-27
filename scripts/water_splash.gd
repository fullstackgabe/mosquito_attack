extends Node2D

## Marca do tiro de água na parede: a parede fica **molhada** (mancha translúcida mais
## escura, não uma poça azul), com respingos saindo do ponto de impacto, gotinhas
## brilhando e água escorrendo para baixo. No impacto, um estouro de gotas voa para
## fora e cai. Pixel art em blocos de CELL px. Fica `life` s e seca nos últimos 40%;
## mosquito que encostar na parte molhada se afoga.

const CELL := 4.0
const C_WET   := Color(0.18, 0.48, 0.78, 0.36)   ## parede molhada
const C_WET_D := Color(0.10, 0.38, 0.70, 0.55)   ## miolo mais encharcado
const C_SHINE := Color(0.88, 0.96, 1.0, 0.95)    ## gotinha brilhando
const C_DROP  := Color(0.10, 0.38, 0.70, 0.85)   ## gota voando (cor do jato)
const BURST_TIME := 0.35

var radius := 60.0
var life := 3.0
var death := "wet"

var _t := 0.0
var _wet: Dictionary = {}    ## Vector2i -> 1 (molhado) ou 2 (miolo encharcado)
var _shines: Array = []      ## Vector2i das gotinhas brilhando
var _drips: Array = []       ## [coluna, linha inicial, comprimento máx (células), velocidade células/s]
var _burst: Array = []       ## [pos, vel] das gotas do estouro

func _ready() -> void:
	## Mancha: miolo irregular + respingos em raios saindo do impacto (cada raio uma
	## fileira de gotas que diminuem e se separam) — água batendo forte na parede.
	var blobs := []
	for i in 5:
		var a := randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * radius * randf_range(0.0, 0.3), radius * randf_range(0.35, 0.5)])
	for i in randi_range(9, 13):
		var a := randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var reach := radius * randf_range(0.9, 1.7)
		var r0 := radius * randf_range(0.08, 0.14)
		var d := radius * 0.4
		while d < reach:
			blobs.append([dir * d, r0 * (1.0 - 0.6 * d / reach)])
			d += r0 * randf_range(1.6, 3.2)
	var n := int(ceil(radius * 1.9 / CELL))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var p := Vector2(gx, gy) * CELL
			for b in blobs:
				if p.distance_to(b[0]) <= b[1]:
					_wet[Vector2i(gx, gy)] = 2 if p.length() < radius * 0.3 else 1
					break
	var keys := _wet.keys()
	keys.shuffle()
	for i in mini(10, keys.size()):
		_shines.append(keys[i])
	## Escorridos: descem da parte de baixo da mancha.
	var bottoms := {}
	for c in _wet:
		if (Vector2(c) * CELL).length() < radius * 0.55 and (not bottoms.has(c.x) or c.y > bottoms[c.x]):
			bottoms[c.x] = c.y
	var cols := bottoms.keys()
	cols.shuffle()
	for i in mini(4, cols.size()):
		_drips.append([cols[i], bottoms[cols[i]] + 1, randi_range(8, 26), randf_range(8.0, 16.0)])
	## Estouro: gotas voando para fora do impacto.
	for i in 16:
		var a := randf() * TAU
		_burst.append([Vector2.ZERO, Vector2(cos(a), sin(a)) * randf_range(250.0, 600.0)])

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	for b in _burst:
		b[1].y += 1400.0 * delta   ## gravidade
		b[0] += b[1] * delta
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and _touches(m.global_position - global_position, m.HIT_RADIUS * 0.4):
			m.squash(death)
	queue_redraw()

## Afoga quem encostar na parte molhada (miolo ou respingos), não num círculo.
func _touches(rel: Vector2, slack: float) -> bool:
	if rel.length() > radius * 1.9 + slack:
		return false
	var c := Vector2i((rel / CELL).round())
	var r := int(ceil(slack / CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _wet.has(c + Vector2i(dx, dy)):
				return true
	return false

func _draw() -> void:
	var a := clampf(1.0 - (_t - life * 0.6) / (life * 0.4), 0.0, 1.0)   ## seca no fim
	var sq := Vector2(CELL, CELL)
	for c in _wet:
		var col: Color = C_WET_D if _wet[c] == 2 else C_WET
		draw_rect(Rect2(Vector2(c) * CELL, sq), Color(col, col.a * a))
	for d in _drips:
		var len: int = mini(d[2], int(d[3] * _t))
		for i in len:   ## filete de 2 blocos que afina para 1 no fim
			var w := 2.0 if i < len * 0.6 else 1.0
			draw_rect(Rect2(Vector2(d[0], d[1] + i) * CELL, Vector2(w, 1) * CELL), Color(C_WET_D, C_WET_D.a * a))
		if len > 0:   ## gota na ponta do escorrido
			draw_rect(Rect2(Vector2(d[0] - 0.5, d[1] + len) * CELL, Vector2(2, 2) * CELL), Color(C_WET_D, C_WET_D.a * a))
			draw_rect(Rect2(Vector2(d[0], d[1] + len) * CELL, sq), Color(C_SHINE, a))
	for s in _shines:
		draw_rect(Rect2(Vector2(s) * CELL, sq), Color(C_SHINE, C_SHINE.a * a))
	if _t < BURST_TIME:
		var ba := 1.0 - _t / BURST_TIME
		for b in _burst:
			draw_rect(Rect2((b[0] - sq).snapped(sq), sq * 2.0), Color(C_DROP, ba))
