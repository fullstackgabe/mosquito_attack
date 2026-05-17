extends Node2D

@export var main_radius: float = 28.0
@export var color: Color = Color(0.72, 0.08, 0.1, 0.95)
@export var nearby_splats: int = 7
@export var far_droplets: int = 14

var _positions: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_positions.append(Vector2.ZERO)
	_radii.append(main_radius)

	for i in range(nearby_splats):
		var angle := TAU * float(i) / float(nearby_splats) + randf_range(-0.5, 0.5)
		var dist := main_radius * randf_range(0.55, 1.15)
		_positions.append(Vector2(cos(angle), sin(angle)) * dist)
		_radii.append(main_radius * randf_range(0.20, 0.45))

	for _i in range(far_droplets):
		var angle := randf() * TAU
		var dist := main_radius * randf_range(1.4, 2.8)
		_positions.append(Vector2(cos(angle), sin(angle)) * dist)
		_radii.append(main_radius * randf_range(0.06, 0.18))

	queue_redraw()

func _draw() -> void:
	for i in range(_positions.size()):
		draw_circle(_positions[i], _radii[i], color)
