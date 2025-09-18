extends RefCounted
class_name HexMapConfig

const DEFAULT_MAP_RADIUS := 24
const DEFAULT_KINGDOM_COUNT := 3
const DEFAULT_SEA_PCT := 0.25
const DEFAULT_MOUNTAINS_PCT := 0.15
const DEFAULT_LAKES_PCT := 0.05
const DEFAULT_RIVERS_CAP := 6
const DEFAULT_ROAD_AGGRESSIVENESS := 0.5
const DEFAULT_FORT_GLOBAL_CAP := 6
const DEFAULT_FORT_SPACING := 4

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

func _init(
    p_seed: int = 0,
    p_map_radius: int = DEFAULT_MAP_RADIUS,
    p_kingdom_count: int = DEFAULT_KINGDOM_COUNT,
    p_sea_pct: float = DEFAULT_SEA_PCT,
    p_mountains_pct: float = DEFAULT_MOUNTAINS_PCT,
    p_lakes_pct: float = DEFAULT_LAKES_PCT,
    p_rivers_cap: int = DEFAULT_RIVERS_CAP,
    p_road_aggressiveness: float = DEFAULT_ROAD_AGGRESSIVENESS,
    p_fort_global_cap: int = DEFAULT_FORT_GLOBAL_CAP,
    p_fort_spacing: int = DEFAULT_FORT_SPACING
) -> void:
    seed = p_seed if p_seed != 0 else Time.get_ticks_msec()
    map_radius = max(1, p_map_radius)
    kingdom_count = max(1, p_kingdom_count)
    sea_pct = clampf(p_sea_pct, 0.0, 1.0)
    mountains_pct = clampf(p_mountains_pct, 0.0, 1.0)
    lakes_pct = clampf(p_lakes_pct, 0.0, 1.0)
    rivers_cap = max(0, p_rivers_cap)
    road_aggressiveness = clampf(p_road_aggressiveness, 0.0, 1.0)
    fort_global_cap = max(0, p_fort_global_cap)
    fort_spacing = max(1, p_fort_spacing)

func duplicate_config() -> HexMapConfig:
    return HexMapConfig.new(
        seed,
        map_radius,
        kingdom_count,
        sea_pct,
        mountains_pct,
        lakes_pct,
        rivers_cap,
        road_aggressiveness,
        fort_global_cap,
        fort_spacing
    )

func to_dictionary() -> Dictionary:
    return {
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
    }
