extends RefCounted
class_name HexMapData

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
var hex_grid: HexGrid
var stage_results: Dictionary = {}

func _init(p_config: HexMapConfig) -> void:
    map_seed = p_config.map_seed
    map_radius = p_config.map_radius
    kingdom_count = p_config.kingdom_count
    rivers_cap = p_config.rivers_cap
    road_aggressiveness = p_config.road_aggressiveness
    fort_global_cap = p_config.fort_global_cap
    fort_spacing = p_config.fort_spacing
    edge_settings = p_config.get_all_edge_settings()
    edge_jitter = p_config.edge_jitter
    random_feature_density = p_config.random_feature_density
    stage_results = {}

func attach_grid(p_grid: HexGrid) -> void:
    hex_grid = p_grid

func set_stage_result(phase: StringName, data: Variant) -> void:
    stage_results[phase] = data

func get_stage_result(phase: StringName) -> Variant:
    return stage_results.get(phase)

func clear_stage_results() -> void:
    stage_results.clear()

func to_dictionary() -> Dictionary:
    var result: Dictionary = {
        "meta": {
            "seed": map_seed,
            "map_radius": map_radius,
            "kingdom_count": kingdom_count,
                "params": {
                "rivers_cap": rivers_cap,
                "road_aggressiveness": road_aggressiveness,
                "fort_global_cap": fort_global_cap,
                "fort_spacing": fort_spacing,
                "edge_settings": edge_settings,
                "edge_jitter": edge_jitter,
                "random_feature_density": random_feature_density,
            },
        },
        "hexes": [],
        "edges": [],
        "points": [],
        "labels": {},
        "terrain": {},
    }
    var terrain: Variant = stage_results.get(StringName("terrain"))
    if typeof(terrain) == TYPE_DICTIONARY:
        var hex_entries: Dictionary = terrain.get("hexes", {})
        var hex_array: Array[Dictionary] = []
        for key in hex_entries.keys():
            var info: Dictionary = hex_entries[key]
            var entry := {
                "coord": info.get("coord", key),
                "region": info.get("region", ""),
                "is_water": info.get("is_water", false),
                "is_sea": info.get("is_sea", false),
                "elev": info.get("elev", 0.0),
                "river_mask": info.get("river_mask", 0),
                "river_class": info.get("river_class", 0),
                "is_mouth": info.get("is_mouth", false),
            }
            hex_array.append(entry)
        result["hexes"] = hex_array
        var terrain_meta: Dictionary = {}
        if terrain.has("regions"):
            terrain_meta["regions"] = terrain["regions"]
        if terrain.has("validation"):
            terrain_meta["validation"] = terrain["validation"]
        if terrain_meta.size() > 0:
            result["terrain"] = terrain_meta
    return result
