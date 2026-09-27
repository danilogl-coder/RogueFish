class_name Arsenal
extends RefCounted
## Items added by the "Marés Profundas" expansion.
##
## Every weapon here is data-driven: "kind" picks one of the archetypes
## implemented in Weapon (shot, nova, orbit, aura, lash, beam, mine, boomerang,
## bounce, strike, slam, summon, trail, lob, tentacle) and the per-level arrays
## tune it. "owner" is the character that brings the item into the game: the
## item only shows up on level-up cards once that character is unlocked
## (Vampire-Survivors style). Items without owner are always available.
##
## FUSIONS: two specific weapons at max level fuse into one weapon that keeps
## levelling up to 10 (and frees a weapon slot).

const BASE_ITEMS := ["bubble", "tail_whip", "coral_shard", "bubble_ring"]

const WEAPONS := {
	# ------------------------------------------------ always available (no owner)
	"tail_whip": {
		"name": "Chicote de Cauda", "icon": "w_tail_whip", "tag": "predator", "kind": "lash",
		"desc": ["Chicoteia à frente com a cauda.", "+15% área", "+30% dano", "Chicoteia também atrás", "+25% dano, -15% recarga"],
		"damage": [14, 14, 18, 18, 22], "cooldown": [1.3, 1.25, 1.2, 1.2, 1.0], "area": [1.0, 1.15, 1.15, 1.15, 1.25],
		"amount": [1, 1, 1, 2, 2], "sheet": "fx/lash_arc", "reach": 34.0, "arc": 1.6, "knock": 160.0, "sfx": "dash",
	},
	"coral_shard": {
		"name": "Estilhaço de Coral", "icon": "w_coral_shard", "tag": "coral", "kind": "shot",
		"desc": ["Lança estilhaços afiados em inimigos aleatórios.", "+1 estilhaço", "Perfura +1", "+30% dano, -10% recarga", "+2 estilhaços"],
		"damage": [8, 8, 8, 10.4, 10.4], "cooldown": [1.0, 1.0, 1.0, 0.9, 0.9], "amount": [2, 3, 3, 3, 5], "pierce": [2, 2, 3, 3, 3],
		"sheet": "fx/coral_shard", "speed": 230.0, "life": 1.2, "size": 4.0, "target": "random", "sfx": "bubble",
	},
	"bubble_ring": {
		"name": "Anel de Bolhas", "icon": "w_bubble_ring", "tag": "current", "kind": "orbit",
		"desc": ["Bolhas giram ao seu redor e empurram inimigos.", "+1 bolha", "+30% dano", "+1 bolha, +15% raio", "+2 bolhas, +30% velocidade"],
		"damage": [5, 5, 6.5, 6.5, 8], "amount": [3, 4, 4, 5, 7], "area": [1.0, 1.0, 1.0, 1.15, 1.15], "speed": [2.2, 2.2, 2.2, 2.2, 2.9],
		"sheet": "fx/bubble", "radius": 30.0, "knock": 120.0, "hit_cd": 0.5,
	},
	# ------------------------------------------------ character items
	"volt_lance": {
		"name": "Lança Voltaica", "icon": "w_volt_lance", "tag": "volt", "kind": "beam", "owner": "leviata",
		"desc": ["Dispara um raio em linha reta que atravessa tudo.", "+20% alcance", "+30% dano", "+1 raio", "+30% dano, atordoa"],
		"damage": [16, 16, 20.8, 20.8, 27], "cooldown": [2.2, 2.1, 2.0, 1.9, 1.7], "area": [1.0, 1.2, 1.2, 1.2, 1.3], "amount": [1, 1, 1, 2, 2],
		"length": 150.0, "width": 7.0, "stun": [0.0, 0, 0, 0, 0.35], "color": "7ae0ff", "sfx": "zap",
	},
	"silver_school": {
		"name": "Cardume de Prata", "icon": "w_silver_school", "tag": "current", "kind": "orbit", "owner": "sardinha",
		"desc": ["Um cardume de sardinhas gira ao seu redor.", "+1 sardinha", "+30% dano", "+2 sardinhas", "+2 sardinhas, +25% raio"],
		"damage": [4, 4, 5.2, 5.2, 6], "amount": [4, 5, 5, 7, 9], "area": [1.0, 1.0, 1.0, 1.0, 1.25], "speed": [3.4, 3.4, 3.4, 3.6, 3.8],
		"sheet": "creatures/sardine", "radius": 34.0, "knock": 60.0, "hit_cd": 0.35, "animated": true,
	},
	"photophore": {
		"name": "Fotóforos", "icon": "w_photophore", "tag": "abyss", "kind": "orbit", "owner": "lanterna",
		"desc": ["Orbes de luz queimam e ofuscam (lentidão).", "+1 orbe", "+30% dano", "+20% raio", "+1 orbe, +30% dano"],
		"damage": [6, 6, 7.8, 7.8, 10], "amount": [2, 3, 3, 3, 4], "area": [1.0, 1.0, 1.0, 1.2, 1.2], "speed": [1.3, 1.3, 1.3, 1.4, 1.5],
		"sheet": "fx/light_orb", "radius": 52.0, "slow": 0.35, "hit_cd": 0.45, "glow": true,
	},
	"tetrodo": {
		"name": "Névoa de Tetrodotoxina", "icon": "w_tetrodo", "tag": "poison", "kind": "aura", "owner": "baiacu",
		"desc": ["Uma névoa venenosa envolve você.", "+20% área", "+30% dano", "Lentifica 20%", "+25% área, +30% dano"],
		"damage": [4, 4, 5.2, 5.2, 6.8], "area": [1.0, 1.2, 1.2, 1.2, 1.5], "slow": [0.0, 0, 0, 0.2, 0.2],
		"radius": 40.0, "tick": 0.5, "poison": 2.0, "color": "a4dc4c",
	},
	"silver_arrow": {
		"name": "Flecha de Prata", "icon": "w_silver_arrow", "tag": "predator", "kind": "shot", "owner": "barracuda",
		"desc": ["Dispara uma flecha veloz que perfura em linha.", "Perfura +1", "+30% dano", "+1 flecha", "+30% dano, perfura +2"],
		"damage": [16, 16, 20.8, 20.8, 27], "cooldown": [1.6, 1.5, 1.4, 1.35, 1.2], "amount": [1, 1, 1, 2, 2], "pierce": [3, 4, 4, 4, 6],
		"sheet": "fx/silver_arrow", "speed": 440.0, "life": 0.9, "size": 4.0, "target": "nearest", "sfx": "dash",
	},
	"serrated": {
		"name": "Dentes Serrilhados", "icon": "w_serrated", "tag": "predator", "kind": "bounce", "owner": "piranha",
		"desc": ["Dentes ricocheteiam entre inimigos e fazem sangrar.", "+1 ricochete", "+1 dente", "+30% dano", "+1 dente, +2 ricochetes"],
		"damage": [7, 7, 7, 9.1, 9.1], "cooldown": [1.4, 1.35, 1.3, 1.25, 1.15], "amount": [1, 1, 2, 2, 3], "bounces": [2, 3, 3, 3, 5],
		"sheet": "fx/tooth", "speed": 260.0, "size": 4.0, "bleed": 2.0,
	},
	"moray_strike": {
		"name": "Bote da Moreia", "icon": "w_moray_strike", "tag": "predator", "kind": "strike", "owner": "moreia",
		"desc": ["Moreias saltam de fendas e mordem inimigos.", "-10% recarga", "+1 moreia", "+30% dano", "+1 moreia, +30% dano"],
		"damage": [22, 22, 22, 28.6, 37], "cooldown": [2.6, 2.35, 2.35, 2.2, 2.0], "amount": [1, 1, 2, 2, 3],
		"visual": "moray", "radius": 170.0, "bleed": 3.0,
	},
	"gold_rain": {
		"name": "Chuva de Ouro", "icon": "w_gold_rain", "tag": "", "kind": "strike", "owner": "dourado_raro",
		"desc": ["Moedas douradas caem sobre os inimigos.", "+1 moeda", "+30% dano", "+2 moedas", "Abates podem soltar pérolas"],
		"damage": [9, 9, 11.7, 11.7, 13], "cooldown": [2.2, 2.2, 2.1, 2.0, 1.8], "amount": [3, 4, 4, 6, 7],
		"visual": "coin", "radius": 230.0, "explode": 14.0,
	},
	"orca_breach": {
		"name": "Salto da Orca", "icon": "w_orca_breach", "tag": "predator", "kind": "slam", "owner": "orca",
		"desc": ["Um impacto gigante esmaga e empurra tudo ao redor.", "+20% área", "+30% dano", "-15% recarga", "+30% dano, atordoa mais"],
		"damage": [26, 26, 33.8, 33.8, 44], "cooldown": [4.5, 4.4, 4.2, 3.6, 3.4], "area": [1.0, 1.2, 1.2, 1.2, 1.3], "stun": [0.3, 0.3, 0.3, 0.3, 0.6],
		"radius": 70.0, "knock": 320.0, "sheet": "fx/splash_ring",
	},
	"cavitation": {
		"name": "Estalo de Pistola", "icon": "w_cavitation", "tag": "current", "kind": "shot", "owner": "camarao",
		"desc": ["Bolha de cavitação que explode e atordoa.", "+30% dano", "+1 estalo", "+30% explosão", "+1 estalo, -15% recarga"],
		"damage": [10, 13, 13, 13, 13], "cooldown": [1.5, 1.45, 1.4, 1.35, 1.15], "amount": [1, 1, 2, 2, 3], "area": [1.0, 1.0, 1.0, 1.3, 1.3],
		"sheet": "fx/cavitation", "speed": 300.0, "life": 1.0, "size": 5.0, "explode": 22.0, "stun": 0.5, "target": "nearest", "sfx": "crit",
	},
	"claw": {
		"name": "Garra Martelo", "icon": "w_claw", "tag": "coral", "kind": "lash", "owner": "caranguejo",
		"desc": ["Uma pinça gigante esmaga à sua frente e atordoa.", "+30% dano", "+20% área", "Golpeia também atrás", "+30% dano, -15% recarga"],
		"damage": [20, 26, 26, 26, 34], "cooldown": [1.6, 1.55, 1.5, 1.45, 1.25], "area": [1.0, 1.0, 1.2, 1.2, 1.2], "amount": [1, 1, 1, 2, 2],
		"sheet": "fx/claw_snap", "reach": 30.0, "arc": 1.1, "knock": 200.0, "stun": 0.3, "sfx": "crunch",
	},
	"tentacles": {
		"name": "Tentáculos Urticantes", "icon": "w_tentacles", "tag": "poison", "kind": "tentacle", "owner": "agua_viva",
		"desc": ["Tentáculos queimam os inimigos próximos e os lentificam.", "+1 tentáculo", "+30% dano", "+1 tentáculo, +20% alcance", "+2 tentáculos"],
		"damage": [6, 6, 7.8, 7.8, 9], "cooldown": [1.2, 1.2, 1.15, 1.1, 1.0], "amount": [2, 3, 3, 4, 6], "area": [1.0, 1.0, 1.0, 1.2, 1.2],
		"radius": 70.0, "slow": 0.4, "poison": 2.0, "color": "e0a8ff",
	},
	"sucker": {
		"name": "Ventosa Bumerangue", "icon": "w_sucker", "tag": "abyss", "kind": "boomerang", "owner": "lula",
		"desc": ["Um tentáculo com ventosas vai e volta, atravessando tudo.", "+30% dano", "+1 ventosa", "+25% alcance", "+1 ventosa, +30% dano"],
		"damage": [12, 15.6, 15.6, 15.6, 20], "cooldown": [1.8, 1.7, 1.65, 1.6, 1.45], "amount": [1, 1, 2, 2, 3], "area": [1.0, 1.0, 1.0, 1.25, 1.25],
		"sheet": "fx/sucker", "range": 120.0, "speed": 260.0, "size": 6.0,
	},
	"shell_bounce": {
		"name": "Casco Ricochete", "icon": "w_shell_bounce", "tag": "coral", "kind": "bounce", "owner": "tartaruga",
		"desc": ["Um casco giratório ricocheteia pesado entre inimigos.", "+1 ricochete", "+30% dano", "+1 casco", "+2 ricochetes, +30% dano"],
		"damage": [14, 14, 18.2, 18.2, 23.7], "cooldown": [1.9, 1.85, 1.8, 1.75, 1.6], "amount": [1, 1, 1, 2, 2], "bounces": [3, 4, 4, 4, 6],
		"sheet": "fx/shell_spin", "speed": 210.0, "size": 7.0, "knock": 180.0, "spin": 14.0,
	},
	"urchin_burst": {
		"name": "Chuva de Espinhos", "icon": "w_urchin_burst", "tag": "coral", "kind": "nova", "owner": "ourico",
		"desc": ["Uma explosão de espinhos roxos em todas as direções.", "+2 espinhos", "+30% dano", "Perfura +1", "+4 espinhos, -15% recarga"],
		"damage": [5, 5, 6.5, 6.5, 7], "cooldown": [2.2, 2.2, 2.1, 2.0, 1.75], "amount": [10, 12, 12, 12, 16], "pierce": [1, 1, 1, 2, 2],
		"sheet": "fx/spine_violet", "speed": 200.0, "life": 0.9, "size": 3.0,
	},
	"mucus": {
		"name": "Rastro de Muco", "icon": "w_mucus", "tag": "poison", "kind": "trail", "owner": "caramujo",
		"desc": ["Deixa um rastro de muco que gruda e corrói.", "+1s de duração", "+30% dano", "+20% área", "+30% dano, +1s"],
		"damage": [3, 3, 3.9, 3.9, 5], "cooldown": [0.4, 0.4, 0.4, 0.4, 0.35], "duration": [3.0, 4.0, 4.0, 4.0, 5.0], "area": [1.0, 1.0, 1.0, 1.2, 1.2],
		"sheet": "fx/mucus", "radius": 16.0, "slow": 0.5,
	},
	"sticky_guts": {
		"name": "Tripas Pegajosas", "icon": "w_sticky_guts", "tag": "poison", "kind": "mine", "owner": "pepino",
		"desc": ["Solta tripas que explodem em gosma ao serem tocadas.", "+1 armadilha", "+30% dano", "+25% área", "+1 armadilha, -15% recarga"],
		"damage": [18, 18, 23.4, 23.4, 26], "cooldown": [2.6, 2.5, 2.4, 2.3, 2.0], "amount": [1, 2, 2, 2, 3], "area": [1.0, 1.0, 1.0, 1.25, 1.25],
		"sheet": "fx/guts", "radius": 28.0, "slow": 0.7, "life": 9.0,
	},
	"scavengers": {
		"name": "Enxame Necrófago", "icon": "w_scavengers", "tag": "", "kind": "summon", "owner": "isopode",
		"desc": ["Isópodes famintos saem e roem os inimigos.", "+1 isópode", "+30% dano", "+1 isópode, +2s", "+2 isópodes"],
		"damage": [5, 5, 6.5, 6.5, 7.5], "cooldown": [3.8, 3.7, 3.6, 3.5, 3.3], "amount": [2, 3, 3, 4, 6], "duration": [6.0, 6, 6, 8, 8],
		"sheet": "creatures/isopod", "speed": 150.0,
	},
	"otter_stone": {
		"name": "Pedra da Lontra", "icon": "w_otter_stone", "tag": "predator", "kind": "lob", "owner": "lontra",
		"desc": ["Arremessa uma pedra pesada que atordoa onde cai.", "+30% dano", "+1 pedra", "+25% área", "+1 pedra, -15% recarga"],
		"damage": [18, 23.4, 23.4, 23.4, 26], "cooldown": [2.0, 1.95, 1.9, 1.85, 1.6], "amount": [1, 1, 2, 2, 3], "area": [1.0, 1.0, 1.0, 1.25, 1.25],
		"sheet": "fx/stone", "explode": 20.0, "stun": 0.6, "speed": 190.0,
	},
	"scissor_jaws": {
		"name": "Mandíbulas-Tesoura", "icon": "w_scissor_jaws", "tag": "predator", "kind": "strike", "owner": "minhoca",
		"desc": ["Mandíbulas brotam do fundo sob os inimigos.", "+1 mandíbula", "+30% dano", "+1 mandíbula", "+1 mandíbula, +30% dano"],
		"damage": [20, 20, 26, 26, 33.8], "cooldown": [2.2, 2.1, 2.0, 1.9, 1.7], "amount": [1, 2, 2, 3, 4],
		"visual": "jaws", "radius": 180.0, "bleed": 3.0,
	},
	"hypno_lure": {
		"name": "Luz Hipnótica", "icon": "w_hypno_lure", "tag": "abyss", "kind": "vortex", "owner": "vibora",
		"desc": ["Uma luz à sua frente hipnotiza e puxa inimigos.", "+25% área", "+30% dano", "+1s de duração", "+30% dano, puxa mais forte"],
		"damage": [6, 6, 7.8, 7.8, 10], "cooldown": [4.0, 3.9, 3.8, 3.7, 3.4], "amount": [1, 1, 1, 1, 1], "area": [1.0, 1.25, 1.25, 1.25, 1.3],
		"duration": [2.5, 2.5, 2.5, 3.5, 3.5], "radius": 46.0, "pull": [110.0, 110, 110, 110, 150], "at_player": true, "tint": "7affff",
	},
	"star_mucus": {
		"name": "Muco Estelar", "icon": "w_star_mucus", "tag": "abyss", "kind": "nova", "owner": "lula_vampira",
		"desc": ["Uma nuvem de muco brilhante que cega e lentifica.", "+2 orbes", "+30% dano", "Lentidão maior", "+3 orbes, -15% recarga"],
		"damage": [7, 7, 9.1, 9.1, 9.1], "cooldown": [2.4, 2.4, 2.3, 2.2, 1.9], "amount": [6, 8, 8, 8, 11], "pierce": [2, 2, 2, 2, 3],
		"slow": [0.35, 0.35, 0.35, 0.55, 0.55], "sheet": "fx/light_orb", "speed": 110.0, "life": 1.3, "size": 5.0,
	},
	"louse_swarm": {
		"name": "Enxame de Piolhos", "icon": "w_louse_swarm", "tag": "poison", "kind": "summon", "owner": "piolho",
		"desc": ["Piolhos-do-mar saem de você e devoram inimigos.", "+1 piolho", "+30% dano", "+1 piolho", "+2 piolhos, +30% dano"],
		"damage": [3.5, 3.5, 4.5, 4.5, 6], "cooldown": [3.6, 3.5, 3.4, 3.3, 3.0], "amount": [3, 4, 4, 5, 7], "duration": [5.0, 5, 5, 5, 6],
		"sheet": "creatures/louse", "speed": 210.0, "latch": true,
	},
}

