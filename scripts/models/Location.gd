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
	for g in base_prices.keys():
		var base: int = base_prices[g]
		var s: float = float(stock.get(g, 0))
		var d: float = float(demand.get(g, 1.0))
		var factor: float = clamp(d * (1.5 - min(s, 100.0) / 200.0), 0.5, 2.0)
		prices[g] = int(round(base * factor))

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
        var s: String = String(g)
        var s_up := s.to_upper()
        # Build reverse map from DB.goods_names
        for id in DB.goods_names.keys():
            var name_low: String = String(DB.goods_names[id])
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
    var code_up := String(DB.goods_names.get(id, str(id))).to_upper()
    return stock.has(code_up) or stock.has(code_up.to_lower())

func get_stock(good: Variant) -> int:
    var id := _good_id(good)
    if id == -1:
        return 0
    if stock.has(id):
        return int(stock.get(id))
    var code_low := String(DB.goods_names.get(id, str(id)))
    var code_up := code_low.to_upper()
    if stock.has(code_up):
        return int(stock.get(code_up))
    if stock.has(code_low):
        return int(stock.get(code_low))
    return 0

func list_goods() -> Array:
    var seen := {}
    var goods: Array = []
    for k in stock.keys():
        var id := _good_id(k)
        if id != -1 and not seen.has(id):
            seen[id] = true
            goods.append(id)
    return goods

func get_price(good: Variant) -> int:
    var id := _good_id(good)
    if id == -1:
        return 0
    # Use precomputed dynamic price; fallback to base * demand
    var base:int = int(DB.goods_base_price.get(id, 0)) if typeof(DB) == TYPE_OBJECT else 0
    var dem:float = float(demand.get(id, 1.0))
    return int(prices.get(id, int(round(base * dem))))
