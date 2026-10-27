extends Node2D

## Nuvem do inseticida: cresce, mata os mosquitos que tocar e some.

const LIFE := 0.8

var max_radius := 110.0
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var r := _radius()
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if m.alive and m.global_position.distance_to(global_position) <= r + m.HIT_RADIUS * 0.5:
			m.squash("poison")
	queue_redraw()

func _radius() -> float:
	return lerpf(max_radius * 0.35, max_radius, minf(_t / (LIFE * 0.5), 1.0))

func _draw() -> void:
	var a := 0.45 * (1.0 - _t / LIFE)
	draw_circle(Vector2.ZERO, _radius(), Color(0.55, 0.85, 0.35, a))
	draw_circle(Vector2.ZERO, _radius() * 0.6, Color(0.75, 0.95, 0.55, a))
