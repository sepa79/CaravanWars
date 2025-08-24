extends Node

# -----------------------------
# Goods
# -----------------------------
enum Good { FOOD, MEDS, ORE, TOOLS, LUX }

var goods_base_price: Dictionary = {
	Good.FOOD: 10,
	Good.MEDS: 16,
	Good.ORE:  20,
	Good.TOOLS:18,
	Good.LUX:  40
}

var goods_names: Dictionary = {
	Good.FOOD: "food",
	Good.MEDS: "meds",
	Good.ORE:  "ore",
	Good.TOOLS:"tools",
	Good.LUX:  "lux"
}

# -----------------------------
# Locations: EN codes + i18n names
# Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE
# -----------------------------
var current_language: String = "pl" # default UI language (PL/EN)

var loc_display: Dictionary = {
	"HARBOR":         {"en": "Harbor",          "pl": "Port"},
	"CENTRAL_KEEP":   {"en": "Central Keep",    "pl": "Twierdza Środkowa"},
	"SOUTHERN_SHRINE":{"en": "Southern Shrine", "pl": "Świątynia Południowa"},
	"FOREST_SPRING":  {"en": "Forest Spring",   "pl": "Źródło Leśne"},
	"MILLS":          {"en": "Mills",           "pl": "Młyny"},
	"FOREST_HAVEN":   {"en": "Forest Haven",    "pl": "Leśna Przystań"},
	"MINE":           {"en": "Mine",            "pl": "Kopalnia"}
}

# Map positions (codes -> image coords)
var positions: Dictionary = {
	"HARBOR":        Vector2(1230, 900),
	"CENTRAL_KEEP":  Vector2(1000, 750),
	"SOUTHERN_SHRINE": Vector2(400, 800),
	"FOREST_SPRING": Vector2(735, 450),
	"MILLS":         Vector2(1140, 110),
	"FOREST_HAVEN":  Vector2(990, 310),
	"MINE":          Vector2(490, 300)
}

# Routes (A->B using codes)
var routes: Dictionary = {
	"CENTRAL_KEEP->FOREST_HAVEN": {"risk": 0.00, "ticks": 2},
	"FOREST_HAVEN->CENTRAL_KEEP": {"risk": 0.00, "ticks": 2},

	"FOREST_SPRING->MINE": {"risk": 0.00, "ticks": 2},
	"MINE->FOREST_SPRING": {"risk": 0.00, "ticks": 2},

	"HARBOR->CENTRAL_KEEP": {"risk": 0.05, "ticks": 3},
	"CENTRAL_KEEP->HARBOR": {"risk": 0.05, "ticks": 3},

	"HARBOR->FOREST_HAVEN": {"risk": 0.05, "ticks": 3},
	"FOREST_HAVEN->HARBOR": {"risk": 0.05, "ticks": 3},

	"CENTRAL_KEEP->FOREST_SPRING": {"risk": 0.05, "ticks": 3},
	"FOREST_SPRING->CENTRAL_KEEP": {"risk": 0.05, "ticks": 3},

	"FOREST_SPRING->FOREST_HAVEN": {"risk": 0.05, "ticks": 2},
	"FOREST_HAVEN->FOREST_SPRING": {"risk": 0.05, "ticks": 2},

	"CENTRAL_KEEP->SOUTHERN_SHRINE": {"risk": 0.07, "ticks": 3},
	"SOUTHERN_SHRINE->CENTRAL_KEEP": {"risk": 0.07, "ticks": 3},

	"HARBOR->SOUTHERN_SHRINE": {"risk": 0.07, "ticks": 4},
	"SOUTHERN_SHRINE->HARBOR": {"risk": 0.07, "ticks": 4},

	"MILLS->FOREST_HAVEN": {"risk": 0.06, "ticks": 3},
	"FOREST_HAVEN->MILLS": {"risk": 0.06, "ticks": 3},

	"FOREST_SPRING->MILLS": {"risk": 0.06, "ticks": 3},
	"MILLS->FOREST_SPRING": {"risk": 0.06, "ticks": 3}
}

# Market per location (by codes)
var locations: Dictionary = {
	"CENTRAL_KEEP":  { "stock": {Good.FOOD: 30, Good.MEDS: 10}, "demand": {Good.FOOD: 1.0, Good.MEDS: 1.1, Good.TOOLS: 1.2} },
	"MINE":          { "stock": {Good.ORE: 60},                  "demand": {Good.FOOD: 1.1, Good.TOOLS: 1.2} },
	"HARBOR":        { "stock": {Good.LUX: 6},                   "demand": {Good.FOOD: 1.2, Good.MEDS: 1.1, Good.ORE: 1.3, Good.TOOLS: 1.2} },
	"MILLS":         { "stock": {Good.FOOD: 40},                 "demand": {Good.MEDS: 1.2, Good.TOOLS: 1.1} },
	"FOREST_HAVEN":  { "stock": {Good.TOOLS: 8},                 "demand": {Good.FOOD: 1.1, Good.MEDS: 1.2} },
	"FOREST_SPRING": { "stock": {Good.FOOD: 10},                 "demand": {Good.TOOLS: 1.1} },
	"SOUTHERN_SHRINE":{ "stock": {Good.MEDS: 20},                "demand": {Good.FOOD: 1.2, Good.TOOLS: 1.3} }
}

# Units
var unit_defs: Dictionary = {
	"hand_cart": { "name":"Hand Cart",  "speed":1.0, "capacity":10, "upkeep_gold":0, "upkeep_food":1 },
	"horse_cart":{ "name":"Horse Cart", "speed":2.0, "capacity":25, "upkeep_gold":1, "upkeep_food":2 },
	"guard":     { "name":"Guard",      "speed":1.0, "capacity":0,  "upkeep_gold":1, "upkeep_food":1, "power":2 }
}

# -----------------------------
# Helpers
# -----------------------------
func set_language(lang: String) -> void:
	if lang == "pl" or lang == "en":
		current_language = lang

func get_loc_name(code: String) -> String:
	if not loc_display.has(code):
		return code
	var names: Dictionary = loc_display[code]
	return String(names.get(current_language, code))

func route_key(a: String, b: String) -> String:
	return "%s->%s" % [a, b]

func get_pos(code: String) -> Vector2:
	if positions.has(code):
		return positions[code]
	return Vector2.ZERO

func has_route(a: String, b: String) -> bool:
	return routes.has(route_key(a, b))

func get_route(a: String, b: String) -> Dictionary:
	return routes.get(route_key(a, b), {})
