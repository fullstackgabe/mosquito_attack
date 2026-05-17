extends Node

signal score_changed(new_score: int)

var score: int = 0

func add_kill() -> void:
	score += 1
	score_changed.emit(score)

func reset() -> void:
	score = 0
	score_changed.emit(score)
