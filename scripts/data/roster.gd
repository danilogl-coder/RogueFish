class_name Roster
extends RefCounted
## Every playable character.
##
##  weapon  : its unique item. You start with it, and unlocking the character
##            adds the item to the level-up pool of every run.
##  trait   : a special effect only this character has (see scripts/game/traits.gd).
##  unlock  : "free" | "price" (pearls) | "boss" (defeat it) | "stat" (lifetime
##            goal) | "pack" (comes with a purchased expansion, then price).
##  group   : section of the character screen.

const SPECIES := {
	# ------------------------------------------------------------ starters
	"dourado": {
		"name": "Peixe-Dourado", "group": "peixes", "short": "Equilibrado e sortudo.",
		"weapon": "bubble", "unlock": {"type": "free"},
		"trait": {"name": "Brilho Dourado", "desc": "+10% XP e +1 rerrolagem por partida."},
		"stats": {"max_hp": 100.0, "speed": 118.0, "bite_damage": 12.0, "armor": 0.0},
	},
	"sardinha": {
		"name": "Sardinha", "group": "peixes", "short": "Pequena, veloz e esquiva.",
		"weapon": "silver_school", "unlock": {"type": "price", "price": 150},
		"trait": {"name": "Cardume", "desc": "15% de chance de desviar de golpes e +8% velocidade."},
		"stats": {"max_hp": 78.0, "speed": 136.0, "bite_damage": 9.0, "armor": 0.0},
	},
	"camarao": {
		"name": "Camarão-Pistola", "group": "invertebrados", "short": "Estalo que atordoa.",
		"weapon": "cavitation", "unlock": {"type": "price", "price": 120},
		"trait": {"name": "Limpador", "desc": "Imune a parasitas e regenera +0.5 PV/s."},
		"stats": {"max_hp": 82.0, "speed": 126.0, "bite_damage": 10.0, "armor": 0.0},
	},
	"caramujo": {
		"name": "Caramujo", "group": "invertebrados", "short": "Lento, mas quase imortal parado.",
		"weapon": "mucus", "unlock": {"type": "price", "price": 100},
		"trait": {"name": "Concha", "desc": "Parado por 1s: +5 armadura e +2 PV/s."},
		"stats": {"max_hp": 120.0, "speed": 92.0, "bite_damage": 10.0, "armor": 2.0},
	},
	"pepino": {
		"name": "Pepino-do-mar", "group": "invertebrados", "short": "Cospe as tripas pra sobreviver.",
		"weapon": "sticky_guts", "unlock": {"type": "price", "price": 200},
		"trait": {"name": "Evisceração", "desc": "Abaixo de 30% de vida, cura 35% (uma vez a cada 60s)."},
		"stats": {"max_hp": 115.0, "speed": 96.0, "bite_damage": 9.0, "armor": 1.0},
	},
	"baiacu": {
		"name": "Baiacu", "group": "peixes", "short": "Infla e envenena.",
		"weapon": "tetrodo", "unlock": {"type": "price", "price": 300},
		"trait": {"name": "Inflar", "desc": "Ao ser atingido, infla: -50% de dano e espinhos por 2s (recarga 8s)."},
		"stats": {"max_hp": 110.0, "speed": 108.0, "bite_damage": 11.0, "armor": 1.0},
	},
	"neon": {
		"name": "Tetra Neon", "group": "peixes", "short": "Rápido e elétrico.",
		"weapon": "pulse", "unlock": {"type": "price", "price": 350},
		"trait": {"name": "Faísca", "desc": "A cada 6 acertos, uma faísca salta para 2 inimigos."},
		"stats": {"max_hp": 80.0, "speed": 138.0, "bite_damage": 10.0, "armor": 0.0, "cooldown_mult": 0.92},
	},
	"ourico": {
		"name": "Ouriço-do-mar", "group": "invertebrados", "short": "Uma bola de espinhos.",
		"weapon": "urchin_burst", "unlock": {"type": "price", "price": 350},
		"trait": {"name": "Espinhoso", "desc": "Reflete 12 de dano a quem te toca."},
		"stats": {"max_hp": 105.0, "speed": 100.0, "bite_damage": 10.0, "armor": 2.0},
	},
	"lanterna": {
		"name": "Peixe-Lanterna", "group": "peixes", "short": "Brilha no escuro.",
		"weapon": "photophore", "unlock": {"type": "price", "price": 400},
		"trait": {"name": "Bioluz", "desc": "Ilumina o abismo e +20% de XP."},
		"stats": {"max_hp": 90.0, "speed": 124.0, "bite_damage": 10.0, "armor": 0.0, "light": 110.0},
	},
	"agua_viva": {
		"name": "Água-viva", "group": "invertebrados", "short": "Queima quem encosta.",
		"weapon": "tentacles", "unlock": {"type": "price", "price": 450},
		"trait": {"name": "Corpo Urticante", "desc": "Quem te toca queima e fica lento."},
		"stats": {"max_hp": 95.0, "speed": 104.0, "bite_damage": 9.0, "armor": 0.0},
	},
	"caranguejo": {
		"name": "Caranguejo", "group": "invertebrados", "short": "Blindado de pinça pesada.",
		"weapon": "claw", "unlock": {"type": "price", "price": 500},
		"trait": {"name": "Carapaça", "desc": "+3 armadura e 20% de chance de aparar golpes."},
		"stats": {"max_hp": 125.0, "speed": 100.0, "bite_damage": 15.0, "armor": 3.0},
	},
	"lula": {
		"name": "Lula", "group": "invertebrados", "short": "Jato e tinta.",
		"weapon": "sucker", "unlock": {"type": "price", "price": 550},
		"trait": {"name": "Jato", "desc": "+1 investida e cada investida solta uma nuvem de tinta."},
		"stats": {"max_hp": 95.0, "speed": 128.0, "bite_damage": 12.0, "armor": 0.0},
	},
	"garoupa": {
		"name": "Garoupa", "group": "peixes", "short": "Tanque de mordida brutal.",
		"weapon": "spines", "unlock": {"type": "price", "price": 600},
		"trait": {"name": "Couro Grosso", "desc": "Bloqueia 1 golpe a cada 10s."},
		"stats": {"max_hp": 135.0, "speed": 102.0, "bite_damage": 18.0, "armor": 2.0},
	},
	"barracuda": {
		"name": "Barracuda", "group": "peixes", "short": "Flecha do recife.",
		"weapon": "silver_arrow", "unlock": {"type": "price", "price": 750},
		"trait": {"name": "Emboscada", "desc": "O primeiro golpe em cada inimigo é sempre crítico."},
		"stats": {"max_hp": 100.0, "speed": 134.0, "bite_damage": 16.0, "armor": 0.0, "crit_chance": 0.06},
	},
	"tartaruga": {
		"name": "Tartaruga", "group": "especiais", "short": "Casco quase inquebrável.",
		"weapon": "shell_bounce", "unlock": {"type": "price", "price": 900},
		"trait": {"name": "Casco", "desc": "Recebe 25% menos dano de tudo."},
		"stats": {"max_hp": 150.0, "speed": 96.0, "bite_damage": 14.0, "armor": 2.0},
	},
	# ------------------------------------------------------ earned by playing
	"piranha": {
		"name": "Piranha", "group": "peixes", "short": "Mordida voraz.",
		"weapon": "serrated", "unlock": {"type": "stat", "stat": "kill_piranha", "target": 250, "desc": "Derrote 250 piranhas"},
		"trait": {"name": "Voraz", "desc": "Mordida 25% mais rápida e que faz sangrar."},
		"stats": {"max_hp": 95.0, "speed": 128.0, "bite_damage": 15.0, "armor": 0.0},
	},
	"moreia": {
		"name": "Moreia", "group": "peixes", "short": "Emboscada da toca.",
		"weapon": "moray_strike", "unlock": {"type": "stat", "stat": "kill_moray", "target": 20, "desc": "Derrote 20 moreias"},
		"trait": {"name": "Toca", "desc": "Escondido regenera 3x; o próximo bote após se esconder dá +100% dano."},
		"stats": {"max_hp": 115.0, "speed": 116.0, "bite_damage": 17.0, "armor": 1.0, "bite_reach": 1.2},
	},
	"isopode": {
		"name": "Isópode Gigante", "group": "invertebrados", "short": "Necrófago blindado.",
		"weapon": "scavengers", "unlock": {"type": "stat", "stat": "carcass", "target": 60, "desc": "Coma 60 pedaços de carcaça"},
		"trait": {"name": "Necrófago", "desc": "Carcaças curam 2x e dão +50% de XP; +1 armadura."},
		"stats": {"max_hp": 120.0, "speed": 104.0, "bite_damage": 12.0, "armor": 2.0},
	},
	"lontra": {
		"name": "Lontra-marinha", "group": "especiais", "short": "Quebra cascas com pedras.",
		"weapon": "otter_stone", "unlock": {"type": "stat", "stat": "kill_urchin", "target": 40, "desc": "Salve o kelp: derrote 40 ouriços"},
		"trait": {"name": "Ferramenta", "desc": "A cada 5 mordidas, a próxima quebra cascas: +100% dano e atordoa."},
		"stats": {"max_hp": 110.0, "speed": 122.0, "bite_damage": 14.0, "armor": 0.0},
	},
	"minhoca": {
		"name": "Minhoca-do-mar", "group": "invertebrados", "short": "Bote da areia.",
		"weapon": "scissor_jaws", "unlock": {"type": "stat", "stat": "kill_bobbit", "target": 15, "desc": "Derrote 15 minhocas-do-mar"},
		"trait": {"name": "Bote", "desc": "Parado por 1,5s, a próxima mordida dá 3x dano."},
		"stats": {"max_hp": 105.0, "speed": 110.0, "bite_damage": 16.0, "armor": 1.0, "bite_reach": 1.3},
	},
	"piolho": {
		"name": "Piolho-do-mar", "group": "invertebrados", "short": "Uma colônia ambulante.",
		"weapon": "louse_swarm", "unlock": {"type": "stat", "stat": "swarms", "target": 1, "desc": "Solte um ENXAME de parasitas"},
		"trait": {"name": "Colônia", "desc": "Começa com uma colônia que já cruza; ela nunca te deixa lento."},
		"stats": {"max_hp": 88.0, "speed": 124.0, "bite_damage": 10.0, "armor": 0.0},
	},
	"dourado_raro": {
		"name": "Dourado Raro", "group": "especiais", "short": "Vale ouro.",
		"weapon": "gold_rain", "unlock": {"type": "stat", "stat": "kill_golden", "target": 5, "desc": "Pegue 5 peixes-dourados raros"},
		"trait": {"name": "Tesouro", "desc": "+40% pérolas e +20% sorte."},
		"stats": {"max_hp": 90.0, "speed": 140.0, "bite_damage": 11.0, "armor": 0.0},
	},
	"orca": {
		"name": "Orca", "group": "especiais", "short": "Megapredador.",
		"weapon": "orca_breach", "unlock": {"type": "stat", "stat": "orcas", "target": 3, "desc": "Derrote 3 orcas"},
		"trait": {"name": "Megapredador", "desc": "+25% de dano contra inimigos grandes; predadores fogem."},
		"stats": {"max_hp": 160.0, "speed": 124.0, "bite_damage": 22.0, "armor": 2.0},
	},
	# ------------------------------------------------------- defeated bosses
	"tubarao": {
		"name": "Tubarão-Rei", "group": "chefes", "short": "Veloz, de mordida larga.",
		"weapon": "pilot", "unlock": {"type": "boss", "boss": "shark_king"},
		"trait": {"name": "Sangue na Água", "desc": "Cada abate: +3% dano por 4s (até +30%)."},
		"stats": {"max_hp": 125.0, "speed": 130.0, "bite_damage": 20.0, "armor": 1.0, "bite_reach": 1.15},
	},
	"kraken": {
		"name": "Kraken Jovem", "group": "chefes", "short": "Braços longos e tinta.",
		"weapon": "ink", "unlock": {"type": "boss", "boss": "kraken"},
		"trait": {"name": "Oito Braços", "desc": "A mordida atinge até 3 inimigos a mais ao redor."},
		"stats": {"max_hp": 120.0, "speed": 114.0, "bite_damage": 15.0, "armor": 1.0, "cooldown_mult": 0.9, "bite_reach": 1.25},
	},
	"pescadora": {
		"name": "Rainha Abissal", "group": "chefes", "short": "Isca que ilumina o abismo.",
		"weapon": "sonar", "unlock": {"type": "boss", "boss": "angler_queen"},
		"trait": {"name": "Isca Viva", "desc": "Críticos puxam XP próxima e curam 1 PV."},
		"stats": {"max_hp": 115.0, "speed": 110.0, "bite_damage": 17.0, "armor": 1.0, "light": 140.0, "crit_chance": 0.12, "magnet": 60.0},
	},
	"leviata": {
		"name": "Leviatã", "group": "chefes", "short": "Serpente elétrica e dura.",
		"weapon": "volt_lance", "unlock": {"type": "boss", "boss": "leviathan"},
		"trait": {"name": "Couro Elétrico", "desc": "Inimigos que te tocam levam 15 de choque."},
		"stats": {"max_hp": 145.0, "speed": 126.0, "bite_damage": 16.0, "armor": 2.0},
	},
	"titanacon": {
		"name": "Titanacon", "group": "chefes", "short": "Titã blindado e lento.",
		"weapon": "whirl", "unlock": {"type": "boss", "boss": "titanacon"},
		"trait": {"name": "Devorar", "desc": "A mordida devora inimigos (não-chefes) abaixo de 20% da vida."},
		"stats": {"max_hp": 175.0, "speed": 98.0, "bite_damage": 23.0, "armor": 3.0, "bite_reach": 1.35},
	},
}

const GROUPS := [
	["peixes", "PEIXES"], ["invertebrados", "INVERTEBRADOS"], ["especiais", "ESPECIAIS"], ["chefes", "CHEFES"],
]
