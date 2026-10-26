extends Node2D

@export var idle_scale: float = 2.9
@export var smack_scale: float = 2.1
@export var smack_duration: float = 0.08
@export var return_duration: float = 0.12

@onready var sprite: Sprite2D = $Sprite2D

var _tween: Tween = null

func _ready() -> void:
	var weapon := Weapons.get_def(SaveData.equipped)
	if weapon.texture != "" and ResourceLoader.exists(weapon.texture):
		sprite.texture = load(weapon.texture)
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
		global_position = event.position
		_hit_mosquitos()
		_play_smack()

## Mata todo mosquito cujo corpo esteja debaixo da sola desenhada do chinelo.
## Usa a escala de repouso (o que o jogador vê ao mirar), não a da animação.
func _hit_mosquitos() -> void:
	for m in get_tree().get_nodes_in_group("mosquitos"):
		if not m.alive:
			continue
		for p in m.hit_points():
			if _sole_covers(p):
				m.squash()
				break

func _sole_covers(global_point: Vector2) -> bool:
	var local := (global_point - sprite.global_position) / idle_scale
	return sprite.is_pixel_opaque(local)

func _play_smack() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(sprite, "scale", Vector2(smack_scale, smack_scale), smack_duration).set_ease(Tween.EASE_OUT)
	_tween.tween_property(sprite, "scale", Vector2(idle_scale, idle_scale), return_duration).set_ease(Tween.EASE_IN)
