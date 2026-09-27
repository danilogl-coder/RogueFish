class_name Shop
extends RefCounted
## Pearl shop of the "Marés Profundas" expansion: things to spend pearls on
## besides characters and permanent upgrades.
##
##  relic     : permanent unlocks that change how runs work (VS "relics")
##  tide      : pick one Maré at the start of a run (VS "arcanas"; needs the
##              Rosa-dos-Ventos relic)
##  mode      : run modifiers toggled before diving (mutant / hyper / inverse /
##              endless), each with a pearl bonus
##  pack      : content expansions: a new biome that grows the map, new
##              creatures that join the ocean and the character list, a new boss

const CATEGORIES := [
	["iap", "PÉROLAS"], ["pack", "EXPANSÕES"], ["relic", "RELÍQUIAS"], ["tide", "MARÉS"], ["mode", "MODOS"],
]

const ITEMS := {
	# ------------------------------------------------------------ expansions
	"pack_vents": {"cat": "pack", "name": "Fontes Hidrotermais", "icon": "pack_vents", "price": 3000,
		"desc": "Novo bioma no fim do mapa (+1200 m): chaminés ferventes, bactérias e dois novos bichos jogáveis: Caranguejo-Yeti e Verme-Tubo."},
	"pack_glow": {"cat": "pack", "name": "Criaturas Luminosas", "icon": "pack_glow", "price": 2250,
		"desc": "Peixe-Víbora e Lula-Vampira passam a caçar no abismo e entram na lista de personagens."},
	"pack_megalodon": {"cat": "pack", "name": "Megalodonte", "icon": "pack_megalodon", "price": 4500,
		"desc": "Um sexto chefe desperta depois do Titanacon. Vença-o para jogar com ele."},
	# ---------------------------------------------------------------- relics
	"relic_compass": {"cat": "relic", "name": "Rosa-dos-Ventos", "icon": "relic_compass", "price": 1250,
		"desc": "Libera as MARÉS: escolha uma bênção no início de cada partida."},
	"relic_crown": {"cat": "relic", "name": "Coroa de Coral", "icon": "relic_crown", "price": 3500,
		"desc": "Limite quebrado: armas comuns sobem até o nível 7."},
	"relic_anchor": {"cat": "relic", "name": "Âncora do Banimento", "icon": "relic_anchor", "price": 1500,
		"desc": "Botão BANIR nas cartas (3 por partida): some com a opção até o fim da partida."},
	"relic_eye": {"cat": "relic", "name": "Olho de Netuno", "icon": "relic_eye", "price": 1000,
		"desc": "Setas na borda da tela também apontam Alfas e peixes-dourados raros."},
	"relic_amber": {"cat": "relic", "name": "Âmbar Ancestral", "icon": "relic_amber", "price": 1750,
		"desc": "Começa toda partida com uma mutação aleatória."},
	"relic_bottle": {"cat": "relic", "name": "Garrafa de Mensagens", "icon": "relic_bottle", "price": 2000,
		"desc": "Um baú aparece perto de você no início de cada ciclo."},
	"relic_pearl": {"cat": "relic", "name": "Pérola Negra", "icon": "relic_pearl", "price": 1500,
		"desc": "Alfas aparecem com o dobro de frequência (mais escamas e pérolas)."},
	"relic_hourglass": {"cat": "relic", "name": "Ampulheta Abissal", "icon": "relic_hourglass", "price": 3000,
		"desc": "Com menos de 25% de vida o tempo desacelera por 3s e você fica invulnerável (1 vez por ciclo)."},
	"relic_music": {"cat": "relic", "name": "Caixa de Música", "icon": "relic_music", "price": 750,
		"desc": "Escolha qual trilha toca nas partidas (em Opções)."},
	# ----------------------------------------------------------------- tides
	"tide_red": {"cat": "tide", "name": "Maré Vermelha", "icon": "tide_red", "price": 1000, "needs": "relic_compass",
		"desc": "Acertos críticos explodem, ferindo quem estiver perto."},
	"tide_silver": {"cat": "tide", "name": "Maré de Prata", "icon": "tide_silver", "price": 1000, "needs": "relic_compass",
		"desc": "+25% de XP e o dobro do raio de coleta."},
	"tide_black": {"cat": "tide", "name": "Maré Negra", "icon": "tide_black", "price": 1250, "needs": "relic_compass",
		"desc": "Inimigos envenenados espalham veneno ao morrer."},
	"tide_storm": {"cat": "tide", "name": "Maré Elétrica", "icon": "tide_storm", "price": 1250, "needs": "relic_compass",
		"desc": "A cada 2,5s um raio cai no inimigo mais forte da tela."},
	"tide_life": {"cat": "tide", "name": "Maré Viva", "icon": "tide_life", "price": 1000, "needs": "relic_compass",
		"desc": "Cada abate cura 1 PV; a cura de comida dobra."},
	"tide_gold": {"cat": "tide", "name": "Maré Dourada", "icon": "tide_gold", "price": 1500, "needs": "relic_compass",
		"desc": "+100% pérolas, mas os inimigos têm +30% de vida."},
	# ----------------------------------------------------------------- modes
	"mode_mutant": {"cat": "mode", "name": "Modo Mutante", "icon": "mode_mutant", "price": 2500, "bonus": 0.5,
		"desc": "Inimigos surgem em variantes de cor com comportamentos novos: Fúria (vermelho), Tóxico (verde), Blindado (azul), Sombra (roxo) e Tesouro (dourado). +50% pérolas."},
	"mode_hyper": {"cat": "mode", "name": "Maré Alta", "icon": "mode_hyper", "price": 2000, "bonus": 0.4,
		"desc": "Tudo 30% mais rápido, hordas maiores e +30% XP. +40% pérolas."},
	"mode_inverse": {"cat": "mode", "name": "Abismo Invertido", "icon": "mode_inverse", "price": 3250, "bonus": 1.5,
		"desc": "O oceano escurece e os inimigos têm +100% de vida e ficam mais rápidos a cada minuto. +150% pérolas."},
}

const MUTANT_VARIANTS := {
	"fury": {"name": "Fúria", "color": Color(1.6, 0.55, 0.5), "speed": 1.45, "hp": 1.0, "dmg": 1.3},
	"toxic": {"name": "Tóxico", "color": Color(0.65, 1.5, 0.55), "speed": 1.0, "hp": 1.1, "dmg": 1.0},
	"armored": {"name": "Blindado", "color": Color(0.6, 0.85, 1.7), "speed": 0.85, "hp": 2.2, "dmg": 1.0},
	"shadow": {"name": "Sombra", "color": Color(0.7, 0.45, 1.3, 0.55), "speed": 1.15, "hp": 1.0, "dmg": 1.2},
	"treasure": {"name": "Tesouro", "color": Color(1.8, 1.5, 0.45), "speed": 1.3, "hp": 1.4, "dmg": 0.5},
}
