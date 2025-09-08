extends RefCounted
class_name CityPlacer

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

func place_cities(count: int = 3) -> Array:
    var cities: Array = []
    for i in count:
        var x = rng.randi_range(0, 100)
        var y = rng.randi_range(0, 100)
        cities.append(Vector2(x, y))
    return cities
