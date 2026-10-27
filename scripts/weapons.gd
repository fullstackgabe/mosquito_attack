class_name Weapons
extends RefCounted

## Catálogo de armas. `locked` = ainda não implementada (aparece como “Em breve”).
## A primeira da lista é a arma padrão, que o jogador já começa tendo. A ordem é a da
## loja, definida pelo usuário (26/10/2026).
##
## `kind` define a mecânica (implementada em swatter.gd):
##   tap   — clique bate onde está o cursor; mata o que estiver sob o sprite.
##           `cooldown`: espera entre golpes.
##           `sweep`: em graus; o golpe varre um arco a partir do cabo, da direita para a
##           esquerda como um destro (vassoura, jornal, toalha, taco).
##   field — clique gasta 1 carga da bateria (`charges`; a raquete usa 1 só) e liga um campo de energia em
##           volta do cursor (`field_radius`) por `field_time` s; mata o que encostar.
##           Com o campo desligado, recupera 1 carga a cada `recharge` s (mesmo sem
##           ter zerado). Se zerar a bateria, espera `empty_recharge` s e volta cheia (todas as cargas).
##   spray — segurar o botão solta nuvens que matam o que tocam; `drain`/`refill` do tanque.
##   throw — clique arremessa a arma, que atravessa a tela; só volta depois que sai.
##           `bounces`: quica N vezes nas bordas; `bounce_time`: quica por N s;
##           `boomerang`: vai até a mira e volta.
##   jet   — clique solta um jato único da arma (embaixo da tela) até a mira, por
##           `jet_time` s; `jet_width`; `cooldown` entre jatos. Onde o jato bate fica
##           uma mancha d'água (`splash_radius`, `splash_life` s) que afoga quem encostar.
##   rocket — clique dispara um foguete da arma até a mira; explode em `blast_radius`.
## `flip_h` / `flip_v`: espelha o sprite.
## `slam_radius` (tap): tapa que mata tudo nesse raio em volta do cursor (sem uso hoje).
## `punch` (tap): soco que sobe e volta — mata o que estiver no caminho (luva de boxe).
## `thick`: multiplica só a largura do sprite (taco mais grosso).
## `no_bar`: tem espera, mas sem barra na tela (taco, chicote).
## `crack` (tap): chicote — parado é a imagem da loja; ao chicotear a corda (`crack_coil`, linha
## central no PNG) desenrola reta para cima e estala na mira. `crack_handle`: fim do cabo.
## `launcher_angle`: a arma fica fixa embaixo da tela apontando para a mira; é a
## direção do cano no PNG, em graus (0 = direita, 90 = baixo).
## `crosshair`: o cursor vira uma mira e o sprite da arma só aparece no arremesso.
## `death`: animação de morte do mosquito (ver Mosquito.squash).
## `aim_y`: linha do PNG (px a partir do topo) que fica sob o cursor — ex.: centro
## da cabeça da raquete, bico do spray. Sem ele, o centro da imagem.
const DEFS := [
	## Tapa
	{"id": "chinelo",    "name": "Chinelo",          "price": 0,
	 "desc": "O clássico. Tapa certeiro.",
	 "texture": "res://art/objects/chinelo/chinelo.png", "locked": false,
	 "kind": "tap", "scale": 2.9, "death": "smash"},
	{"id": "livro",        "name": "Livro",            "price": 200,
	 "desc": "Tapa com área maior.",
	 "texture": "res://art/objects/livro/livro.png", "locked": false,
	 "kind": "tap", "scale": 3.6, "death": "smash"},
	{"id": "luva",         "name": "Luva de Boxe",     "price": 700,
	 "desc": "Soco que joga pra cima.",
	 "texture": "res://art/objects/luva/luva.png", "locked": false,
	 "kind": "tap", "scale": 3.4, "punch": true, "death": "swept"},
	## Varredura / golpe
	{"id": "vassoura",   "name": "Vassoura",         "price": 300,
	 "desc": "Varre vários de uma vez.",
	 "texture": "res://art/objects/vassoura/vassoura.png", "locked": false,
	 "kind": "tap", "scale": 4.2, "sweep": 110.0, "cooldown": 0.9, "death": "swept"},
	{"id": "jornal",       "name": "Jornal",           "price": 100,
	 "desc": "Varredura rápida.",
	 "texture": "res://art/objects/jornal/jornal.png", "locked": false,
	 "kind": "tap", "scale": 3.6, "sweep": 100.0, "cooldown": 0.5, "death": "swept"},
	{"id": "taco",         "name": "Taco de Baseball", "price": 400,
	 "desc": "Rebate nos outros.",
	 "texture": "res://art/objects/taco/taco.png", "locked": false,
	 "kind": "tap", "scale": 4.6, "thick": 1.6, "aim_y": 16, "sweep": 110.0, "cooldown": 0.6, "no_bar": true, "death": "batted"},
	{"id": "toalha",       "name": "Chicote",          "price": 350,
	 "desc": "Chicotada de longe.",
	 "texture": "res://art/objects/chicote/chicote.png", "locked": false,
	 "kind": "tap", "scale": 3.0, "crack": true, "crack_handle": [4, 59],
	 "crack_coil": [[17, 39], [16, 26], [23, 16], [35, 15], [42, 18], [46, 25], [46, 33], [40, 40], [33, 39], [29, 31], [32, 24], [39, 21], [48, 21], [52, 15], [51, 9], [55, 5]],
	 "cooldown": 0.55, "no_bar": true, "death": "swept"},
	## Arremesso com mira
	{"id": "ursinho",      "name": "Ursinho",          "price": 250,
	 "desc": "Arremesso em linha reta.",
	 "texture": "res://art/objects/ursinho/ursinho.png", "locked": false,
	 "kind": "throw", "crosshair": true, "scale": 2.6, "throw_speed": 1800.0, "death": "smash"},
	{"id": "tenis",        "name": "Tênis All Star",   "price": 600,
	 "desc": "Arremesso rápido e reto.",
	 "texture": "res://art/objects/tenis/tenis.png", "locked": false,
	 "kind": "throw", "crosshair": true, "scale": 2.6, "throw_speed": 2000.0, "death": "smash"},
	{"id": "bola",         "name": "Bola de Basquete", "price": 800,
	 "desc": "Quica pela tela por 3 s.",
	 "texture": "res://art/objects/bola/bola.png", "locked": false,
	 "kind": "throw", "crosshair": true, "scale": 2.2, "throw_speed": 1400.0, "bounce_time": 3.0, "death": "smash"},
	## Área, nuvem e tiro (ordem pedida pelo usuário)
	{"id": "raquete",    "name": "Raquete Elétrica", "price": 150,
	 "desc": "Campo elétrico.",
	 "texture": "res://art/objects/raquete/raquete.png", "locked": false,
	 "kind": "field", "scale": 3.8, "aim_y": 20, "field_radius": 115.0, "field_time": 1.6, "charges": 1, "recharge": 1.8, "empty_recharge": 1.8, "death": "zap"},
	{"id": "inseticida", "name": "Inseticida",       "price": 500,
	 "desc": "Segure para borrifar.",
	 "texture": "res://art/objects/inseticida/inseticida.png", "locked": false,
	 "kind": "spray", "scale": 2.2, "aim_y": 7, "cloud_radius": 110.0, "drain": 0.45, "refill": 0.25, "death": "poison"},
	{"id": "pistola_agua", "name": "Rifle de Água",    "price": 900,
	 "desc": "Jato que afoga.",
	 "texture": "res://art/objects/pistola_agua/pistola_agua.png", "locked": false,
	 "kind": "jet", "crosshair": true, "scale": 2.6, "launcher_angle": 0.0, "jet_width": 26.0,
	 "jet_time": 0.25, "cooldown": 0.3, "splash_radius": 75.0, "splash_life": 3.0, "death": "wet"},
	{"id": "bazuca",       "name": "Bazuca",           "price": 2000,
	 "desc": "Míssil explosivo.",
	 "texture": "res://art/objects/bazuca/bazuca.png", "locked": false,
	 "kind": "rocket", "crosshair": true, "scale": 3.0, "launcher_angle": -30.0, "cooldown": 2.0,
	 "rocket_speed": 1700.0, "blast_radius": 360.0, "death": "blast"},
]

const DEFAULT_ID := "chinelo"

static func get_def(id: String) -> Dictionary:
	for w in DEFS:
		if w.id == id:
			return w
	return DEFS[0]
