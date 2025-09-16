extends RefCounted
class_name MapGenCityPlacer

var rng: RandomNumberGenerator
var map_width: float = 150.0
var map_height: float = 150.0
var border_margin: float = 30.0

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

func place_cities(
    count: int = 3,
    min_distance: float = 20.0,
    max_distance: float = 40.0,
    width: float = 150.0,
    height: float = 150.0,
    p_border_margin: float = 30.0
) -> Array[Vector2]:
    map_width = width
    map_height = height
    border_margin = p_border_margin
    var result: Array[Vector2] = []
    return result

func select_city_sites(field: Array, cities_target: int, min_distance: float, p_border_margin: float = 30.0) -> Dictionary:
    border_margin = p_border_margin
    var result: Dictionary = {
        "cities": [] as Array[Vector2],
        "capitals": [] as Array[int],
        "leftovers": [] as Array[Vector2],
    }
    return result
