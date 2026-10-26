extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	SaveData.coins_changed.connect(_on_coins_changed)
	_on_score_changed(GameState.score)
	_on_coins_changed(SaveData.coins)

func _on_score_changed(value: int) -> void:
	score_label.text = "%d" % value

func _on_coins_changed(value: int) -> void:
	coins_label.text = "Moedas: %d" % value
