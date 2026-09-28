extends Node
## In-app purchases (autoload "Billing").
##
##   Billing.buy("pearls_2")      # grants through Billing.grant() when paid
##
## Backends:
##  * Google Play: the official "GodotGooglePlayBilling" Android plugin, 3.x
##    API (godot-sdk-integrations/godot-google-play-billing, Godot 4.2+).
##    When its singleton exists it is used automatically: product ids here
##    must match the ids created in the Play Console.
##  * any other store can register with `Billing.set_backend(obj)`, obj
##    having `buy(product_id: String, on_done: Callable)` that calls
##    on_done.call(true) once the purchase is confirmed.
##  * debug builds without a store use a simulated confirmation dialog (no
##    money involved) so the flow can be tested. Release builds without a
##    store show the shop as unavailable.
##
## Purchases are granted client side. Before launch, validate purchase
## tokens on a server (see docs/MONETIZATION.md).

signal purchased(product_id: String)
signal failed(product_id: String, reason: String)
signal prices_updated

var prices := {}                 ## product id -> localized price from the store
var _backend: Object = null
var _play: Object = null          ## GodotGooglePlayBilling singleton
var _pending := ""
var _consuming := {}             ## purchase token -> product id, until consumed

const PLAY_OK := 0
const PLAY_CANCELED := 1
const PLAY_ALREADY_OWNED := 7
const PLAY_PURCHASED := 1        ## purchase_state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotGooglePlayBilling"):
		attach_play(Engine.get_singleton("GodotGooglePlayBilling"))


## Hooks up the Google Play Billing plugin (or a stand-in with the same
## signals and methods, for tests).
func attach_play(play: Object) -> void:
	_play = play
	_play.connect("connected", _on_play_connected)
	_play.connect("disconnected", func(): get_tree().create_timer(10.0).timeout.connect(Callable(_play, "startConnection")))
	_play.connect("connect_error", func(_code: int, _msg: String): get_tree().create_timer(30.0).timeout.connect(Callable(_play, "startConnection")))
	_play.connect("query_product_details_response", _on_play_details)
	_play.connect("query_purchases_response", _on_play_owned)
	_play.connect("on_purchase_updated", _on_play_updated)
	_play.connect("consume_purchase_response", _on_play_consumed)
	_play.call("startConnection")


func set_backend(obj: Object) -> void:
	_backend = obj


func available() -> bool:
	return _play != null or _backend != null or OS.is_debug_build()


func price_text(id: String) -> String:
	return String(prices.get(id, Offers.PRODUCTS[id].price))


func owned(id: String) -> bool:
	return Profile.purchases.has(id)


func can_buy(id: String) -> bool:
	var d: Dictionary = Offers.PRODUCTS[id]
	return available() and (bool(d.consumable) or not owned(id))


# ------------------------------------------------------------------- buy
func buy(id: String) -> void:
	if not can_buy(id):
		_fail(id, "indisponível")
		return
	_pending = id
	if _play != null:
		var r: Dictionary = _play.call("purchase", id, "", "", false)
		if int(r.get("response_code", PLAY_OK)) != PLAY_OK:
			_fail(id, String(r.get("debug_message", "")))
	elif _backend != null:
		_backend.call("buy", id, func(ok: bool):
			if ok:
				grant(id)
			else:
				_fail(id, "cancelada"))
	else:
		_simulate(id)


## Gives the player what the product contains (called once per purchase).
func grant(id: String) -> void:
	var d: Dictionary = Offers.PRODUCTS[id]
	if not bool(d.consumable):
		if owned(id):
			return
		Profile.purchases.append(id)
	if id == "vip":
		Profile.vip = true
	Profile.add_pearls(int(d.get("pearls", 0)))
	var sp: String = d.get("species", "")
	if sp != "" and not Profile.unlocked.has(sp):
		Profile.unlocked.append(sp)
	for it in d.get("items", []):
		if not Profile.owned.has(it):
			Profile.owned.append(it)
	Profile.save_game()
	_pending = ""
	purchased.emit(id)


func _fail(id: String, reason: String) -> void:
	_pending = ""
	failed.emit(id, reason)


## Asks the store again for everything this account owns (new phone,
## reinstall). Non-consumables come back through grant().
func restore() -> void:
	if _play != null:
		_play.call("queryPurchases", "inapp", false)
	elif _backend != null and _backend.has_method("restore"):
		_backend.call("restore")


# ------------------------------------------------------------ Google Play
func _on_play_connected() -> void:
	_play.call("queryProductDetails", PackedStringArray(Offers.PRODUCTS.keys()), "inapp")
	_play.call("queryPurchases", "inapp", false)


func _on_play_details(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != PLAY_OK:
		return
	for d in res.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			prices[String(d.get("product_id", ""))] = String(offers[0].get("formatted_price", ""))
	prices_updated.emit()


## Purchases this account already owns (app start, "restore").
func _on_play_owned(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) == PLAY_OK:
		_handle_purchases(res.get("purchases", []))


## Result of the purchase screen.
func _on_play_updated(res: Dictionary) -> void:
	match int(res.get("response_code", -1)):
		PLAY_OK:
			_handle_purchases(res.get("purchases", []))
		PLAY_CANCELED:
			_fail(_pending, "cancelada")
		PLAY_ALREADY_OWNED:
			_play.call("queryPurchases", "inapp", false)
		_:
			_fail(_pending, String(res.get("debug_message", "")))


## Non-consumables are granted and acknowledged; consumables (pearl packs)
## are granted only once Google confirms the consume, so a purchase that is
## returned again by queryPurchases can never be paid out twice.
func _handle_purchases(list: Array) -> void:
	for p in list:
		if typeof(p) != TYPE_DICTIONARY or int(p.get("purchase_state", 0)) != PLAY_PURCHASED:
			continue  # pending (e.g. cash payment): it comes back when paid
		var token := String(p.get("purchase_token", ""))
		for pid in p.get("product_ids", []):
			var id := String(pid)
			if not Offers.PRODUCTS.has(id):
				continue
			if bool(Offers.PRODUCTS[id].consumable):
				if not _consuming.has(token):
					_consuming[token] = id
					_play.call("consumePurchase", token)
			else:
				if not bool(p.get("is_acknowledged", false)):
					_play.call("acknowledgePurchase", token)
				grant(id)


func _on_play_consumed(res: Dictionary) -> void:
	var token := String(res.get("token", ""))
	var id := String(_consuming.get(token, ""))
	_consuming.erase(token)
	if id == "":
		return
	if int(res.get("response_code", -1)) == PLAY_OK:
		grant(id)
	else:
		_fail(id, String(res.get("debug_message", "")))


# --------------------------------------------------------- debug stand-in
func _simulate(id: String) -> void:
	var d: Dictionary = Offers.PRODUCTS[id]
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	UIKit.dim_background(root, 0.85)
	var panel := UIKit.center_panel(root, Vector2(320, 120))
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	v.add_child(UIKit.label("COMPRA DE TESTE", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%s — %s" % [tr(d.name), price_text(id)], 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("(simulada: nenhuma loja ligada, nada é cobrado)", 8, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var ok := UIKit.button("CONFIRMAR", "GoldButton", 0, "check")
	ok.pressed.connect(func():
		layer.queue_free()
		grant(id))
	h.add_child(ok)
	var no := UIKit.button("CANCELAR", "", 0, "back")
	no.pressed.connect(func():
		layer.queue_free()
		_fail(id, "cancelada"))
	h.add_child(no)
