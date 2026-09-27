class_name Evolutions
extends RefCounted
## Every character grows through its own natural life cycle: the stages are
## the real stages of that animal (a crab hatches as a zoea larva and only
## walks after the megalopa stage, a jellyfish starts as a star-shaped
## ephyra...) and end in a legendary form of its own.
##
## Each stage has a name, a line of flavour and a way of moving
## (see Player._move and MOVES below), so a character plays differently as it
## grows, and two animals never feel the same.

## Locomotion modes. The numbers tune Player._move.
##  accel/drag: how fast the velocity follows the stick
##  speed     : top speed multiplier
##  floor     : bound to the sea floor (gravity pulls it down)
##  climb     : vertical speed multiplier while leaving the floor
const MOVES := {
	"swim": {"name": "Nado", "desc": "Nado livre e equilibrado.", "accel": 820.0, "drag": 420.0, "speed": 1.0},
	"dart": {"name": "Arrancada", "desc": "Acelera e freia na hora, muda de direção em um instante.", "accel": 1500.0, "drag": 900.0, "speed": 1.05},
	"cruise": {"name": "Cruzeiro", "desc": "Demora a embalar, mas embalado é o mais rápido do mar.", "accel": 300.0, "drag": 140.0, "speed": 1.18},
	"drift": {"name": "Plâncton", "desc": "Flutua com a corrente: pouco controle, mas difícil de acertar.", "accel": 260.0, "drag": 120.0, "speed": 0.85, "evade": 0.12},
	"pulse": {"name": "Pulsação", "desc": "Avança em pulsos fortes e plana entre eles.", "accel": 0.0, "drag": 180.0, "speed": 1.0, "pulse": 0.62, "kick": 1.9},
	"jet": {"name": "Jato", "desc": "Jatos de água em rajadas, muito rápidos, com recuo entre eles.", "accel": 0.0, "drag": 260.0, "speed": 1.1, "pulse": 0.42, "kick": 2.3},
	"walk": {"name": "Caminhada", "desc": "Anda firme pelo fundo e pula para nadar um pouco.", "accel": 1300.0, "drag": 1100.0, "speed": 1.1, "floor": true, "climb": 0.55},
	"crawl": {"name": "Rastejo", "desc": "Gruda no fundo: lento, mas nada o derruba. Sobe devagar.", "accel": 900.0, "drag": 900.0, "speed": 0.95, "floor": true, "climb": 0.4, "armor": 2.0},
	"slither": {"name": "Serpentear", "desc": "Ondula como serpente: ganha velocidade indo reto.", "accel": 700.0, "drag": 380.0, "speed": 1.0, "straight": 0.3},
}

