extends RefCounted
class_name MapGenStub

class MapGenParams:
    var rng_seed: int
    var width: float
    var height: float

    func _init(p_rng_seed: int = 0, p_width: float = 150.0, p_height: float = 150.0) -> void:
        rng_seed = p_rng_seed if p_rng_seed != 0 else Time.get_ticks_msec()
        width = max(20.0, p_width)
        height = max(20.0, p_height)

var params: MapGenParams

func _init(p_params: MapGenParams = MapGenParams.new()) -> void:
    params = p_params

func generate() -> Dictionary:
    return {
        "meta": {
            "seed": params.rng_seed,
            "width": params.width,
            "height": params.height,
        },
        "width": params.width,
        "height": params.height,
        "cities": [],
        "villages": [],
        "forts": [],
        "rivers": [],
        "roads": {},
        "regions": {},
        "kingdom_seeds": [],
        "kingdom_names": {},
        "capitals": [],
    }

static func validate_map(_roads: Dictionary, _rivers: Array) -> Array[String]:
    return []

static func export_bundle(
    _path: String,
    _map_data: Dictionary,
    _rng_seed: int,
    _version: String,
    _width: float,
    _height: float,
    _unit_scale: float = 1.0
) -> void:
    pass

static func load_bundle(_path: String) -> Dictionary:
    return {}

static func generate_regions(
    _cities: Array[Vector2],
    _kingdom_count: int,
    _width: float,
    _height: float
) -> Dictionary:
    return {}
