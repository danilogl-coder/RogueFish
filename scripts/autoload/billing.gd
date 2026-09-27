extends Node
## In-app purchases (autoload "Billing").
##
##   Billing.buy("pearls_2")      # grants through Billing.grant() when paid
##
## Backends:
##  * Google Play: the official "GodotGooglePlayBilling" Android plugin
##    (godot-sdk-integrations/godot-google-play-billing). When its singleton
##    exists it is used automatically: product ids here must match the ids
##    created in the Play Console.
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
var _play = null                 ## GodotGooglePlayBilling singleton
var _pending := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_play = Engine.get_singleton("GodotGooglePlayBilling")
		_play.connect("connected", _on_play_connected)
		_play.connect("purchases_updated", _on_play_purchases)
		_play.connect("purchase_error", func(code, msg): _fail("store", str(msg)))
		_play.connect("sku_details_query_completed", _on_play_details)
		_play.startConnection()


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
		_play.purchase(id)
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


# ------------------------------------------------------------ Google Play
func _on_play_connected() -> void:
	var ids: Array = Offers.PRODUCTS.keys()
	_play.querySkuDetails(ids, "inapp")
	_play.queryPurchases("inapp")


func _on_play_details(details: Array) -> void:
	for d in details:
		if typeof(d) == TYPE_DICTIONARY and d.has("sku"):
			prices[String(d.sku)] = String(d.get("price", ""))
	prices_updated.emit()


func _on_play_purchases(list: Array) -> void:
	for p in list:
		if typeof(p) != TYPE_DICTIONARY or int(p.get("purchase_state", 0)) != 1:
			continue
		var skus: Array = p.get("skus", [p.get("sku", "")])
		var token: String = p.get("purchase_token", "")
		for sku in skus:
			var id := String(sku)
			if not Offers.PRODUCTS.has(id):
				continue
			if bool(Offers.PRODUCTS[id].consumable):
				_play.consumePurchase(token)
			elif not bool(p.get("is_acknowledged", false)):
				_play.acknowledgePurchase(token)
			grant(id)


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
	v.add_child(UIKit.label("%s — %s" % [d.name, price_text(id)], 8, UIKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
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
