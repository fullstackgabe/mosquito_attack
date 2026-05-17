extends Node2D

@onready var arena: Node2D = $Arena

func _ready() -> void:
	randomize()
	GameState.reset()
	var viewport_size := get_viewport_rect().size
	var arena_rect := Rect2(Vector2.ZERO, viewport_size)
	MosquitoSpawner.start(arena, arena_rect)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
