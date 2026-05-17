extends Node

const MOSQUITO_SCENE: PackedScene = preload("res://scenes/mosquito.tscn")

@export var spawn_interval_min: float = 0.7
@export var spawn_interval_max: float = 1.6
@export var max_alive: int = 6
@export var edge_margin: float = 60.0

var _spawn_root: Node = null
var _arena_rect: Rect2 = Rect2()
var _timer: Timer = null
var _alive_mosquitos: Array[Mosquito] = []
var _active: bool = false

func start(spawn_root: Node, arena_rect: Rect2) -> void:
	_spawn_root = spawn_root
	_arena_rect = arena_rect
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_on_timer)
		add_child(_timer)
	_active = true
	_schedule_next()

func stop() -> void:
	_active = false
	if _timer:
		_timer.stop()

func _schedule_next() -> void:
	if not _active:
		return
	_timer.wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	_timer.start()

func _on_timer() -> void:
	_purge_dead()
	if _alive_mosquitos.size() < max_alive:
		_spawn_one()
	_schedule_next()

func _spawn_one() -> void:
	if _spawn_root == null:
		return
	var inset := _arena_rect.grow(-edge_margin)
	var pos := Vector2(
		randf_range(inset.position.x, inset.end.x),
		randf_range(inset.position.y, inset.end.y)
	)
	var m := MOSQUITO_SCENE.instantiate() as Mosquito
	m.position = pos
	m.setup(_arena_rect)
	_spawn_root.add_child(m)
	_alive_mosquitos.append(m)

func _purge_dead() -> void:
	_alive_mosquitos = _alive_mosquitos.filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
