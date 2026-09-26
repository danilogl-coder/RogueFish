extends Node
## Static game data: species, creatures, bosses, weapons, passives, mutations,
## synergies, meta upgrades. Everything balance-related lives here.

const WORLD_W := 3200.0
const WORLD_H := 1000.0
const FLOOR_Y := 948.0
const SURFACE_Y := 14.0

const STAGE_NAMES := ["Alevino", "Juvenil", "Adulto", "Veterano", "Leviatã"]
const STAGE_LEVELS := [1, 6, 12, 19, 27]
const STAGE_RADIUS := [7.0, 9.0, 11.5, 14.5, 18.0]
const MAX_WEAPONS := 5
const MAX_PASSIVES := 5
const MAX_LEVEL := 5

const TAGS := {
	"volt": {"name": "Elétrico", "icon": "bolt", "color": Color("fff060")},
	"poison": {"name": "Veneno", "icon": "venom", "color": Color("cc7ee0")},
	"abyss": {"name": "Abissal", "icon": "eye", "color": Color("9474e2")},
	"coral": {"name": "Coral", "icon": "coral", "color": Color("f07c7c")},
	"predator": {"name": "Predador", "icon": "fang", "color": Color("ff9a5c")},
	"current": {"name": "Corrente", "icon": "wave", "color": Color("4ee0d8")},
}

# Bonus text per tag at 2 and 4 items. Effects are applied in player.gd.
const SYNERGIES := {
	"volt": ["Ataques elétricos saltam +1 alvo e +15% dano", "Choques atordoam inimigos"],
	"poison": ["+30% dano de veneno", "Envenenados explodem em nuvem tóxica"],
	"abyss": ["+8% chance crítica", "Críticos x2.5 e curam 1 PV ao matar"],
	"coral": ["+2 armadura", "Espinhos refletem 15 dano e +1 PV/s"],
	"predator": ["+25% dano da mordida", "Abates curam 2 PV e mordida 25% mais rápida"],
	"current": ["+10% velocidade e projéteis", "Corrente periódica empurra inimigos"],
}

const COMBOS := {
	"storm_toxin": {"name": "Tempestade Tóxica", "tags": ["volt", "poison"], "desc": "Choques aplicam veneno"},
	"abyss_hunter": {"name": "Caçador Abissal", "tags": ["predator", "abyss"], "desc": "Mordida +25% crítico"},
	"living_reef": {"name": "Recife Vivo", "tags": ["coral", "current"], "desc": "+1 PV/s e +10% área"},
}

const ATTRIBUTES := {
	"str": {"name": "FOR", "full": "Força", "icon": "fang", "desc": "+8% dano, +1 mordida"},
	"vit": {"name": "VIT", "full": "Vitalidade", "icon": "heart", "desc": "+12 PV máx, +0.15 PV/s"},
	"agi": {"name": "AGI", "full": "Agilidade", "icon": "wave", "desc": "+4% veloc., -3% recarga"},
	"ins": {"name": "INS", "full": "Instinto", "icon": "eye", "desc": "+3% crítico, +12% ímã"},
}
const ATTRIBUTE_MAX := 10

const SPECIES := {
	"dourado": {
		"name": "Peixe-Dourado", "desc": "Equilibrado e resiliente. Começa com Bolhas.",
		"weapon": "bubble", "price": 0,
		"stats": {"max_hp": 100.0, "speed": 118.0, "bite_damage": 12.0, "armor": 0.0},
	},
	"neon": {
		"name": "Tetra Neon", "desc": "Rápido e elétrico, porém frágil. Começa com Pulso.",
		"weapon": "pulse", "price": 350,
		"stats": {"max_hp": 80.0, "speed": 138.0, "bite_damage": 10.0, "armor": 0.0, "cooldown_mult": 0.92},
	},
	"garoupa": {
		"name": "Garoupa", "desc": "Tanque lento com mordida brutal. Começa com Espinhos.",
		"weapon": "spines", "price": 600,
		"stats": {"max_hp": 135.0, "speed": 102.0, "bite_damage": 18.0, "armor": 2.0},
	},
}

