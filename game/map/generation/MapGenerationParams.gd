extends RefCounted
class_name MapGenerationParams

const DEFAULT_CITY_MIN_DISTANCE := 40.0
const DEFAULT_VILLAGE_MIN_DISTANCE := 18.0

var rng_seed: int
var map_size: int
var kingdom_count: int
var sea_level: float
var terrain_octaves: int
var terrain_roughness: float
var mountain_scale: float
var erosion_strength: float
var river_min_accum: float
var river_source_alt_thresh: float
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var city_min_distance: float
var village_min_distance: float

func _init(
    p_rng_seed: int = 12345,
    p_map_size: int = 256,
    p_kingdom_count: int = 3,
    p_sea_level: float = 0.32,
    p_terrain_octaves: int = 6,
    p_terrain_roughness: float = 0.5,
    p_mountain_scale: float = 0.8,
    p_erosion_strength: float = 0.1,
    p_river_min_accum: float = 32.0,
    p_river_source_alt_thresh: float = 0.55,
    p_road_aggressiveness: float = 0.25,
    p_fort_global_cap: int = 24,
    p_fort_spacing: int = 150,
    p_city_min_distance: float = DEFAULT_CITY_MIN_DISTANCE,
    p_village_min_distance: float = DEFAULT_VILLAGE_MIN_DISTANCE
) -> void:
    rng_seed = p_rng_seed
    map_size = max(64, p_map_size)
    kingdom_count = max(1, p_kingdom_count)
    sea_level = clamp(p_sea_level, 0.05, 0.95)
    terrain_octaves = int(clamp(p_terrain_octaves, 1, 8))
    terrain_roughness = clamp(p_terrain_roughness, 0.0, 1.0)
    mountain_scale = clamp(p_mountain_scale, 0.0, 1.5)
    erosion_strength = clamp(p_erosion_strength, 0.0, 1.0)
    river_min_accum = max(1.0, p_river_min_accum)
    river_source_alt_thresh = clamp(p_river_source_alt_thresh, 0.3, 0.9)
    road_aggressiveness = clamp(p_road_aggressiveness, 0.0, 1.0)
    fort_global_cap = max(0, p_fort_global_cap)
    fort_spacing = max(10, p_fort_spacing)
    city_min_distance = max(8.0, p_city_min_distance)
    village_min_distance = max(4.0, p_village_min_distance)
