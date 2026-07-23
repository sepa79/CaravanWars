extends RefCounted
class_name HexMapConfig

const TerrainSettingsResource := preload("res://map/TerrainSettings.gd")

const DEFAULT_MAP_SEED := 12345
const DEFAULT_MAP_WIDTH := 100
const DEFAULT_MAP_HEIGHT := 100
const DEFAULT_KINGDOM_COUNT := 3
const DEFAULT_RIVERS_CAP := 6
const DEFAULT_ROAD_AGGRESSIVENESS := 0.5
const DEFAULT_FORT_GLOBAL_CAP := 6
const DEFAULT_FORT_SPACING := 4
const DEFAULT_EDGE_JITTER := 3

const EDGE_NAMES: Array[String] = [
    "north",
    "east",
    "south",
    "west",
]

const EDGE_TERRAIN_TYPES: Array[String] = [
    "sea",
    "plains",
    "hills",
    "mountains",
]

const DEFAULT_EDGE_TYPE := "plains"
const DEFAULT_EDGE_WIDTH := 0

const DEFAULT_EDGE_DEPTHS := {
    "north": 2,
    "east": 2,
    "south": 2,
    "west": 2,
}

const DEFAULT_EDGE_TERRAINS := {
    "north": "sea",
    "east": "mountains",
    "south": "plains",
    "west": "sea",
}

const FEATURE_INTENSITIES: Array[String] = [
    "none",
    "low",
    "medium",
    "high",
]

const FEATURE_MODES: Array[String] = [
    "auto",
    "peaks_only",
    "hills_only",
]

const FEATURE_FALLOFFS: Array[String] = [
    "smooth",
    "linear",
]

const DEFAULT_FEATURE_INTENSITY := "none"
const DEFAULT_FEATURE_MODE := "auto"
const DEFAULT_FEATURE_FALLOFF := "smooth"
const DEFAULT_FEATURE_COUNT_OVERRIDE := null
const DEFAULT_ROUGHNESS_SCALE: float = 1.0

var map_seed: int
var map_width: int
var map_height: int
var kingdom_count: int
var rivers_cap: int
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var edge_settings: Dictionary = {}
var edge_jitter: int
var random_feature_settings: Dictionary = {}
var terrain_settings

func _init(
    p_seed: int = DEFAULT_MAP_SEED,
    p_map_width: int = DEFAULT_MAP_WIDTH,
    p_map_height: int = DEFAULT_MAP_HEIGHT,
    p_kingdom_count: int = DEFAULT_KINGDOM_COUNT,
    p_rivers_cap: int = DEFAULT_RIVERS_CAP,
    p_road_aggressiveness: float = DEFAULT_ROAD_AGGRESSIVENESS,
    p_fort_global_cap: int = DEFAULT_FORT_GLOBAL_CAP,
    p_fort_spacing: int = DEFAULT_FORT_SPACING,
    p_edge_settings: Dictionary = {},
    p_edge_jitter: int = DEFAULT_EDGE_JITTER,
    p_random_feature_settings: Dictionary = {},
    p_terrain_settings = null
) -> void:
    map_seed = p_seed if p_seed != 0 else Time.get_ticks_msec()
    map_width = max(1, p_map_width)
    map_height = max(1, p_map_height)
    kingdom_count = max(1, p_kingdom_count)
    rivers_cap = max(0, p_rivers_cap)
    road_aggressiveness = clampf(p_road_aggressiveness, 0.0, 1.0)
    fort_global_cap = max(0, p_fort_global_cap)
    fort_spacing = max(1, p_fort_spacing)
    edge_settings = _sanitize_edge_settings(p_edge_settings)
    edge_jitter = max(0, p_edge_jitter)
    random_feature_settings = _sanitize_random_feature_settings(p_random_feature_settings)
    if p_terrain_settings == null:
        terrain_settings = TerrainSettingsResource.new()
    else:
        terrain_settings = p_terrain_settings.duplicate_settings()

func duplicate_config() -> HexMapConfig:
    var script: Script = get_script()
    var clone: HexMapConfig = script.new(
        map_seed,
        map_width,
        map_height,
        kingdom_count,
        rivers_cap,
        road_aggressiveness,
        fort_global_cap,
        fort_spacing,
        edge_settings,
        edge_jitter,
        random_feature_settings,
        terrain_settings
    )
    return clone

