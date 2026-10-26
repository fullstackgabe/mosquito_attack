class_name Weapons
extends RefCounted

## Catálogo de armas. `locked` = ainda não implementada (aparece como “Em breve”).
## A primeira da lista é a arma padrão, que o jogador já começa tendo.
const DEFS := [
	{"id": "chinelo",    "name": "Chinelo",          "price": 0,
	 "desc": "O clássico. Um tapa certeiro.",
	 "texture": "res://art/objects/chinelo/chinelo.png", "locked": false},
	{"id": "raquete",    "name": "Raquete Elétrica", "price": 150,
	 "desc": "Área grande e choque.\nA bateria acaba.",
	 "texture": "", "locked": true},
	{"id": "vassoura",   "name": "Vassoura",         "price": 300,
	 "desc": "Golpe largo, mata vários.\nMas é lenta.",
	 "texture": "", "locked": true},
	{"id": "inseticida", "name": "Inseticida",       "price": 500,
	 "desc": "Segure para soltar a nuvem.\nO spray acaba.",
	 "texture": "", "locked": true},
	{"id": "chinelo_vo", "name": "Chinelo da Vó",    "price": 1000,
	 "desc": "Arremessado, atravessa\na tela inteira.",
	 "texture": "", "locked": true},
]

const DEFAULT_ID := "chinelo"

static func get_def(id: String) -> Dictionary:
	for w in DEFS:
		if w.id == id:
			return w
	return DEFS[0]
