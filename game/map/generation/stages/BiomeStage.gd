extends RefCounted
class_name MapBiomeStage

const MapGenerationParams := preload("res://map/generation/MapGenerationParams.gd")
const MapGenerationConstants := preload("res://map/generation/MapGenerationConstants.gd")
const MapGenerationShared := preload("res://map/generation/MapGenerationShared.gd")
static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var size: int = state["map_size"]
    var total: int = size * size
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var river_distance: PackedFloat32Array = state["rivers"]["distance_map"]

    var temp_noise := FastNoiseLite.new()
    temp_noise.seed = params.rng_seed + 101
    temp_noise.frequency = 0.75 / float(size)
    temp_noise.fractal_octaves = 3

    var rain_noise := FastNoiseLite.new()
    rain_noise.seed = params.rng_seed + 303
    rain_noise.frequency = 0.5 / float(size)
    rain_noise.fractal_octaves = 4

    var temperature := PackedFloat32Array()
    temperature.resize(total)
    var rainfall := PackedFloat32Array()
    rainfall.resize(total)
    var biome_map: Array[String] = []
    biome_map.resize(total)
    var special_tags: Array[String] = []
    special_tags.resize(total)

    for y in range(size):
        var latitude: float = abs((float(y) / float(size)) - 0.5) * 2.0
        for x in range(size):
            var index: int = y * size + x
            var altitude: float = heightmap[index]
            var base_temp: float = clamp(1.0 - latitude - altitude * 0.65, 0.0, 1.0)
            var temp_variation: float = temp_noise.get_noise_2d(float(x), float(y)) * 0.1
            var temp_value: float = clamp(base_temp + temp_variation, 0.0, 1.0)
            temperature[index] = temp_value

            var rain_base: float = 0.5 + rain_noise.get_noise_2d(float(x), float(y)) * 0.25
            var river_boost: float = clamp(
                1.0 - min(river_distance[index] / float(MapGenerationConstants.RIVER_INFLUENCE_RADIUS * 2), 1.0),
                0.0,
                1.0
            )
            var slope_shadow: float = clamp(1.0 - slope_map[index] * 0.6, 0.0, 1.0)
            var rainfall_value: float = clamp(rain_base * slope_shadow + river_boost * 0.4 + (1.0 - altitude) * 0.15, 0.0, 1.0)
            rainfall[index] = rainfall_value

            var biome: String = _classify_biome(temp_value, rainfall_value, altitude, slope_map[index], sea_mask[index] == 1, params)
            biome_map[index] = biome
            var tag: String = ""
            if sea_mask[index] == 0:
                if MapGenerationShared.has_adjacent_sea(x, y, size, sea_mask):
                    tag = "coast"
                elif river_boost > 0.75:
                    tag = "delta"
            special_tags[index] = tag

    var polygons := _aggregate_biomes(biome_map, size)

    state["biome_map"] = biome_map
    state["temperature_map"] = temperature
    state["rainfall_map"] = rainfall
    state["biome_tags"] = special_tags

    return {
        "temperature_map": temperature,
        "rainfall_map": rainfall,
        "polygons": polygons,
        "biome_map": biome_map,
        "tags": special_tags,
    }

static func _classify_biome(
    temp_value: float,
    rainfall_value: float,
    altitude: float,
    slope_value: float,
    is_sea: bool,
    params: MapGenerationParams
) -> String:
    if is_sea:
        return "ocean"
    if altitude < params.sea_level + 0.015 and rainfall_value > 0.6:
        return "swamp"
    if slope_value > 0.85 or altitude > 0.85:
        return "alpine"
    if temp_value < 0.25:
        if rainfall_value < 0.3:
            return "tundra"
        return "taiga"
    if temp_value > 0.75:
        if rainfall_value < 0.25:
            return "desert"
        if rainfall_value > 0.7:
            return "tropical_forest"
        return "savanna"
    if rainfall_value > 0.75:
        return "temperate_rainforest"
    if rainfall_value > 0.5:
        return "temperate_forest"
    if rainfall_value < 0.25:
        return "steppe"
    return "grassland"

static func _aggregate_biomes(biome_map: Array[String], size: int) -> Array[Dictionary]:
    var polygons: Array[Dictionary] = []
    var cell_size: int = max(4, int(size / 64))
    for y in range(0, size, cell_size):
        var y_end: int = min(y + cell_size, size)
        for x in range(0, size, cell_size):
            var x_end: int = min(x + cell_size, size)
            var counter: Dictionary = {}
            for sy in range(y, y_end):
                for sx in range(x, x_end):
                    var biome: String = biome_map[sy * size + sx]
                    counter[biome] = counter.get(biome, 0) + 1
            var best_biome: String = "grassland"
            var best_score: int = -1
            for biome in counter.keys():
                var score: int = counter[biome]
                if score > best_score:
                    best_score = score
                    best_biome = biome
            var polygon := PackedVector2Array()
            polygon.append(Vector2(x, y))
            polygon.append(Vector2(x_end, y))
            polygon.append(Vector2(x_end, y_end))
            polygon.append(Vector2(x, y_end))
            polygons.append({
                "type": best_biome,
                "points": polygon,
            })
    return polygons