## Two maxed weapons -> one fused weapon that levels up to 10. The fused
## weapon uses an archetype with "base" values; each level scales them.
const FUSIONS := {
	"storm_bubbles": {"name": "Bolhas de Tempestade", "icon": "f_storm_bubbles", "from": ["bubble", "pulse"], "tag": "volt",
		"desc": "Bolhas elétricas que dão choque em cadeia a cada acerto.", "kind": "shot",
		"base": {"damage": 14.0, "cooldown": 0.9, "amount": 3, "pierce": 2}, "sheet": "fx/volt_ball", "speed": 240.0, "life": 1.3,
		"size": 5.0, "target": "nearest", "chain": 2, "sfx": "bubble"},
	"ink_vortex": {"name": "Vórtice de Tinta", "icon": "f_ink_vortex", "from": ["ink", "whirl"], "tag": "poison",
		"desc": "Redemoinhos de tinta venenosa surgem sobre os inimigos e os sugam.", "kind": "vortex",
		"base": {"damage": 9.0, "cooldown": 3.4, "amount": 2, "area": 1.0, "duration": 4.0}, "radius": 44.0, "pull": 70.0},
	"thorn_tempest": {"name": "Tempestade de Espinhos", "icon": "f_thorn_tempest", "from": ["spines", "urchin_burst"], "tag": "coral",
		"desc": "Espirais duplas de espinhos que giram e perfuram.", "kind": "nova",
		"base": {"damage": 9.0, "cooldown": 1.3, "amount": 16, "pierce": 2}, "sheet": "fx/spine_violet", "speed": 210.0, "life": 1.1,
		"size": 3.0, "spiral": true},
	"royal_school": {"name": "Cardume Real", "icon": "f_royal_school", "from": ["pilot", "silver_school"], "tag": "predator",
		"desc": "Um cardume imperial gira ao redor e dispara sobre os inimigos.", "kind": "orbit",
		"base": {"damage": 11.0, "amount": 8, "area": 1.2, "speed": 3.6}, "sheet": "creatures/pilot", "radius": 40.0, "knock": 90.0,
		"hit_cd": 0.3, "animated": true, "hunt": true},
	"orca_song": {"name": "Canto da Orca", "icon": "f_orca_song", "from": ["sonar", "orca_breach"], "tag": "abyss",
		"desc": "Ondas colossais que esmagam, marcam (+25% dano) e puxam XP.", "kind": "slam",
		"base": {"damage": 38.0, "cooldown": 3.2, "area": 1.4, "stun": 0.4}, "radius": 80.0, "knock": 360.0, "mark": 4.0,
		"sheet": "fx/splash_ring", "pull_xp": true},
	"abyss_aurora": {"name": "Aurora Abissal", "icon": "f_abyss_aurora", "from": ["volt_lance", "photophore"], "tag": "abyss",
		"desc": "Feixes de luz giram ao seu redor e queimam tudo que tocam.", "kind": "sweep",
		"base": {"damage": 9.0, "amount": 2, "area": 1.0, "speed": 1.6}, "length": 110.0, "width": 5.0, "hit_cd": 0.35, "color": "9ff0ff"},
	"abyss_shears": {"name": "Tesoura Abissal", "icon": "f_abyss_shears", "from": ["claw", "tail_whip"], "tag": "predator",
		"desc": "Golpes cruzados à frente e atrás que atordoam e fazem sangrar.", "kind": "lash",
		"base": {"damage": 34.0, "cooldown": 1.1, "area": 1.3, "amount": 2}, "sheet": "fx/claw_snap", "reach": 36.0, "arc": 1.8,
		"knock": 220.0, "stun": 0.35, "bleed": 4.0, "sfx": "crunch"},
	"cavitation_cannon": {"name": "Canhão de Cavitação", "icon": "f_cavitation_cannon", "from": ["cavitation", "coral_shard"], "tag": "current",
		"desc": "Rajadas de cavitação que explodem em cadeia.", "kind": "shot",
		"base": {"damage": 22.0, "cooldown": 1.0, "amount": 3, "pierce": 2, "area": 1.3}, "sheet": "fx/cavitation", "speed": 320.0,
		"life": 1.1, "size": 6.0, "explode": 30.0, "stun": 0.5, "target": "random", "sfx": "crit"},
	"armored_boomerang": {"name": "Bumerangue Blindado", "icon": "f_armored_boomerang", "from": ["sucker", "shell_bounce"], "tag": "coral",
		"desc": "Cascos com ventosas vão, ricocheteiam e voltam esmagando.", "kind": "boomerang",
		"base": {"damage": 24.0, "cooldown": 1.4, "amount": 3, "area": 1.3}, "sheet": "fx/shell_spin", "range": 140.0, "speed": 280.0,
		"size": 8.0, "knock": 200.0, "spin": 14.0},
	"slime_marsh": {"name": "Pântano Viscoso", "icon": "f_slime_marsh", "from": ["mucus", "sticky_guts"], "tag": "poison",
		"desc": "Seu rastro vira um pântano que explode em gosma.", "kind": "trail",
		"base": {"damage": 8.0, "cooldown": 0.3, "duration": 5.0, "area": 1.4}, "sheet": "fx/mucus", "radius": 18.0, "slow": 0.7,
		"mine_every": 4},
	"abyss_plague": {"name": "Praga Abissal", "icon": "f_abyss_plague", "from": ["scavengers", "louse_swarm"], "tag": "poison",
		"desc": "Uma praga de isópodes e piolhos devora o oceano.", "kind": "summon",
		"base": {"damage": 7.0, "cooldown": 2.6, "amount": 8, "duration": 7.0}, "sheet": "creatures/louse_f", "speed": 220.0, "latch": true},
	"deadly_ambush": {"name": "Emboscada Mortal", "icon": "f_deadly_ambush", "from": ["moray_strike", "scissor_jaws"], "tag": "predator",
		"desc": "Moreias e mandíbulas atacam de todos os lados.", "kind": "strike",
		"base": {"damage": 40.0, "cooldown": 1.5, "amount": 4}, "visual": "moray", "radius": 220.0, "bleed": 5.0},
	"golden_fangs": {"name": "Presas de Ouro", "icon": "f_golden_fangs", "from": ["gold_rain", "serrated"], "tag": "predator",
		"desc": "Dentes de ouro ricocheteiam e fazem chover pérolas.", "kind": "bounce",
		"base": {"damage": 16.0, "cooldown": 1.1, "amount": 3, "bounces": 5}, "sheet": "fx/gold_tooth", "speed": 280.0, "size": 5.0,
		"bleed": 3.0, "pearls": true},
	"venom_garden": {"name": "Jardim Venenoso", "icon": "f_venom_garden", "from": ["tetrodo", "tentacles"], "tag": "poison",
		"desc": "Névoa tóxica com tentáculos que chicoteiam tudo por perto.", "kind": "aura",
		"base": {"damage": 9.0, "area": 1.6, "amount": 4, "slow": 0.35}, "radius": 44.0, "tick": 0.45, "poison": 4.0, "color": "c8f070",
		"tentacles": true},
	"star_abyss": {"name": "Galáxia Abissal", "icon": "f_star_abyss", "from": ["hypno_lure", "star_mucus"], "tag": "abyss",
		"desc": "Vórtices estrelados puxam os inimigos, cegam e os esmagam.", "kind": "vortex",
		"base": {"damage": 12.0, "cooldown": 2.8, "amount": 2, "area": 1.3, "duration": 4.0}, "radius": 46.0, "pull": 140.0,
		"slow": 0.5, "tint": "b0a0ff"},
	"tide_ring": {"name": "Anel das Marés", "icon": "f_tide_ring", "from": ["bubble_ring", "silver_arrow"], "tag": "current",
		"desc": "Bolhas orbitam e disparam flechas de prata para fora.", "kind": "orbit",
		"base": {"damage": 12.0, "amount": 6, "area": 1.2, "speed": 2.6}, "sheet": "fx/bubble_big", "radius": 36.0, "knock": 120.0,
		"hit_cd": 0.4, "shoot": "fx/silver_arrow"},
}

const FUSION_MAX := 10


## Value of a fusion stat at a level (1..10).
static func fusion_value(f: Dictionary, key: String, level: int, fallback = 0.0):
	var base: Dictionary = f.get("base", {})
	if not base.has(key):
		return f.get(key, fallback)
	var b: float = float(base[key])
	var l := float(level - 1)
	match key:
		"damage":
			return b * (1.0 + 0.16 * l)
		"cooldown":
			return b * maxf(0.55, 1.0 - 0.035 * l)
		"amount":
			return int(b) + int(level / 3)
		"area":
			return b * (1.0 + 0.04 * l)
		"pierce", "bounces":
			return int(b) + int(level / 4)
		"duration":
			return b * (1.0 + 0.05 * l)
		"speed":
			return b * (1.0 + 0.03 * l)
	return b


static func fusion_level_desc(level: int) -> String:
	var parts := ["+16% dano", "-3.5% recarga"]
	if level % 3 == 0:
		parts.append("+1 quantidade")
	if level % 4 == 0:
		parts.append("+1 perfuração")
	return ", ".join(parts)
