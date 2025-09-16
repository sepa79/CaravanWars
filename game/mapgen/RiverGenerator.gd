extends RefCounted
class_name MapGenRiverGenerator

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

func generate_rivers(
    roads: Dictionary = {},
    count: int = 0,
    width: float = 100.0,
    height: float = 100.0
) -> Array:
    return []

static func apply_intersections(_rivers: Array, _roads: Dictionary) -> void:
    pass
