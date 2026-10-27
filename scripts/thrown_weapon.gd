extends Sprite2D

## Arma arremessada (ursinho, tênis, bola): voa girando, mata tudo
## que o sprite tocar e emite `finished` quando acaba.
##   padrão     — linha reta até sair da tela
##   bounces    — quica nas bordas da tela N vezes, depois sai (ursinho)
##   bounce_time — quica nas bordas durante N segundos, depois sai (bola)
##   boomerang  — vai até `target` e volta para `home` (tênis)

signal finished

const SPIN := 14.0   # rad/s

var velocity := Vector2.ZERO
var arena := Rect2()
var death := "smash_big"
var bounces := 0
var bounce_time := 0.0
var boomerang := false
var target := Vector2.ZERO
var home := Vector2.ZERO
var radius := 0.0   ## meio tamanho do desenho: o quique é na borda do sprite

var _t := 0.0
var _entered := false    # só quica depois de entrar na tela (nasce abaixo dela)
var _returning := false

func _process(delta: float) -> void:
	_t += delta
	if not (boomerang and _tick_boomerang(delta)):
		position += velocity * delta
	rotation += SPIN * delta
	var inner := arena.grow(-radius)
	if inner.has_point(position):
		_entered = true
	elif _entered and (bounces > 0 or _t < bounce_time):
		_bounce(inner)
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if not m.alive:
			continue
		for p in m.hit_points():
			if is_pixel_opaque(to_local(p)):
				m.squash(death, velocity.normalized())
				break
	if not boomerang and not arena.grow(200.0).has_point(position):
		_finish()

func _bounce(inner: Rect2) -> void:
	if position.x < inner.position.x or position.x > inner.end.x:
		velocity.x = -velocity.x
	if position.y < inner.position.y or position.y > inner.end.y:
		velocity.y = -velocity.y
	position = position.clamp(inner.position, inner.end)
	bounces -= 1

## true quando já posicionou neste frame (parou exatamente na mira para virar).
func _tick_boomerang(delta: float) -> bool:
	var speed := velocity.length()
	if not _returning and position.distance_to(target) <= speed * delta:
		position = target   # passa exatamente pela mira antes de voltar
		_returning = true
		velocity = (home - position).normalized() * speed
		return true
	if _returning:
		if position.distance_to(home) <= speed * delta:
			_finish()
			return true
		velocity = (home - position).normalized() * speed
	return false

func _finish() -> void:
	finished.emit()
	queue_free()
