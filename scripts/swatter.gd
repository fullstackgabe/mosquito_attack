extends Node2D

@export var idle_scale: float = 2.9
@export var smack_scale: float = 2.1
@export var smack_duration: float = 0.08
@export var return_duration: float = 0.12

@onready var sprite: Sprite2D = $Sprite2D

var _tween: Tween = null

func _ready() -> void:
	sprite.scale = Vector2(idle_scale, idle_scale)
	set_process(true)

func _process(_delta: float) -> void:
	global_position = get_viewport().get_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed:
		_play_smack()

func _play_smack() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(sprite, "scale", Vector2(smack_scale, smack_scale), smack_duration).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "scale", Vector2(idle_scale, idle_scale), return_duration).set_ease(Tween.EASE_IN)