## species -> 5 stages of [name, description, move]
const LINES := {
	"dourado": [["Larva", "Transparente, só olhos e saco vitelino.", "drift"], ["Alevino", "Ainda cinzento, como todo peixinho-dourado bebê.", "swim"],
		["Juvenil", "O dourado começa a aparecer em manchas.", "swim"], ["Adulto", "Laranja vivo e cauda de véu.", "swim"],
		["Oranda Imperial", "Coroa de gordura na cabeça e véus enormes.", "swim"]],
	"sardinha": [["Larva", "Um fio de vidro com dois olhos.", "drift"], ["Alevino", "Prateada e translúcida.", "dart"],
		["Juvenil", "Ganha o dorso azul.", "dart"], ["Adulta", "Espelho de prata do cardume.", "dart"],
		["Rainha do Cardume", "Pintas azuis e brilho de metal.", "dart"]],
	"camarao": [["Zoea", "Larva espinhosa que vive no plâncton.", "drift"], ["Pós-larva", "Já parece um camarão, de vidro.", "swim"],
		["Juvenil", "A garra-pistola começa a crescer.", "walk"], ["Adulto", "Vermelho, garra enorme.", "walk"],
		["Pistoleiro Alfa", "Garra de canhão e antenas plumosas.", "walk"]],
	"caramujo": [["Véliger", "Larva que nada com duas asas de cílios.", "drift"], ["Juvenil", "Assentou no fundo: concha fina.", "crawl"],
		["Adulto", "Concha com estrias e nós.", "crawl"], ["Múrex", "Concha cheia de espinhos.", "crawl"],
		["Concha-Rainha", "Concha gigante com lábio perolado.", "crawl"]],
	"pepino": [["Auriculária", "Larva de vidro com faixas de cílios.", "drift"], ["Doliolária", "Um barril com anéis que gira na água.", "drift"],
		["Juvenil", "Desceu ao fundo e rasteja.", "crawl"], ["Adulto", "Papilas altas nas costas.", "crawl"],
		["Pepino-Abissal", "Criou um véu e voltou a nadar.", "swim"]],
	"baiacu": [["Larva", "Uma bolinha de vidro com olhos.", "drift"], ["Alevino", "Redondo e pintadinho.", "swim"],
		["Juvenil", "As manchas escurecem.", "swim"], ["Adulto", "Pronto para inflar.", "swim"],
		["Baiacu-Espinho", "Espinhos longos sempre de pé.", "swim"]],
	"neon": [["Larva", "Um risco de vidro.", "drift"], ["Alevino", "A faixa azul acende.", "dart"],
		["Juvenil", "Metade da barriga fica vermelha.", "dart"], ["Adulto", "Neon completo.", "dart"],
		["Neon-Cardeal", "Vermelho da cabeça à cauda.", "dart"]],
	"ourico": [["Plúteo", "Larva de vidro com braços longos.", "drift"], ["Juvenil", "Assentou: espinhos curtos.", "walk"],
		["Adulto", "Espinhos longos e pés ambulacrais.", "walk"], ["Ouriço-Diadema", "Espinhos-agulha listrados.", "walk"],
		["Ouriço-Coroa", "Espinhos com pontas luminosas.", "walk"]],
	"lanterna": [["Larva", "Olhos pedunculados e corpo de vidro.", "drift"], ["Alevino", "Os primeiros fotóforos acendem.", "swim"],
		["Juvenil", "Uma fileira de luzes.", "swim"], ["Adulto", "Duas fileiras de luz.", "swim"],
		["Lanterna-Abissal", "Um farol vivo do abismo.", "swim"]],
	"agua_viva": [["Éfira", "Estrela de oito braços que pulsa.", "pulse"], ["Medusa Jovem", "O sino se fecha.", "pulse"],
		["Medusa", "Tentáculos longos e gônadas.", "pulse"], ["Medusa-Juba", "Juba de tentáculos gigantes.", "pulse"],
		["Medusa-Coroa", "Borda que brilha no escuro.", "pulse"]],
	"caranguejo": [["Zoea", "Larva com espinho nas costas, vive no plâncton.", "drift"], ["Megalopa", "Metade caranguejo, metade lagosta: ainda nada.", "swim"],
		["Juvenil", "Desceu ao fundo e anda de lado.", "walk"], ["Adulto", "Pinça esmagadora.", "walk"],
		["Caranguejo-Rei", "Carapaça com coroa de espinhos.", "walk"]],
	"lula": [["Paralarva", "Minúscula, de vidro, já dá jatos.", "jet"], ["Juvenil", "As barbatanas crescem.", "jet"],
		["Adulta", "Muda de cor com cromatóforos.", "jet"], ["Lula-Gigante", "Clavas com ganchos.", "jet"],
		["Lula-Colossal", "O maior olho do mar.", "jet"]],
	"garoupa": [["Larva", "Espinhos longos de larva.", "drift"], ["Alevino", "Faixas escuras marcadas.", "swim"],
		["Juvenil", "Pintas por todo o corpo.", "swim"], ["Adulta", "Robusta e paciente.", "cruise"],
		["Mero", "Um gigante de lábios grossos.", "cruise"]],
	"barracuda": [["Larva", "Uma agulha de vidro.", "drift"], ["Alevino", "Manchas escuras de camuflagem.", "dart"],
		["Juvenil", "Listras nas costas.", "dart"], ["Adulta", "Prata e dentes.", "dart"],
		["Barracuda-Gigante", "Cicatrizes de mil caçadas.", "dart"]],
	"tartaruga": [["Filhote", "Acabou de sair do ovo.", "swim"], ["Juvenil", "O casco ganha escudos.", "swim"],
		["Subadulta", "Casco com anéis de crescimento.", "cruise"], ["Adulta", "Quilha e cracas.", "cruise"],
		["Ancestral", "Casco com costuras luminosas.", "cruise"]],
	"piranha": [["Larva", "Transparente e faminta.", "drift"], ["Alevino", "Pintinhas prateadas.", "swim"],
		["Juvenil", "A barriga fica vermelha.", "swim"], ["Adulta", "Mandíbula de aço.", "dart"],
		["Piranha-Negra", "Escura, de olhos vermelhos.", "dart"]],
	"moreia": [["Leptocéfalo", "Larva em forma de folha de vidro.", "drift"], ["Juvenil", "Enguia escura e fina.", "slither"],
		["Adulta", "Pintas e boca de agulhas.", "slither"], ["Moreia-Gigante", "Grossa como um tronco.", "slither"],
		["Moreia-Dragão", "Chifres nas narinas e cores de fogo.", "slither"]],
	"isopode": [["Manca", "Recém-nascido, ainda sem o último par de patas.", "walk"], ["Juvenil", "Placas pálidas.", "walk"],
		["Adulto", "Placas cinzentas.", "walk"], ["Isópode Gigante", "Espinhos nas costas.", "walk"],
		["Isópode Colossal", "Olhos que brilham.", "walk"]],
	"lontra": [["Filhote", "Uma bolinha de pelo que boia.", "swim"], ["Juvenil", "Pelo liso e marrom.", "dart"],
		["Adulta", "Bigodes e agilidade.", "dart"], ["Veterana", "Cicatrizes de batalha.", "dart"],
		["Anciã", "Cabeça prateada e sua pedra da sorte.", "dart"]],
	"minhoca": [["Trocófora", "Larva que gira com um cinto de cílios.", "drift"], ["Juvenil", "Um vermezinho rosado.", "slither"],
		["Adulta", "Brilho de arco-íris.", "slither"], ["Bobbit Gigante", "Cinco antenas e tesouras.", "slither"],
		["Bobbit Colossal", "Anéis que brilham.", "slither"]],
	"piolho": [["Náuplio", "Larva de três pares de patas.", "drift"], ["Copepodito", "Procura um hospedeiro.", "swim"],
		["Calimo", "Preso por um fio, crescendo.", "swim"], ["Adulto", "Escudo largo.", "swim"],
		["Rainha da Colônia", "Bolsas de ovos enormes.", "swim"]],
	"dourado_raro": [["Larva", "Uma faísca dourada.", "drift"], ["Alevino", "Brilha como moeda.", "swim"],
		["Juvenil", "Listras de ouro.", "swim"], ["Adulto", "Ouro puro.", "swim"],
		["Tesouro Vivo", "Escamas de ouro e barbatanas de sol.", "swim"]],
	"orca": [["Filhote", "Manchas ainda alaranjadas.", "swim"], ["Juvenil", "Preto e branco nítido.", "swim"],
		["Adulta", "Nadadeira dorsal alta.", "cruise"], ["Matriarca", "Líder do grupo.", "cruise"],
		["Lenda dos Mares", "Cicatrizes e dorsal gigante.", "cruise"]],
	"vibora": [["Larva", "Olhos em hastes.", "drift"], ["Juvenil", "Dentes já enormes.", "swim"],
		["Adulta", "Fotóforos ao longo do ventre.", "swim"], ["Víbora-Abissal", "Presas maiores que a cabeça.", "swim"],
		["Víbora-Estelar", "Um céu estrelado no corpo.", "swim"]],
	"lula_vampira": [["Paralarva", "Um só par de barbatanas.", "jet"], ["Juvenil", "Dois pares de barbatanas!", "jet"],
		["Adulta", "A capa se abre: agora plana.", "pulse"], ["Anciã", "Pontas dos braços brancas.", "pulse"],
		["Vampira Suprema", "Capa com borda luminosa.", "pulse"]],
	"caranguejo_yeti": [["Zoea", "Larva das fontes termais.", "drift"], ["Megalopa", "Nada entre as chaminés.", "swim"],
		["Juvenil", "Os pelos começam a crescer.", "walk"], ["Adulto", "Braços peludos cheios de bactérias.", "walk"],
		["Yeti Ancestral", "Pelos que brilham.", "walk"]],
	"verme_tubo": [["Trocófora", "Larva que gira na corrente quente.", "drift"], ["Juvenil", "Um tubinho mole.", "slither"],
		["Adulto", "Tubo com anéis.", "slither"], ["Verme-Tubo Gigante", "Penacho duplo e cracas.", "slither"],
		["Rei das Fontes", "Penacho luminoso.", "slither"]],
	"tubarao": [["Filhote", "Nasceu pronto para caçar.", "swim"], ["Juvenil", "Pontas das nadadeiras escuras.", "swim"],
		["Adulto", "Dentes serrilhados.", "cruise"], ["Tubarão-Rei", "Cicatrizes de rei.", "cruise"],
		["Imperador", "Nenhum mar lhe resiste.", "cruise"]],
	"kraken": [["Paralarva", "Um pontinho de vidro com braços.", "jet"], ["Juvenil", "Ventosas afiadas.", "jet"],
		["Adulto", "Braços de chicote.", "jet"], ["Kraken", "Afunda navios.", "jet"],
		["Kraken Ancestral", "Uma lenda com olhos de ouro.", "jet"]],
	"pescadora": [["Larva", "Uma bolinha com a primeira isca.", "drift"], ["Juvenil", "A isca acende.", "swim"],
		["Adulta", "Dentes de agulha.", "swim"], ["Rainha", "Isca dupla.", "swim"],
		["Rainha Abissal", "Coroa de luzes.", "swim"]],
	"leviata": [["Larva", "Uma fita elétrica.", "drift"], ["Juvenil", "Faíscas nas escamas.", "slither"],
		["Adulto", "Chifres de coral.", "slither"], ["Serpente do Trovão", "Nuvem de raios.", "slither"],
		["Leviatã", "A tempestade viva.", "slither"]],
	"megalodonte": [["Filhote", "Já é maior que um tubarão.", "swim"], ["Juvenil", "Dentes do tamanho de mãos.", "cruise"],
		["Adulto", "Rei do mar antigo.", "cruise"], ["Colosso", "Casco de cicatrizes.", "cruise"],
		["Megalodonte Ancestral", "Voltou da extinção.", "cruise"]],
	"titanacon": [["Cria", "Recém-saído do ovo abissal.", "swim"], ["Juvenil", "Placas de pedra.", "cruise"],
		["Adulto", "Brasas nas escamas.", "cruise"], ["Titã", "Engole cardumes.", "cruise"],
		["Titanacon", "O fim do oceano.", "cruise"]],
}


static func stage(species: String, i: int) -> Array:
	var line: Array = LINES.get(species, LINES["dourado"])
	return line[clampi(i, 0, line.size() - 1)]


static func stage_name(species: String, i: int) -> String:
	return String(stage(species, i)[0])


static func stage_desc(species: String, i: int) -> String:
	return String(stage(species, i)[1])


static func move_id(species: String, i: int) -> String:
	return String(stage(species, i)[2])


static func move(species: String, i: int) -> Dictionary:
	return MOVES[move_id(species, i)]
