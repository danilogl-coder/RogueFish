class_name Offers
extends RefCounted
## Monetization data (see docs/MONETIZATION.md).
##
## Rewarded videos are always optional and always give something: they never
## gate progress, have a daily cap and a cooldown, and the VIP pass turns them
## into instant rewards. Real-money products are convenience (pearls, a
## starter bundle, VIP) — nothing sold is exclusive power you can't earn.

## Rewarded video placements.
##  daily    : max videos per day for this placement
##  cooldown : seconds between two videos of this placement
const VIDEOS := {
	"pearls": {"daily": 5, "cooldown": 240.0, "reward": 250, "name": "Pérolas grátis"},
	"revive": {"daily": 12, "cooldown": 0.0, "name": "Reviver"},
	"double": {"daily": 8, "cooldown": 0.0, "name": "Dobrar pérolas"},
	"daily_x2": {"daily": 1, "cooldown": 0.0, "name": "Diária em dobro"},
	"reroll": {"daily": 10, "cooldown": 30.0, "name": "Rerrolar cartas"},
}

## In-app products. "consumable" ones can be bought many times.
##  price  : display price used until the store returns the localized one
##  tag    : small badge on the card
const PRODUCTS := {
	"starter": {"name": "Pacote Inicial", "icon": "gift", "price": "R$ 7,90", "consumable": false, "tag": "1x · -65%",
		"pearls": 6000, "species": "tartaruga", "items": ["relic_compass"],
		"desc": "6.000 pérolas + Tartaruga + Rosa-dos-Ventos. Só uma vez."},
	"vip": {"name": "Passe VIP Abissal", "icon": "star", "price": "R$ 19,90", "consumable": false, "tag": "SEM VÍDEOS",
		"desc": "Recompensas de vídeo na hora, sem assistir. +25% pérolas em toda partida. Para sempre."},
	"pearls_1": {"name": "Punhado de Pérolas", "icon": "pearl", "price": "R$ 4,90", "consumable": true, "tag": "",
		"pearls": 2500, "desc": "2.500 pérolas."},
	"pearls_2": {"name": "Bolsa de Pérolas", "icon": "pearl", "price": "R$ 12,90", "consumable": true, "tag": "+15%",
		"pearls": 7500, "desc": "7.500 pérolas."},
	"pearls_3": {"name": "Baú de Pérolas", "icon": "chest", "price": "R$ 24,90", "consumable": true, "tag": "POPULAR",
		"pearls": 17000, "desc": "17.000 pérolas."},
	"pearls_4": {"name": "Tesouro Abissal", "icon": "chest", "price": "R$ 59,90", "consumable": true, "tag": "MELHOR VALOR",
		"pearls": 48000, "desc": "48.000 pérolas."},
}

const VIP_PEARL_BONUS := 0.25

## Public privacy policy (docs/privacy.html published with GitHub Pages).
const PRIVACY_URL := "https://danilogl-coder.github.io/roguefish/privacy.html"
