class_name Mosquito
extends Area2D

@export var speed_min: float = 80.0
@export var speed_max: float = 220.0
@export var lifetime_min: float = 3.0
@export var lifetime_max: float = 8.0
@export var squish_duration: float = 0.4

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer

const TEX_FLY: Texture2D = preload("res://art/mosquitos/common/fly/south.png")
const BLOOD_PUDDLE_SCRIPT: Script = preload("res://scripts/blood_puddle.gd")

var velocity: Vector2 = Vector2.ZERO
var alive: bool = true
var arena_rect: Rect2

func _ready() -> void:
	var angle := randf() * TAU
	var speed := randf_range(speed_min, speed_max)
	velocity = Vector2(cos(angle), sin(angle)) * speed

	lifetime_timer.wait_time = randf_range(lifetime_min, lifetime_max)
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	lifetime_timer.start()

	input_event.connect(_on_input_event)
	_update_facing()

func setup(arena: Rect2) -> void:
	arena_rect = arena

func _physics_process(delta: float) -> void:
	if not alive:
		return
	position += velocity * delta
	_bounce_off_walls()
	_update_facing()

func _bounce_off_walls() -> void:
	if arena_rect.size == Vector2.ZERO:
		return
	if position.x < arena_rect.position.x and velocity.x < 0.0:
		velocity.x = -velocity.x
		position.x = arena_rect.position.x
	elif position.x > arena_rect.end.x and velocity.x > 0.0:
		velocity.x = -velocity.x
		position.x = arena_rect.end.x
	if position.y < arena_rect.position.y and velocity.y < 0.0:
		velocity.y = -velocity.y
		position.y = arena_rect.position.y
	elif position.y > arena_rect.end.y and velocity.y > 0.0:
		velocity.y = -velocity.y
		position.y = arena_rect.end.y

func _update_facing() -> void:
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not alive:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed:
		_die()

func _die() -> void:
	alive = false
	velocity = Vector2.ZERO
	_spawn_blood_puddle()
	sprite.modulate = Color(0.08, 0.08, 0.08, 0.9)
	sprite.scale *= 0.9
	lifetime_timer.stop()
	GameState.add_kill()
	await get_tree().create_timer(squish_duration).timeout
	queue_free()

func _spawn_blood_puddle() -> void:
	var puddle := Node2D.new()
	puddle.set_script(BLOOD_PUDDLE_SCRIPT)
	add_child(puddle)
	move_child(puddle, 0)

func _on_lifetime_expired() -> void:
	if alive:
		queue_free()
