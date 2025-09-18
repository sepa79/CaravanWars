extends RefCounted
class_name HexMapData

var seed: int
var map_radius: int
var kingdom_count: int
var sea_pct: float
var mountains_pct: float
var lakes_pct: float
var rivers_cap: int
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var hex_grid: HexGrid
var stage_results: Dictionary = {}

func _init(p_config: HexMapConfig) -> void:
    seed = p_config.seed
    map_radius = p_config.map_radius
    kingdom_count = p_config.kingdom_count
    sea_pct = p_config.sea_pct
    mountains_pct = p_config.mountains_pct
    lakes_pct = p_config.lakes_pct
    rivers_cap = p_config.rivers_cap
    road_aggressiveness = p_config.road_aggressiveness
    fort_global_cap = p_config.fort_global_cap
    fort_spacing = p_config.fort_spacing
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
    return {
        "meta": {
            "seed": seed,
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
            },
        },
        "hexes": [],
        "edges": [],
        "points": [],
        "labels": {},
    }