func to_dictionary() -> Dictionary:
    return {
        "seed": map_seed,
        "width": map_width,
        "height": map_height,
        "kingdom_count": kingdom_count,
        "params": {
            "rivers_cap": rivers_cap,
            "road_aggressiveness": road_aggressiveness,
            "fort_global_cap": fort_global_cap,
            "fort_spacing": fort_spacing,
            "edge_settings": _sanitize_edge_settings(edge_settings),
            "edge_jitter": edge_jitter,
            "random_features": _sanitize_random_feature_settings(random_feature_settings),
        },
        "terrain_settings": terrain_settings.to_dictionary(),
    }

func get_edge_setting(edge_name: String) -> Dictionary:
    var sanitized := _sanitize_edge_settings(edge_settings)
    var default_width := int(DEFAULT_EDGE_DEPTHS.get(edge_name, DEFAULT_EDGE_WIDTH))
    return sanitized.get(edge_name, {
        "type": DEFAULT_EDGE_TERRAINS.get(edge_name, DEFAULT_EDGE_TYPE),
        "width": default_width,
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

func get_random_feature_settings() -> Dictionary:
    return _sanitize_random_feature_settings(random_feature_settings)

func set_random_feature_settings(settings: Dictionary) -> void:
    random_feature_settings = _sanitize_random_feature_settings(settings)

func update_random_feature_setting(setting_name: String, value: Variant) -> void:
    var current_settings := get_random_feature_settings()
    current_settings[setting_name] = value
    random_feature_settings = _sanitize_random_feature_settings(current_settings)

func _sanitize_edge_settings(source: Dictionary) -> Dictionary:
    var sanitized: Dictionary = {}
    for edge_name in EDGE_NAMES:
        var entry: Dictionary = {}
        if typeof(source.get(edge_name)) == TYPE_DICTIONARY:
            entry = source[edge_name]
        var terrain_type := String(entry.get("type", DEFAULT_EDGE_TERRAINS.get(edge_name, DEFAULT_EDGE_TYPE)))
        if not EDGE_TERRAIN_TYPES.has(terrain_type):
            terrain_type = DEFAULT_EDGE_TERRAINS.get(edge_name, DEFAULT_EDGE_TYPE)
        var default_width := int(DEFAULT_EDGE_DEPTHS.get(edge_name, DEFAULT_EDGE_WIDTH))
        var width_value := int(entry.get("width", default_width))
        sanitized[edge_name] = {
            "type": terrain_type,
            "width": max(0, width_value),
        }
    return sanitized

func _sanitize_random_feature_settings(source: Dictionary) -> Dictionary:
    var sanitized: Dictionary = {}
    var intensity_value := String(source.get("intensity", DEFAULT_FEATURE_INTENSITY)).to_lower()
    if not FEATURE_INTENSITIES.has(intensity_value):
        intensity_value = DEFAULT_FEATURE_INTENSITY
    sanitized["intensity"] = intensity_value
    var mode_value := String(source.get("mode", DEFAULT_FEATURE_MODE)).to_lower()
    if not FEATURE_MODES.has(mode_value):
        mode_value = DEFAULT_FEATURE_MODE
    sanitized["mode"] = mode_value
    var falloff_value := String(source.get("falloff", DEFAULT_FEATURE_FALLOFF)).to_lower()
    if not FEATURE_FALLOFFS.has(falloff_value):
        falloff_value = DEFAULT_FEATURE_FALLOFF
    sanitized["falloff"] = falloff_value
    var count_value: Variant = source.get("count_override", DEFAULT_FEATURE_COUNT_OVERRIDE)
    var sanitized_count: Variant = DEFAULT_FEATURE_COUNT_OVERRIDE
    match typeof(count_value):
        TYPE_INT:
            if count_value >= 0:
                sanitized_count = count_value
        TYPE_FLOAT:
            var normalized := int(round(float(count_value)))
            if normalized >= 0:
                sanitized_count = normalized
        _:
            sanitized_count = DEFAULT_FEATURE_COUNT_OVERRIDE
    sanitized["count_override"] = sanitized_count
    var roughness_variant: Variant = source.get("roughness_scale", DEFAULT_ROUGHNESS_SCALE)
    var roughness_scale: float = DEFAULT_ROUGHNESS_SCALE
    match typeof(roughness_variant):
        TYPE_FLOAT, TYPE_INT:
            roughness_scale = clampf(float(roughness_variant), 0.25, 4.0)
        _:
            roughness_scale = DEFAULT_ROUGHNESS_SCALE
    sanitized["roughness_scale"] = roughness_scale
    return sanitized
