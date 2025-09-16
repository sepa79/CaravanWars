extends RefCounted
class_name NoiseUtil

func create_simplex(
    _rng_seed: int,
    _octaves: int = 3,
    _frequency: float = 0.05,
    _gain: float = 0.5,
    _lacunarity: float = 2.0
) -> FastNoiseLite:
    return FastNoiseLite.new()

func generate_field(_noise: FastNoiseLite, _width: int, _height: int, _step: float = 1.0) -> Array:
    return []

func compute_roughness(_field: Array) -> Array:
    return []
