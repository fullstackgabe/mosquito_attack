extends Node2D

@export var main_radius: float = 36.0
@export var color: Color = Color(0.72, 0.08, 0.1, 0.95)
@export var splat_count: int = 5

var _positions: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_positions.append(Vector2.ZERO)
	_radii.append(main_radius)
	for i in range(splat_count):
		var angle := TAU * float(i) / float(splat_count) + randf_range(-0.4, 0.4)
		var dist := main_radius * randf_range(0.65, 1.05)
		_positions.append(Vector2(cos(angle), sin(angle)) * dist)
		_radii.append(main_radius * randf_range(0.22, 0.42))
	queue_redraw()

func _draw() -> void:
	for i in range(_positions.size()):
		draw_circle(_positions[i], _radii[i], color)