# faction: herb | pred | hazard | gold
const CREATURES := {
	"shrimp": {"name": "Camarão", "sheet": "shrimp", "tier": 0, "hp": 6, "speed": 55, "radius": 5, "dmg": 0,
		"xp": 1, "faction": "herb", "script": "shrimp", "depth": [0.55, 0.97], "pearl": 0.004},
	"sardine": {"name": "Sardinha", "sheet": "sardine", "tier": 0, "hp": 5, "speed": 80, "radius": 5, "dmg": 0,
		"xp": 1, "faction": "herb", "script": "sardine", "depth": [0.08, 0.6], "pearl": 0.004},
	"snail": {"name": "Caramujo", "sheet": "snail", "tier": 0, "hp": 22, "speed": 10, "radius": 6, "dmg": 0,
		"xp": 3, "faction": "herb", "script": "snail", "depth": [1.0, 1.0], "pearl": 0.02},
	"puffer": {"name": "Baiacu", "sheet": "puffer", "tier": 1, "hp": 28, "speed": 32, "radius": 7, "dmg": 10,
		"xp": 4, "faction": "herb", "script": "puffer", "depth": [0.3, 0.9], "pearl": 0.02},
	"turtle": {"name": "Tartaruga", "sheet": "turtle", "tier": 3, "hp": 220, "speed": 30, "radius": 14, "dmg": 10,
		"xp": 25, "faction": "herb", "script": "turtle", "depth": [0.2, 0.85], "pearl": 0.4},
	"piranha": {"name": "Piranha", "sheet": "piranha", "tier": 1, "hp": 16, "speed": 88, "radius": 7, "dmg": 5,
		"xp": 2, "faction": "pred", "script": "piranha", "depth": [0.2, 0.9], "pearl": 0.01},
	"barracuda": {"name": "Barracuda", "sheet": "barracuda", "tier": 2, "hp": 55, "speed": 70, "radius": 8, "dmg": 13,
		"xp": 7, "faction": "pred", "script": "barracuda", "depth": [0.1, 0.8], "pearl": 0.04},
	"jellyfish": {"name": "Água-viva", "sheet": "jellyfish", "tier": 2, "hp": 26, "speed": 22, "radius": 8, "dmg": 6,
		"xp": 4, "faction": "hazard", "script": "jellyfish", "depth": [0.1, 0.75], "pearl": 0.02, "light": 40.0},
	"moray": {"name": "Moreia", "sheet": "moray", "tier": 3, "hp": 90, "speed": 60, "radius": 9, "dmg": 14,
		"xp": 12, "faction": "pred", "script": "moray", "depth": [1.0, 1.0], "pearl": 0.1},
	"shark": {"name": "Tubarão", "sheet": "shark", "tier": 4, "hp": 260, "speed": 78, "radius": 15, "dmg": 22,
		"xp": 30, "faction": "pred", "script": "shark", "depth": [0.1, 0.7], "pearl": 0.3},
	"angler": {"name": "Peixe-Pescador", "sheet": "angler", "tier": 3, "hp": 70, "speed": 26, "radius": 11, "dmg": 16,
		"xp": 10, "faction": "pred", "script": "angler", "depth": [0.72, 0.95], "pearl": 0.08, "light": 55.0},
	"crab": {"name": "Caranguejo", "sheet": "crab", "tier": 1, "hp": 30, "speed": 36, "radius": 8, "dmg": 6,
		"xp": 3, "faction": "pred", "script": "crab", "depth": [1.0, 1.0], "pearl": 0.02},
	"squid": {"name": "Lula", "sheet": "squid", "tier": 2, "hp": 40, "speed": 64, "radius": 8, "dmg": 8,
		"xp": 6, "faction": "pred", "script": "squid", "depth": [0.15, 0.85], "pearl": 0.04},
	"golden": {"name": "Peixe-Dourado Raro", "sheet": "golden", "tier": 0, "hp": 12, "speed": 110, "radius": 6, "dmg": 0,
		"xp": 12, "faction": "gold", "script": "sardine", "depth": [0.1, 0.8], "pearl": 1.0},
}

const BOSSES := {
	"shark_king": {"name": "Mandíbula, o Tubarão-Rei", "hp": 1600, "script": "boss_shark", "dmg": 22, "xp": 250, "pearls": 25},
	"kraken": {"name": "Kraken das Marés", "hp": 2600, "script": "boss_kraken", "dmg": 24, "xp": 400, "pearls": 40},
	"angler_queen": {"name": "Rainha Abissal", "hp": 3600, "script": "boss_angler", "dmg": 32, "xp": 600, "pearls": 60},
	"leviathan": {"name": "Leviatã Elétrico", "hp": 5200, "script": "boss_leviathan", "dmg": 36, "xp": 900, "pearls": 100},
}
const BOSS_ORDER := ["shark_king", "kraken", "angler_queen", "leviathan"]

