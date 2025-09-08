extends RefCounted
class_name RiverGenerator

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

func generate_rivers(count: int = 1) -> Array:
    var rivers: Array = []
    for i in count:
        var start = Vector2(rng.randi_range(0, 100), rng.randi_range(0, 100))
        var end = Vector2(rng.randi_range(0, 100), rng.randi_range(0, 100))
        rivers.append([start, end])
    return rivers
