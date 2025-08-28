extends Node
# Jeden narrator per miasto (produkcja/popyt + kara za brak FOOD)

var code: String = ""
var min_food: int = 5
var produce: Dictionary = {}   # { String -> int }
var consume: Dictionary = {}   # { String -> int }

var _loc: Variant = null       # obiekt Location (z DB)
var _loop: Variant = null      # /root/LoopbackServer

func _srv() -> Variant:
	return get_node_or_null("/root/Server")

func _log(msg:String) -> void:
	print("[MayorNarrator] ", msg)
	var s = _srv()
	if s != null:
		s.call_deferred("broadcast_log", msg)

func setup(p_code: String, p_loc: Variant, p_loop: Variant, p_prod: Dictionary, p_cons: Dictionary, p_min_food: int = 5) -> void:
	code = p_code
	_loc = p_loc
	_loop = p_loop
	produce = (p_prod.duplicate() as Dictionary)
	consume = (p_cons.duplicate() as Dictionary)
	min_food = p_min_food
	_log("setup city=" + code + ", min_food=" + str(min_food) + ", produce=" + str(produce) + ", consume=" + str(consume))

func _food_amount() -> int:
	var stock: Dictionary = (_loc.get("stock") as Dictionary)
	return int(stock.get("FOOD", 0))

func _apply_shortage_multiplier(base_amount: int) -> int:
	var f: int = _food_amount()
	if f <= 0:
		return int(floor(base_amount * 0.25))
	elif f < min_food:
		return int(floor(base_amount * 0.5))
	return base_amount

func process_tick() -> bool:
	if _loc == null:
		return false

	var changed: bool = false
	var stock: Dictionary = (_loc.get("stock") as Dictionary)
	var before := stock.duplicate(true)

	# Konsumpcja
	var cons_keys: Array = consume.keys()
	for key in cons_keys:
		var g: String = String(key)
		var need: int = int(consume[g])
		if need > 0:
			var have: int = int(stock.get(g, 0))
			var used: int = (have if have < need else need)
			if used > 0:
				stock[g] = have - used
				changed = true
				_log("[" + code + "] consume " + g + " used=" + str(used) + " (have=" + str(have) + ", need=" + str(need) + ")")

	# Produkcja (z karą poza FOOD)
	var prod_keys: Array = produce.keys()
	for key in prod_keys:
		var g2: String = String(key)
		var amt: int = int(produce[g2])
		if amt > 0:
			if g2 != "FOOD":
				amt = _apply_shortage_multiplier(amt)
			var cur: int = int(stock.get(g2, 0))
			stock[g2] = cur + amt
			changed = true
			_log("[" + code + "] produce " + g2 + " amount=" + str(amt) + " (cur=" + str(cur) + ")")

	if changed and _loop != null:
		var payload: Dictionary = {"city": code, "stock": stock.duplicate()}
		_loop.publish("market/stock_changed", payload)
		_loop.publish("market/stock_changed/%s" % code, payload)
		_log("[" + code + "] stock changed: before=" + str(before) + " after=" + str(stock))

	return changed
