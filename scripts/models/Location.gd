class_name Location
extends RefCounted

var code: String
var name_key: String
var info_key: String
var position: Vector2
var stock: Dictionary
var demand: Dictionary
var prices: Dictionary = {}

func _init(
		p_code: String,
		p_name_key: String,
		p_info_key: String,
		p_position: Vector2,
		p_stock: Dictionary,
		p_demand: Dictionary = {}
		) -> void:
	code = p_code
	name_key = p_name_key
	info_key = p_info_key
	position = p_position
	stock = p_stock
	demand = p_demand

func get_name() -> String:
	return tr(name_key)

func get_info() -> String:
	return tr(info_key)

func update_prices(base_prices: Dictionary) -> void:
	# Deterministic pricing only: base + additive modifier derived from demand multiplier.
	# No dependence on current stock or randomness.
	for g in base_prices.keys():
		var base: int = int(base_prices.get(g, 0))
		var dmul: float = float(demand.get(g, 1.0))
		var add: int = int(round(base * (dmul - 1.0)))
		prices[g] = base + add

func goods_for_view(base_prices: Dictionary, goods_names: Dictionary) -> Dictionary:
	var goods := {}
	for g in stock.keys():
		var qty: int = stock[g]
		var p: int = prices.get(g, int(round(base_prices.get(g, 0) * demand.get(g, 1.0))))
		goods[goods_names.get(g, str(g))] = {"qty": int(qty), "price": int(p)}
	return goods

func _good_id(g: Variant) -> int:
	if typeof(g) == TYPE_INT:
		return int(g)
	if typeof(g) == TYPE_STRING:
		var s: String = str(g)
		var s_up := s.to_upper()
		# Build reverse map from DB.goods_names
		for id in DB.goods_names.keys():
			var name_low: String = str(DB.goods_names.get(id, ""))
			if s_up == name_low.to_upper():
				return int(id)
		# Also allow already-uppercase codes like "FOOD"
		match s_up:
			"FOOD": return int(DB.Good.FOOD)
			"MEDS": return int(DB.Good.MEDS)
			"ORE": return int(DB.Good.ORE)
			"TOOLS": return int(DB.Good.TOOLS)
			"LUX": return int(DB.Good.LUX)
	return -1

func has_good(good: Variant) -> bool:
	var id := _good_id(good)
	if id == -1:
		return false
	if stock.has(id):
		return true
	var code_up := str(DB.goods_names.get(id, id)).to_upper()
	return stock.has(code_up) or stock.has(code_up.to_lower())

func get_stock(good: Variant) -> int:
	var id := _good_id(good)
	if id == -1:
		return 0
	if stock.has(id):
		return int(stock.get(id))
	var code_low := str(DB.goods_names.get(id, id))
	var code_up := code_low.to_upper()
	if stock.has(code_up):
		return int(stock.get(code_up))
	if stock.has(code_low):
		return int(stock.get(code_low))
	return 0

func list_goods() -> Array:
	# Expose all known goods so locations can buy from or accept sales of any item,
	# not only those currently in stock.
	var goods: Array = []
	if typeof(DB) == TYPE_OBJECT and DB.goods_base_price is Dictionary:
		goods = DB.goods_base_price.keys()
		goods.sort()
	return goods

func get_price(good: Variant) -> int:
	var id := _good_id(good)
	if id == -1:
		return 0
	# Query DB's deterministic price function
	return int(DB.price_of(code, id))
