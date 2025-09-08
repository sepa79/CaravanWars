extends RefCounted
class_name RoadNetwork

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

func build_roads(cities: Array) -> Array:
    var roads: Array = []
    for i in range(cities.size() - 1):
        roads.append([cities[i], cities[i + 1]])
    return roads