# Ecosystem populations per cycle (index 0 = cycle 1). Values = target counts.
const POPULATION := [
	{"shrimp": 14, "sardine": 16, "snail": 4, "puffer": 3, "piranha": 5, "crab": 3, "jellyfish": 4, "turtle": 1, "angler": 1},
	{"shrimp": 14, "sardine": 16, "snail": 4, "puffer": 4, "piranha": 8, "crab": 4, "jellyfish": 5, "turtle": 2, "angler": 2, "squid": 2, "barracuda": 2},
	{"shrimp": 12, "sardine": 18, "snail": 4, "puffer": 4, "piranha": 8, "crab": 4, "jellyfish": 6, "turtle": 2, "angler": 3, "squid": 3, "barracuda": 3, "shark": 1},
	{"shrimp": 12, "sardine": 18, "snail": 4, "puffer": 5, "piranha": 10, "crab": 5, "jellyfish": 7, "turtle": 2, "angler": 3, "squid": 4, "barracuda": 4, "shark": 2},
]

# Waves: weighted spawn table per cycle
const WAVES := [
	{"piranha": 6, "crab": 2, "jellyfish": 1},
	{"piranha": 5, "squid": 2, "barracuda": 2, "jellyfish": 1},
	{"piranha": 4, "barracuda": 3, "squid": 2, "angler": 1, "shark": 0.4},
	{"piranha": 4, "barracuda": 3, "squid": 3, "angler": 1, "shark": 0.8, "puffer": 1},
]

const EXPLORE_TIME := [75.0, 70.0, 70.0, 65.0]
const WAVE_TIME := 50.0

# ------------------------------------------------------------------ weapons
# Per-level tables: index 0 = level 1.
const WEAPONS := {
	"bubble": {
		"name": "Bolhas", "icon": "w_bubble", "tag": "current", "evo": "torpedo", "pair": "gills",
		"desc": ["Dispara bolhas no inimigo mais próximo.", "+1 bolha", "+40% dano", "Atravessa +1 inimigo", "+1 bolha, +30% dano"],
		"damage": [9, 9, 12.6, 12.6, 16.4], "cooldown": [1.1, 1.1, 1.0, 1.0, 0.9], "amount": [1, 2, 2, 2, 3], "pierce": [1, 1, 1, 2, 2],
	},
	"ink": {
		"name": "Tinta Tóxica", "icon": "w_ink", "tag": "poison", "evo": "black_tide", "pair": "venom",
		"desc": ["Lança nuvens de tinta que envenenam e lentificam.", "+30% área", "+1 nuvem", "+1s duração, +30% dano", "+1 nuvem, +20% área"],
		"damage": [5, 5, 5, 6.5, 6.5], "cooldown": [3.4, 3.2, 3.0, 3.0, 2.8], "amount": [1, 1, 2, 2, 3], "area": [1.0, 1.3, 1.3, 1.3, 1.56], "duration": [3.0, 3.0, 3.0, 4.0, 4.0],
	},
	"pulse": {
		"name": "Pulso Elétrico", "icon": "w_pulse", "tag": "volt", "evo": "storm", "pair": "battery",
		"desc": ["Descarga elétrica que salta entre inimigos.", "+1 salto", "+30% dano", "-15% recarga", "+2 saltos, +30% dano"],
		"damage": [12, 12, 15.6, 15.6, 20], "cooldown": [2.2, 2.2, 2.1, 1.8, 1.7], "amount": [2, 3, 3, 3, 5], "range": [110, 110, 120, 120, 130],
	},
	"spines": {
		"name": "Espinhos", "icon": "w_spines", "tag": "coral", "evo": "coral_crown", "pair": "shell",
		"desc": ["Dispara um anel de espinhos em todas as direções.", "+2 espinhos", "+30% dano", "+1 perfuração", "+3 espinhos, -15% recarga"],
		"damage": [7, 7, 9.1, 9.1, 9.1], "cooldown": [1.9, 1.9, 1.8, 1.8, 1.55], "amount": [6, 8, 8, 8, 11], "pierce": [1, 1, 1, 2, 2],
	},
	"pilot": {
		"name": "Peixes-Piloto", "icon": "w_pilot", "tag": "predator", "evo": "frenzy", "pair": "teeth",
		"desc": ["Peixes-piloto orbitam e mordem inimigos.", "+1 peixe", "+30% dano", "+1 peixe, +20% raio", "+1 peixe, +30% velocidade"],
		"damage": [7, 7, 9.1, 9.1, 10], "cooldown": [0.0, 0, 0, 0, 0], "amount": [2, 3, 3, 4, 5], "area": [1.0, 1.0, 1.0, 1.2, 1.2], "speed": [2.6, 2.6, 2.6, 2.6, 3.4],
	},
	"sonar": {
		"name": "Sonar", "icon": "w_sonar", "tag": "abyss", "evo": "abyss_call", "pair": "eyes",
		"desc": ["Onda sonora que atinge e empurra tudo ao redor.", "+20% área", "+40% dano", "-15% recarga", "+20% área, +30% dano"],
		"damage": [11, 11, 15.4, 15.4, 20], "cooldown": [2.9, 2.9, 2.8, 2.4, 2.4], "area": [1.0, 1.2, 1.2, 1.2, 1.44],
	},
	"whirl": {
		"name": "Redemoinho", "icon": "w_whirl", "tag": "current", "evo": "maelstrom", "pair": "magnet",
		"desc": ["Cria redemoinhos que puxam e trituram inimigos.", "+25% área", "+1s duração", "+1 redemoinho", "+50% dano, -15% recarga"],
		"damage": [5, 5, 5, 5, 7.5], "cooldown": [5.0, 5.0, 5.0, 5.0, 4.25], "amount": [1, 1, 1, 2, 2], "area": [1.0, 1.25, 1.25, 1.25, 1.25], "duration": [3.0, 3.0, 4.0, 4.0, 4.0],
	},
}

