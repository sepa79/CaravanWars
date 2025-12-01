extends RefCounted
class_name BaseHeightGenerator

const DEFAULT_HEIGHT: float = 0.5
const BASE_HEIGHT_NOISE_AMPLITUDE: float = 0.0
const BASE_HEIGHT_NOISE_FREQUENCY: float = 0.0

func generate(width: int, height: int, _rng_state: int, _config: HexMapConfig) -> Dictionary:
    var heights: Dictionary = {}
    for r in range(height):
        for q in range(width):
            var t: float = 0.0
            if height > 1:
                t = float(r) / float(height - 1)
            var height_value: float = clampf(0.2 + 0.6 * t, 0.0, 1.0)
            heights[Vector2i(q, r)] = height_value
    return heights
