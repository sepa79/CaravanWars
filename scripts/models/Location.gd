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

func has_good(good:int) -> bool:
	return stock.has(good)

func get_stock(good:int) -> int:
	return int(stock.get(good, 0))

func list_goods() -> Array:
	return stock.keys()

func get_price(good:int) -> int:
	# Use precomputed dynamic price; fallback to base * demand
	var base:int = int(DB.goods_base_price.get(good, 0)) if typeof(DB) == TYPE_OBJECT else 0
	var dem:float = float(demand.get(good, 1.0))
	return int(prices.get(good, int(round(base * dem))))