const EVOLUTIONS := {
	"torpedo": {"name": "Torpedo de Bolhas", "icon": "torpedo", "from": "bubble", "desc": "Torpedos teleguiados que explodem em área."},
	"black_tide": {"name": "Maré Negra", "icon": "w_ink", "from": "ink", "desc": "Rastro de tinta venenosa segue você por onde nada."},
	"storm": {"name": "Tempestade Voltaica", "icon": "bolt", "from": "pulse", "desc": "Raios caem sem parar sobre os inimigos da tela."},
	"coral_crown": {"name": "Coroa de Coral", "icon": "coral", "from": "spines", "desc": "Espirais de corais perfurantes em rajadas duplas."},
	"frenzy": {"name": "Cardume Voraz", "icon": "w_pilot", "from": "pilot", "desc": "8 piranhas caçam inimigos sozinhas e voltam."},
	"abyss_call": {"name": "Chamado Abissal", "icon": "eye", "from": "sonar", "desc": "Onda gigante que marca inimigos (+25% dano) e puxa XP."},
	"maelstrom": {"name": "Maelstrom", "icon": "w_whirl", "from": "whirl", "desc": "Um redemoinho colossal te acompanha, sugando tudo."},
}

const PASSIVES := {
	"gills": {"name": "Guelras Potentes", "icon": "p_gills", "tag": "current", "desc": "+10% área de ataques"},
	"heart": {"name": "Coração de Baleia", "icon": "p_heart", "tag": "coral", "desc": "+20 PV máx e +0.2 PV/s"},
	"fins": {"name": "Barbatanas Ágeis", "icon": "p_fins", "tag": "current", "desc": "+7% velocidade"},
	"teeth": {"name": "Dentes Afiados", "icon": "p_teeth", "tag": "predator", "desc": "+10% dano"},
	"venom": {"name": "Glândula de Veneno", "icon": "p_venom", "tag": "poison", "desc": "+20% dano e duração de veneno"},
	"battery": {"name": "Bateria Orgânica", "icon": "p_battery", "tag": "volt", "desc": "-7% tempo de recarga"},
	"eyes": {"name": "Olhos Abissais", "icon": "p_eyes", "tag": "abyss", "desc": "+5% crítico e +15% dano crítico"},
	"shell": {"name": "Carapaça", "icon": "p_shell", "tag": "coral", "desc": "+1 armadura"},
	"magnet": {"name": "Ímã de Plâncton", "icon": "p_magnet", "tag": "", "desc": "+30% raio de coleta"},
	"luck": {"name": "Estrela-do-Mar", "icon": "p_luck", "tag": "", "desc": "+15% sorte (cartas raras, pérolas)"},
	"brain": {"name": "Instinto Ancestral", "icon": "p_brain", "tag": "", "desc": "+8% experiência"},
}

