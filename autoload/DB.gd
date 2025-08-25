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
# Locations
# Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE
# -----------------------------
var current_language: String = "pl" # default UI language (PL/EN)
const Location = preload("res://scripts/models/Location.gd")

func _ready() -> void:
        var tr = load("res://locale/translations.pl.tres")
        if tr:
                TranslationServer.add_translation(tr)
        TranslationServer.set_locale(current_language)
        for loc in locations.values():
                loc.update_prices(goods_base_price)

# Routes (A->B using codes)
var routes: Dictionary = {
        "FOREST_SPRING->MINE": {"risk": 0.00, "ticks": 2},
        "MINE->FOREST_SPRING": {"risk": 0.00, "ticks": 2},

        "HARBOR->CENTRAL_KEEP": {"risk": 0.05, "ticks": 3},
        "CENTRAL_KEEP->HARBOR": {"risk": 0.05, "ticks": 3},

        "CENTRAL_KEEP->FOREST_SPRING": {"risk": 0.05, "ticks": 3},
        "FOREST_SPRING->CENTRAL_KEEP": {"risk": 0.05, "ticks": 3},

        "FOREST_SPRING->FOREST_HAVEN": {"risk": 0.05, "ticks": 2},
        "FOREST_HAVEN->FOREST_SPRING": {"risk": 0.05, "ticks": 2},

        "CENTRAL_KEEP->SOUTHERN_SHRINE": {"risk": 0.07, "ticks": 3},
        "SOUTHERN_SHRINE->CENTRAL_KEEP": {"risk": 0.07, "ticks": 3},

        "MILLS->FOREST_HAVEN": {"risk": 0.06, "ticks": 3},
        "FOREST_HAVEN->MILLS": {"risk": 0.06, "ticks": 3}

}

# Market per location (by codes)
var locations: Dictionary = {
        "CENTRAL_KEEP": Location.new(
                "CENTRAL_KEEP",
                "Central Keep",
                "The heart of the realm and a bustling town.",
                Vector2(910, 750),
                {Good.FOOD: 30, Good.MEDS: 10},
                {Good.FOOD: 1.0, Good.MEDS: 1.1, Good.TOOLS: 1.2}
        ),
        "MINE": Location.new(
                "MINE",
                "Mine",
                "Rich veins of ore run through these tunnels.",
                Vector2(440, 340),
                {Good.ORE: 60},
                {Good.FOOD: 1.1, Good.TOOLS: 1.2}
        ),
        "HARBOR": Location.new(
                "HARBOR",
                "Harbor",
                "Ships from afar visit this busy port.",
                Vector2(1060, 840),
                {Good.LUX: 6},
                {Good.FOOD: 1.2, Good.MEDS: 1.1, Good.ORE: 1.3, Good.TOOLS: 1.2}
        ),
        "MILLS": Location.new(
                "MILLS",
                "Mills",
                "Windmills that grind grain for the region.",
                Vector2(1010, 185),
                {Good.FOOD: 40},
                {Good.MEDS: 1.2, Good.TOOLS: 1.1}
        ),
        "FOREST_HAVEN": Location.new(
                "FOREST_HAVEN",
                "Forest Haven",
                "A safe haven amid towering trees.",
                Vector2(890, 360),
                {Good.TOOLS: 8},
                {Good.FOOD: 1.1, Good.MEDS: 1.2}
        ),
        "FOREST_SPRING": Location.new(
                "FOREST_SPRING",
                "Forest Spring",
                "A spring hidden deep within the forest.",
                Vector2(690, 560),
                {Good.FOOD: 10},
                {Good.TOOLS: 1.1}
        ),
        "SOUTHERN_SHRINE": Location.new(
                "SOUTHERN_SHRINE",
                "Southern Shrine",
                "A tranquil shrine in the south.",
                Vector2(350, 840),
                {Good.MEDS: 20},
                {Good.FOOD: 1.2, Good.TOOLS: 1.3}
        )
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
                TranslationServer.set_locale(lang)

func get_loc(code: String) -> Location:
        return locations.get(code, null)

func get_loc_name(code: String) -> String:
        var loc: Location = get_loc(code)
        if loc == null:
                return code
        return loc.get_name()

func route_key(a: String, b: String) -> String:
        return "%s->%s" % [a, b]

func get_pos(code: String) -> Vector2:
        var loc: Location = get_loc(code)
        if loc:
                return loc.position
        return Vector2.ZERO

func has_route(a: String, b: String) -> bool:
        return routes.has(route_key(a, b))

func get_route(a: String, b: String) -> Dictionary:
        return routes.get(route_key(a, b), {})
