extends RefCounted
class_name HexMapConfig

const DEFAULT_MAP_RADIUS := 24
const DEFAULT_KINGDOM_COUNT := 3
const DEFAULT_RIVERS_CAP := 6
const DEFAULT_ROAD_AGGRESSIVENESS := 0.5
const DEFAULT_FORT_GLOBAL_CAP := 6
const DEFAULT_FORT_SPACING := 4
const DEFAULT_EDGE_JITTER := 0
const DEFAULT_RANDOM_FEATURE_DENSITY := 0.0

const EDGE_NAMES: Array[String] = [
    "east",
    "north_east",
    "north_west",
    "west",
    "south_west",
    "south_east",
]

const EDGE_TERRAIN_TYPES: Array[String] = [
    "plains",
    "hills",
    "mountains",
    "sea",
    "lake",
]

const DEFAULT_EDGE_TYPE := "plains"
const DEFAULT_EDGE_WIDTH := 0

var map_seed: int
var map_radius: int
var kingdom_count: int
var rivers_cap: int
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var edge_settings: Dictionary = {}
var edge_jitter: int
var random_feature_density: float

func _init(
    p_seed: int = 0,
    p_map_radius: int = DEFAULT_MAP_RADIUS,
    p_kingdom_count: int = DEFAULT_KINGDOM_COUNT,
    p_rivers_cap: int = DEFAULT_RIVERS_CAP,
    p_road_aggressiveness: float = DEFAULT_ROAD_AGGRESSIVENESS,
    p_fort_global_cap: int = DEFAULT_FORT_GLOBAL_CAP,
    p_fort_spacing: int = DEFAULT_FORT_SPACING,
    p_edge_settings: Dictionary = {},
    p_edge_jitter: int = DEFAULT_EDGE_JITTER,
    p_random_feature_density: float = DEFAULT_RANDOM_FEATURE_DENSITY
) -> void:
    map_seed = p_seed if p_seed != 0 else Time.get_ticks_msec()
    map_radius = max(1, p_map_radius)
    kingdom_count = max(1, p_kingdom_count)
    rivers_cap = max(0, p_rivers_cap)
    road_aggressiveness = clampf(p_road_aggressiveness, 0.0, 1.0)
    fort_global_cap = max(0, p_fort_global_cap)
    fort_spacing = max(1, p_fort_spacing)
    edge_settings = _sanitize_edge_settings(p_edge_settings)
    edge_jitter = max(0, p_edge_jitter)
    random_feature_density = clampf(p_random_feature_density, 0.0, 1.0)

func duplicate_config() -> HexMapConfig:
    var script: Script = get_script()
    var clone: HexMapConfig = script.new(
        map_seed,
        map_radius,
        kingdom_count,
        rivers_cap,
        road_aggressiveness,
        fort_global_cap,
        fort_spacing,
        edge_settings,
        edge_jitter,
        random_feature_density
    )
    return clone

func to_dictionary() -> Dictionary:
    return {
        "seed": map_seed,
        "map_radius": map_radius,
        "kingdom_count": kingdom_count,
        "params": {
            "rivers_cap": rivers_cap,
            "road_aggressiveness": road_aggressiveness,
            "fort_global_cap": fort_global_cap,
            "fort_spacing": fort_spacing,
            "edge_settings": _sanitize_edge_settings(edge_settings),
            "edge_jitter": edge_jitter,
            "random_feature_density": random_feature_density,
        },
    }

func get_edge_setting(edge_name: String) -> Dictionary:
    var sanitized := _sanitize_edge_settings(edge_settings)
    return sanitized.get(edge_name, {
        "type": DEFAULT_EDGE_TYPE,
        "width": DEFAULT_EDGE_WIDTH,
    })

func get_all_edge_settings() -> Dictionary:
    return _sanitize_edge_settings(edge_settings)

func set_edge_setting(edge_name: String, terrain_type: String, width: int) -> void:
    var chosen_edge := edge_name
    if not EDGE_NAMES.has(chosen_edge):
        return
    var chosen_type := terrain_type if EDGE_TERRAIN_TYPES.has(terrain_type) else DEFAULT_EDGE_TYPE
    var sanitized_width: int = max(0, width)
    edge_settings[chosen_edge] = {
        "type": chosen_type,
        "width": sanitized_width,
    }

func _sanitize_edge_settings(source: Dictionary) -> Dictionary:
    var sanitized: Dictionary = {}
    for edge_name in EDGE_NAMES:
        var entry: Dictionary = {}
        if typeof(source.get(edge_name)) == TYPE_DICTIONARY:
            entry = source[edge_name]
        var terrain_type := String(entry.get("type", DEFAULT_EDGE_TYPE))
        if not EDGE_TERRAIN_TYPES.has(terrain_type):
            terrain_type = DEFAULT_EDGE_TYPE
        var width_value := int(entry.get("width", DEFAULT_EDGE_WIDTH))
        sanitized[edge_name] = {
            "type": terrain_type,
            "width": max(0, width_value),
        }
    return sanitized
