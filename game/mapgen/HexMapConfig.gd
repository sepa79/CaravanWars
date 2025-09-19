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
const DEFAULT_COASTLINE_SIDES_MIN := 1
const DEFAULT_COASTLINE_SIDES_MAX := 2
const DEFAULT_COASTLINE_DEPTH_MIN := 1
const DEFAULT_COASTLINE_DEPTH_MAX := 3
const DEFAULT_SIDE_BORDER_WIDTH := 2
const DEFAULT_SIDE_JITTER := 0.3
const DEFAULT_RIDGE_PASS_WIDTH := 2
const DEFAULT_EXTRA_MOUNTAIN_SPACING := 4

const SIDE_TYPE_PLAINS := "plains"
const SIDE_TYPE_SEA := "sea"
const SIDE_TYPE_MOUNTAINS := "mountains"

const SIDE_COUNT := 6

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
    p_fort_spacing: int = DEFAULT_FORT_SPACING,
    p_coastline_sides_min: int = DEFAULT_COASTLINE_SIDES_MIN,
    p_coastline_sides_max: int = DEFAULT_COASTLINE_SIDES_MAX,
    p_coastline_depth_min: int = DEFAULT_COASTLINE_DEPTH_MIN,
    p_coastline_depth_max: int = DEFAULT_COASTLINE_DEPTH_MAX,
    p_side_modes: Array[String] = [],
    p_side_widths: Array[int] = [],
    p_side_jitter: float = DEFAULT_SIDE_JITTER,
    p_ridge_pass_width: int = DEFAULT_RIDGE_PASS_WIDTH,
    p_extra_mountain_spacing: int = DEFAULT_EXTRA_MOUNTAIN_SPACING
) -> void:
    map_seed = p_seed if p_seed != 0 else Time.get_ticks_msec()
    map_radius = max(1, p_map_radius)
    kingdom_count = max(1, p_kingdom_count)
    sea_pct = clampf(p_sea_pct, 0.0, 1.0)
    mountains_pct = clampf(p_mountains_pct, 0.0, 1.0)
    lakes_pct = clampf(p_lakes_pct, 0.0, 1.0)
    rivers_cap = max(0, p_rivers_cap)
    road_aggressiveness = clampf(p_road_aggressiveness, 0.0, 1.0)
    fort_global_cap = max(0, p_fort_global_cap)
    fort_spacing = max(1, p_fort_spacing)
    coastline_sides_min = clampi(p_coastline_sides_min, 0, HexGrid.AXIAL_DIRECTIONS.size())
    coastline_sides_max = clampi(p_coastline_sides_max, coastline_sides_min, HexGrid.AXIAL_DIRECTIONS.size())
    coastline_depth_min = max(0, p_coastline_depth_min)
    coastline_depth_max = max(coastline_depth_min, p_coastline_depth_max)
    side_modes = _normalize_side_modes(p_side_modes)
    side_widths = _normalize_side_widths(p_side_widths)
    side_jitter = clampf(p_side_jitter, 0.0, 1.0)
    ridge_pass_width = max(1, p_ridge_pass_width)
    extra_mountain_spacing = max(1, p_extra_mountain_spacing)

func duplicate_config() -> HexMapConfig:
    var script: Script = get_script()
    var clone: HexMapConfig = script.new(
        map_seed,
        map_radius,
        kingdom_count,
        sea_pct,
        mountains_pct,
        lakes_pct,
        rivers_cap,
        road_aggressiveness,
        fort_global_cap,
        fort_spacing,
        coastline_sides_min,
        coastline_sides_max,
        coastline_depth_min,
        coastline_depth_max,
        side_modes.duplicate(),
        side_widths.duplicate(),
        side_jitter,
        ridge_pass_width,
        extra_mountain_spacing
    )
    return clone

func to_dictionary() -> Dictionary:
    return {
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
    }

func _normalize_side_modes(p_modes: Array[String]) -> Array[String]:
    var normalized: Array[String] = []
    var allowed: Array[String] = [SIDE_TYPE_PLAINS, SIDE_TYPE_SEA, SIDE_TYPE_MOUNTAINS]
    normalized.resize(SIDE_COUNT)
    for i in range(SIDE_COUNT):
        var choice: String = SIDE_TYPE_PLAINS
        if i < p_modes.size():
            var value: String = String(p_modes[i])
            var lowered: String = value.to_lower()
            if allowed.has(lowered):
                choice = lowered
        normalized[i] = choice
    return normalized

func _normalize_side_widths(p_widths: Array[int]) -> Array[int]:
    var normalized: Array[int] = []
    normalized.resize(SIDE_COUNT)
    for i in range(SIDE_COUNT):
        var width: int = DEFAULT_SIDE_BORDER_WIDTH
        if i < p_widths.size():
            width = max(0, int(p_widths[i]))
        normalized[i] = width
    return normalized
