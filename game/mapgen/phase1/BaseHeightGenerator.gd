extends RefCounted
class_name BaseHeightGenerator

const DEFAULT_HEIGHT: float = 0.5

func generate(width: int, height: int, _rng_state: int, _config: HexMapConfig) -> Dictionary:
    var heights: Dictionary = {}
    for r in range(height):
        for q in range(width):
            heights[Vector2i(q, r)] = DEFAULT_HEIGHT
    return heights
