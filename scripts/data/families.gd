class_name Families
extends RefCounted
## Body-plan families of the non-fish characters. Each family draws the
## mutations as its own anatomy (see tools/art/beasts*.py), so each one also
## names them its own way: a crab's "fins" are its legs, a snail's "tail" is
## the end of its foot... Species not listed here are fish and use the
## default names in DB.MUTATIONS.

const SPECIES := {
	"caranguejo": "crab", "caranguejo_yeti": "crab",
	"camarao": "shrimp",
	"isopode": "isopod", "piolho": "isopod",
	"lula": "squid", "lula_vampira": "squid",
	"agua_viva": "jelly",
	"ourico": "urchin",
	"pepino": "cucumber",
	"caramujo": "snail",
	"minhoca": "bobbit",
	"verme_tubo": "tubeworm",
	"tartaruga": "turtle",
	"lontra": "otter",
}

## family -> mutation id -> name
const NAMES := {
	"crab": {
		"head_piranha": "Pinças Serrilhadas", "head_sword": "Lança de Aço", "head_lure": "Antenas-Lanterna",
		"fins_spiky": "Patas de Coral", "fins_wing": "Patas-Remo", "fins_volt": "Articulações Elétricas",
		"skin_armor": "Carapaça Blindada", "skin_toxic": "Carapaça Tóxica", "skin_glow": "Carapaça Luminosa",
		"tail_fork": "Leque de Lagosta", "tail_sting": "Cauda de Escorpião", "tail_eel": "Abdômen de Lagosta",
	},
	"shrimp": {
		"head_piranha": "Rostro Serrilhado", "head_sword": "Rostro-Lança", "head_lure": "Antenas-Lanterna",
		"fins_spiky": "Patas Espinhosas", "fins_wing": "Leques-Remo", "fins_volt": "Patas Elétricas",
		"skin_armor": "Exoesqueleto Blindado", "skin_toxic": "Exoesqueleto Tóxico", "skin_glow": "Exoesqueleto Luminoso",
		"tail_fork": "Leque Duplo", "tail_sting": "Télson Farpado", "tail_eel": "Chicote Caudal",
	},
	"isopod": {
		"head_piranha": "Mandíbulas", "head_sword": "Chifre Frontal", "head_lure": "Antena-Lanterna",
		"fins_spiky": "Patas com Espinhos", "fins_wing": "Pleópodes-Remo", "fins_volt": "Patas Elétricas",
		"skin_armor": "Placas Blindadas", "skin_toxic": "Placas Tóxicas", "skin_glow": "Placas Luminosas",
		"tail_fork": "Urópodes Bifurcados", "tail_sting": "Espinho Caudal", "tail_eel": "Cercos Gêmeos",
	},
	"squid": {
		"head_piranha": "Bico e Clavas Dentadas", "head_sword": "Tentáculos-Lança", "head_lure": "Braço-Lanterna",
		"fins_spiky": "Barbatanas Espinhosas", "fins_wing": "Barbatanas Largas", "fins_volt": "Barbatanas Elétricas",
		"skin_armor": "Manto Blindado", "skin_toxic": "Manto Tóxico", "skin_glow": "Manto Luminoso",
		"tail_fork": "Manto Bifurcado", "tail_sting": "Ponta Farpada", "tail_eel": "Filamentos Luminosos",
	},
	"jelly": {
		"head_piranha": "Sino Dentado", "head_sword": "Cúspide de Aço", "head_lure": "Isca Flutuante",
		"fins_spiky": "Nematocistos", "fins_wing": "Véu Nadador", "fins_volt": "Tentáculos Elétricos",
		"skin_armor": "Sino Blindado", "skin_toxic": "Sino Tóxico", "skin_glow": "Sino Luminoso",
		"tail_fork": "Braços Orais Largos", "tail_sting": "Ferrão Oral", "tail_eel": "Filamento Longo",
	},
	"urchin": {
		"head_piranha": "Lanterna de Aristóteles", "head_sword": "Espinho-Lança", "head_lure": "Espinho-Lanterna",
		"fins_spiky": "Pés Espinhosos", "fins_wing": "Pés-Remo", "fins_volt": "Pés Elétricos",
		"skin_armor": "Testa Blindada", "skin_toxic": "Testa Tóxica", "skin_glow": "Testa Luminosa",
		"tail_fork": "Espinhos Gêmeos", "tail_sting": "Espinho Venenoso", "tail_eel": "Filamento Caudal",
	},
	"cucumber": {
		"head_piranha": "Coroa Dentada", "head_sword": "Chifre Oral", "head_lure": "Papila-Lanterna",
		"fins_spiky": "Pódios Espinhosos", "fins_wing": "Véu Nadador", "fins_volt": "Pódios Elétricos",
		"skin_armor": "Couro Blindado", "skin_toxic": "Couro Tóxico", "skin_glow": "Couro Luminoso",
		"tail_fork": "Lobos Caudais", "tail_sting": "Espinho Caudal", "tail_eel": "Fios de Cuvier",
	},
	"snail": {
		"head_piranha": "Rádula Dentada", "head_sword": "Arpão de Cone", "head_lure": "Sifão-Lanterna",
		"fins_spiky": "Tentáculos Espinhosos", "fins_wing": "Asas de Borboleta-do-Mar", "fins_volt": "Tentáculos Elétricos",
		"skin_armor": "Concha Blindada", "skin_toxic": "Concha Tóxica", "skin_glow": "Concha Luminosa",
		"tail_fork": "Pé Bifurcado", "tail_sting": "Pé Farpado", "tail_eel": "Sifão Longo",
	},
	"bobbit": {
		"head_piranha": "Tesouras Serrilhadas", "head_sword": "Tesouras-Lança", "head_lure": "Antena-Lanterna",
		"fins_spiky": "Cerdas de Coral", "fins_wing": "Parapódios-Remo", "fins_volt": "Cerdas Elétricas",
		"skin_armor": "Anéis Blindados", "skin_toxic": "Anéis Tóxicos", "skin_glow": "Anéis Luminosos",
		"tail_fork": "Cauda Bifurcada", "tail_sting": "Ferrão Caudal", "tail_eel": "Cauda Longa",
	},
	"tubeworm": {
		"head_piranha": "Boca Dentada", "head_sword": "Opérculo-Lança", "head_lure": "Penacho-Lanterna",
		"fins_spiky": "Espinhos do Tubo", "fins_wing": "Remos Laterais", "fins_volt": "Tubo Elétrico",
		"skin_armor": "Tubo Blindado", "skin_toxic": "Tubo Tóxico", "skin_glow": "Tubo Luminoso",
		"tail_fork": "Base Bifurcada", "tail_sting": "Ponta Farpada", "tail_eel": "Tubo Longo",
	},
	"turtle": {
		"head_piranha": "Bico Serrilhado", "head_sword": "Chifre de Aço", "head_lure": "Língua-Isca",
		"fins_spiky": "Nadadeiras Espinhosas", "fins_wing": "Nadadeiras Gigantes", "fins_volt": "Nadadeiras Elétricas",
		"skin_armor": "Casco Blindado", "skin_toxic": "Casco Tóxico", "skin_glow": "Casco Luminoso",
		"tail_fork": "Cauda Bifurcada", "tail_sting": "Cauda Espinhosa", "tail_eel": "Cauda Longa",
	},
	"otter": {
		"head_piranha": "Presas Afiadas", "head_sword": "Chifre de Aço", "head_lure": "Isca Luminosa",
		"fins_spiky": "Garras", "fins_wing": "Patas Palmadas", "fins_volt": "Patas Elétricas",
		"skin_armor": "Pelagem Blindada", "skin_toxic": "Pelagem Tóxica", "skin_glow": "Pelagem Luminosa",
		"tail_fork": "Cauda Bifurcada", "tail_sting": "Cauda Espinhosa", "tail_eel": "Cauda Longa",
	},
}


static func mutation_name(species: String, mid: String) -> String:
	var fam: String = SPECIES.get(species, "")
	if fam != "" and NAMES[fam].has(mid):
		return NAMES[fam][mid]
	return DB.MUTATIONS[mid].name
