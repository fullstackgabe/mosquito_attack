extends Node2D

@onready var arena: Node2D = $Arena

func _ready() -> void:
	randomize()
	GameState.reset()
	var viewport_size := get_viewport_rect().size
	var arena_rect := Rect2(Vector2.ZERO, viewport_size)
	MosquitoSpawner.start(arena, arena_rect)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _exit_tree() -> void:
	MosquitoSpawner.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
