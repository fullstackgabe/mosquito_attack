extends Node

const MOSQUITO_SCENE: PackedScene = preload("res://scenes/mosquito.tscn")

## Dificuldade progressiva: vai de 0 (início) a 1 (teto) em RAMP_TIME segundos
## de partida e para ali — os valores "max" abaixo são o limite.
const RAMP_TIME := 120.0

@export var spawn_interval_min: float = 0.7    # início
@export var spawn_interval_max: float = 1.6
@export var spawn_interval_min_cap: float = 0.25   # teto da dificuldade
@export var spawn_interval_max_cap: float = 0.6
@export var max_alive: int = 6
@export var max_alive_cap: int = 18
@export var speed_mult_cap: float = 2.2        # velocidade multiplicada por até 2.2×
@export var lifetime_mult_cap: float = 0.45    # tempo na tela cai para até 45%
@export var edge_margin: float = 60.0

var _spawn_root: Node = null
var _arena_rect: Rect2 = Rect2()
var _timer: Timer = null
var _alive_mosquitos: Array[Mosquito] = []
var _active: bool = false
var _elapsed: float = 0.0

func start(spawn_root: Node, arena_rect: Rect2) -> void:
	_spawn_root = spawn_root
	_arena_rect = arena_rect
	_elapsed = 0.0
	_alive_mosquitos.clear()
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

func _process(delta: float) -> void:
	if _active:
		_elapsed += delta

## 0.0 no começo da partida, 1.0 no teto (depois de RAMP_TIME segundos).
func difficulty() -> float:
	return clampf(_elapsed / RAMP_TIME, 0.0, 1.0)

func _schedule_next() -> void:
	if not _active:
		return
	var d := difficulty()
	_timer.wait_time = randf_range(
		lerpf(spawn_interval_min, spawn_interval_min_cap, d),
		lerpf(spawn_interval_max, spawn_interval_max_cap, d))
	_timer.start()

func _on_timer() -> void:
	_purge_dead()
	if _alive_mosquitos.size() < roundi(lerpf(max_alive, max_alive_cap, difficulty())):
		_spawn_one()
	_schedule_next()

func _spawn_one() -> void:
	if _spawn_root == null or not is_instance_valid(_spawn_root):
		return
	var inset := _arena_rect.grow(-edge_margin)
	var pos := Vector2(
		randf_range(inset.position.x, inset.end.x),
		randf_range(inset.position.y, inset.end.y)
	)
	var d := difficulty()
	var m := MOSQUITO_SCENE.instantiate() as Mosquito
	m.position = pos
	m.setup(_arena_rect)
	var speed_mult := lerpf(1.0, speed_mult_cap, d)
	var life_mult := lerpf(1.0, lifetime_mult_cap, d)
	m.speed_min *= speed_mult
	m.speed_max *= speed_mult
	m.lifetime_min *= life_mult
	m.lifetime_max *= life_mult
	_spawn_root.add_child(m)
	_alive_mosquitos.append(m)

func _purge_dead() -> void:
	_alive_mosquitos = _alive_mosquitos.filter(func(m): return is_instance_valid(m) and m.alive and not m.is_queued_for_deletion())
