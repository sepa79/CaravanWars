extends RefCounted

const MapGenerationParams := preload("res://map/generation/MapGenerationParams.gd")
const MapGenerator := preload("res://map/generation/MapGenerator.gd")

class MapGenParams:
    var rng_seed: int
    var map_size: int
    var kingdom_count: int
    var sea_level: float

    func _init(
        p_rng_seed: int = 12345,
        p_map_size: int = 256,
        p_kingdom_count: int = 3,
        p_sea_level: float = 0.32
    ) -> void:
        rng_seed = p_rng_seed
        map_size = max(64, p_map_size)
        kingdom_count = max(1, p_kingdom_count)
        sea_level = clamp(p_sea_level, 0.05, 0.95)

var _params: MapGenParams

func _init(p_params: MapGenParams = MapGenParams.new()) -> void:
    _params = p_params
    if OS.has_environment("MAP_SMOKE_TEST"):
        _params.map_size = min(_params.map_size, 256)

func generate() -> Dictionary:
    var generation_params := MapGenerationParams.new(
        _params.rng_seed,
        _params.map_size,
        _params.kingdom_count,
        _params.sea_level
    )
    if OS.has_environment("MAP_SMOKE_TEST"):
        generation_params.kingdom_count = max(1, min(generation_params.kingdom_count, 3))
    return MapGenerator.new(generation_params).generate()
