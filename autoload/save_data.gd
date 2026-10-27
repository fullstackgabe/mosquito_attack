extends Node

## Progresso salvo entre partidas: moedas, armas compradas e arma equipada.

signal coins_changed(new_coins: int)

const SAVE_PATH := "user://save.cfg"

var coins: int = 0
var owned: Array = [Weapons.DEFAULT_ID]
var equipped: String = Weapons.DEFAULT_ID

func _ready() -> void:
	_load()

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save()

func owns(id: String) -> bool:
	return owned.has(id)

## Compra a arma se houver moedas e ela estiver liberada. Retorna true se comprou.
func buy(id: String) -> bool:
	var w := Weapons.get_def(id)
	if w.locked or owns(id) or coins < w.price:
		return false
	coins -= w.price
	owned.append(id)
	coins_changed.emit(coins)
	save()
	return true

func equip(id: String) -> void:
	if owns(id):
		equipped = id
		save()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "owned", owned)
	cfg.set_value("progress", "equipped", equipped)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins    = cfg.get_value("progress", "coins", 0)
	owned    = cfg.get_value("progress", "owned", [Weapons.DEFAULT_ID])
	equipped = cfg.get_value("progress", "equipped", Weapons.DEFAULT_ID)
	if not owned.has(Weapons.DEFAULT_ID):
		owned.append(Weapons.DEFAULT_ID)
	## arma removida do jogo (ex.: Havaiana de Pau, 26/10/2026) volta para a padrão
	if not owned.has(equipped) or Weapons.get_def(equipped).id != equipped:
		equipped = Weapons.DEFAULT_ID