# Mutations: slot -> id. Each changes the fish sprite.
const MUTATION_SLOTS := ["head", "fins", "skin", "tail"]
const MUTATIONS := {
	"head_piranha": {"slot": "head", "name": "Mandíbula de Piranha", "tag": "predator", "desc": "Mordida +40% dano e causa sangramento."},
	"head_sword": {"slot": "head", "name": "Rostro de Espadarte", "tag": "current", "desc": "Alcance da mordida +60% e investida mais longa."},
	"head_lure": {"slot": "head", "name": "Lanterna Abissal", "tag": "abyss", "desc": "Ilumina o abismo, +50% ímã e +8% crítico."},
	"fins_spiky": {"slot": "fins", "name": "Nadadeiras Espinhosas", "tag": "coral", "desc": "Reflete 10 dano ao ser tocado e +1 armadura."},
	"fins_wing": {"slot": "fins", "name": "Asas de Peixe-Voador", "tag": "current", "desc": "+22% velocidade e mordida 15% mais rápida."},
	"fins_volt": {"slot": "fins", "name": "Nadadeiras Elétricas", "tag": "volt", "desc": "Solta faíscas no inimigo próximo a cada 1.2s."},
	"skin_armor": {"slot": "skin", "name": "Escamas Blindadas", "tag": "coral", "desc": "+3 armadura e +25 PV máx."},
	"skin_toxic": {"slot": "skin", "name": "Pele Tóxica", "tag": "poison", "desc": "Aura venenosa fere quem chega perto."},
	"skin_glow": {"slot": "skin", "name": "Bioluminescência", "tag": "abyss", "desc": "+10% crítico, +0.6 PV/s e brilho próprio."},
	"tail_fork": {"slot": "tail", "name": "Cauda Forquilha", "tag": "predator", "desc": "+12% velocidade e investida dupla."},
	"tail_sting": {"slot": "tail", "name": "Ferrão de Arraia", "tag": "poison", "desc": "Ferroa inimigos atrás de você com veneno."},
	"tail_eel": {"slot": "tail", "name": "Cauda de Enguia", "tag": "volt", "desc": "Mordidas liberam choque em cadeia."},
}

# Rogue-lite meta upgrades (bought with pearls between runs)
const META := {
	"vitality": {"name": "Vitalidade Ancestral", "icon": "heart", "desc": "+10 PV máx", "max": 5, "cost": [40, 80, 140, 220, 320]},
	"might": {"name": "Mandíbula Forte", "icon": "fang", "desc": "+6% dano", "max": 5, "cost": [50, 100, 160, 240, 340]},
	"swift": {"name": "Nado Veloz", "icon": "wave", "desc": "+4% velocidade", "max": 5, "cost": [40, 80, 130, 200, 290]},
	"scales": {"name": "Escamas Grossas", "icon": "p_shell", "desc": "+1 armadura", "max": 3, "cost": [120, 260, 450]},
	"magnet": {"name": "Faro de Plâncton", "icon": "p_magnet", "desc": "+15% coleta", "max": 3, "cost": [60, 120, 200]},
	"wisdom": {"name": "Sabedoria", "icon": "p_brain", "desc": "+6% experiência", "max": 5, "cost": [60, 110, 170, 250, 350]},
	"luck": {"name": "Sorte do Mar", "icon": "p_luck", "desc": "+10% sorte", "max": 3, "cost": [80, 160, 280]},
	"reroll": {"name": "Maré da Sorte", "icon": "reroll", "desc": "+1 rerrolagem por partida", "max": 3, "cost": [100, 200, 350]},
	"regen": {"name": "Regeneração", "icon": "plus", "desc": "+0.2 PV/s", "max": 3, "cost": [90, 180, 300]},
	"greed": {"name": "Olho de Ouro", "icon": "star", "desc": "+15% pérolas", "max": 4, "cost": [100, 180, 280, 400]},
	"revive": {"name": "Segunda Chance", "icon": "dna", "desc": "Revive uma vez por partida", "max": 1, "cost": [500]},
	"choice": {"name": "Visão Ampla", "icon": "eye", "desc": "4 cartas por nível", "max": 1, "cost": [650]},
}

const RARITY_FRAME := {"common": "card_common", "rare": "card_rare", "epic": "card_epic", "legend": "card_legend", "mutation": "card_mutation"}


func xp_to_next(level: int) -> int:
	var l := float(level - 1)
	return int(round(7.0 + l * 5.0 + pow(l, 1.45) * 0.9))


func stage_for_level(level: int) -> int:
	var s := 0
	for i in STAGE_LEVELS.size():
		if level >= STAGE_LEVELS[i]:
			s = i
	return s


func weapon_value(id: String, key: String, level: int, fallback = 0.0):
	var w: Dictionary = WEAPONS.get(id, {})
	if not w.has(key):
		return fallback
	var arr: Array = w[key]
	return arr[clampi(level - 1, 0, arr.size() - 1)]


func item_tag(id: String) -> String:
	if WEAPONS.has(id):
		return WEAPONS[id].tag
	if EVOLUTIONS.has(id):
		return WEAPONS[EVOLUTIONS[id].from].tag
	if PASSIVES.has(id):
		return PASSIVES[id].tag
	if MUTATIONS.has(id):
		return MUTATIONS[id].tag
	return ""


func format_time(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]
