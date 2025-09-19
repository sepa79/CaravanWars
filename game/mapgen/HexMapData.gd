extends RefCounted
class_name HexMapData

var map_seed: int
var map_radius: int
var kingdom_count: int
var sea_pct: float
var mountains_pct: float
var lakes_pct: float
var rivers_cap: int
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var coastline_sides_min: int
var coastline_sides_max: int
var coastline_depth_min: int
var coastline_depth_max: int
var side_modes: Array[String]
var side_widths: Array[int]
var side_jitter: float
var ridge_pass_width: int
var extra_mountain_spacing: int
var hex_grid: HexGrid
var stage_results: Dictionary = {}

func _init(p_config: HexMapConfig) -> void:
    map_seed = p_config.map_seed
    map_radius = p_config.map_radius
    kingdom_count = p_config.kingdom_count
    sea_pct = p_config.sea_pct
    mountains_pct = p_config.mountains_pct
    lakes_pct = p_config.lakes_pct
    rivers_cap = p_config.rivers_cap
    road_aggressiveness = p_config.road_aggressiveness
    fort_global_cap = p_config.fort_global_cap
    fort_spacing = p_config.fort_spacing
    coastline_sides_min = p_config.coastline_sides_min
    coastline_sides_max = p_config.coastline_sides_max
    coastline_depth_min = p_config.coastline_depth_min
    coastline_depth_max = p_config.coastline_depth_max
    side_modes = p_config.side_modes.duplicate()
    side_widths = p_config.side_widths.duplicate()
    side_jitter = p_config.side_jitter
    ridge_pass_width = p_config.ridge_pass_width
    extra_mountain_spacing = p_config.extra_mountain_spacing
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
                "sea_pct": sea_pct,
                "mountains_pct": mountains_pct,
                "lakes_pct": lakes_pct,
                "rivers_cap": rivers_cap,
                "road_aggressiveness": road_aggressiveness,
                "fort_global_cap": fort_global_cap,
                "fort_spacing": fort_spacing,
                "coastline_sides_min": coastline_sides_min,
                "coastline_sides_max": coastline_sides_max,
                "coastline_depth_min": coastline_depth_min,
                "coastline_depth_max": coastline_depth_max,
                "side_modes": side_modes.duplicate(),
                "side_widths": side_widths.duplicate(),
                "side_jitter": side_jitter,
                "ridge_pass_width": ridge_pass_width,
                "extra_mountain_spacing": extra_mountain_spacing,
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
            }
            hex_array.append(entry)
        result["hexes"] = hex_array
        var terrain_meta: Dictionary = {}
        if terrain.has("regions"):
            terrain_meta["regions"] = terrain["regions"]
        if terrain.has("validation"):
            terrain_meta["validation"] = terrain["validation"]
        if terrain.has("ridge"):
            terrain_meta["ridge"] = terrain["ridge"]
        if terrain.has("coastline"):
            terrain_meta["coastline"] = terrain["coastline"]
        if terrain_meta.size() > 0:
            result["terrain"] = terrain_meta
    return result
