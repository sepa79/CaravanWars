extends RefCounted
class_name MapGenStub

const TERRAIN_CONTOUR_INTERVAL := 0.1
const RIVER_INFLUENCE_RADIUS := 6
const DEFAULT_CITY_MIN_DISTANCE := 40.0
const DEFAULT_VILLAGE_MIN_DISTANCE := 18.0
const BORDER_SAMPLE_STEP := 2
const FACE_OFF_DISTANCE := 80.0

class MapGenParams:
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
        p_map_size: int = 2048,
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

var params: MapGenParams

func _init(p_params: MapGenParams = MapGenParams.new()) -> void:
    params = p_params

func generate() -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = params.rng_seed

    var state: Dictionary = {
        "rng": rng,
        "map_size": params.map_size,
    }

    var terrain := _generate_terrain(state)
    state["terrain"] = terrain

    var rivers := _generate_rivers(state)
    state["rivers"] = rivers

    var biomes := _generate_biomes(state)
    state["biomes"] = biomes

    var kingdoms := _generate_kingdoms(state)
    state["kingdoms"] = kingdoms

    var settlements := _generate_settlements(state)
    state["settlements"] = settlements

    var roads := _generate_roads(state)
    state["roads"] = roads

    var forts := _generate_forts(state)
    state["forts"] = forts

    var map_data: Dictionary = {
        "meta": {
            "seed": params.rng_seed,
            "map_size": params.map_size,
            "kingdom_count": params.kingdom_count,
            "sea_level": params.sea_level,
        },
        "parameters": _serialize_params(),
        "terrain": terrain,
        "rivers": rivers,
        "biomes": biomes,
        "kingdoms": kingdoms,
        "settlements": settlements,
        "roads": roads,
        "forts": forts,
    }

    map_data["validation"] = validate_map(roads, rivers.get("polylines", []))
    return map_data

func _serialize_params() -> Dictionary:
    return {
        "rng_seed": params.rng_seed,
        "map_size": params.map_size,
        "kingdom_count": params.kingdom_count,
        "sea_level": params.sea_level,
        "terrain_octaves": params.terrain_octaves,
        "terrain_roughness": params.terrain_roughness,
        "mountain_scale": params.mountain_scale,
        "erosion_strength": params.erosion_strength,
        "river_min_accum": params.river_min_accum,
        "river_source_alt_thresh": params.river_source_alt_thresh,
        "road_aggressiveness": params.road_aggressiveness,
        "fort_global_cap": params.fort_global_cap,
        "fort_spacing": params.fort_spacing,
        "city_min_distance": params.city_min_distance,
        "village_min_distance": params.village_min_distance,
    }

func _generate_terrain(state: Dictionary) -> Dictionary:
    var size: int = state["map_size"]
    var total := size * size

    var noise := FastNoiseLite.new()
    noise.seed = params.rng_seed
    noise.frequency = 1.0 / float(size)
    noise.fractal_octaves = params.terrain_octaves
    noise.fractal_lacunarity = 2.0 + params.terrain_roughness
    noise.fractal_gain = 0.5 + params.terrain_roughness * 0.35

    var ridge_noise := FastNoiseLite.new()
    ridge_noise.seed = params.rng_seed + 17
    ridge_noise.frequency = 2.0 / float(size)
    ridge_noise.fractal_octaves = max(1, params.terrain_octaves - 2)
    ridge_noise.fractal_gain = 0.45

    var heightmap := PackedFloat32Array()
    heightmap.resize(total)
    var sea_mask := PackedByteArray()
    sea_mask.resize(total)

    var rng: RandomNumberGenerator = state["rng"]
    var erosion_passes := int(round(params.erosion_strength * 4.0))

    for y in range(size):
        for x in range(size):
            var nx := float(x) / float(size)
            var ny := float(y) / float(size)
            var base_height := (noise.get_noise_2d(nx * size, ny * size) + 1.0) * 0.5
            var ridge := (ridge_noise.get_noise_2d(nx * size, ny * size) + 1.0) * 0.5
            var mountain_factor := pow(ridge, 1.0 - clamp(params.mountain_scale, 0.0, 0.95))
            var height_value := clamp(base_height * (0.7 + params.mountain_scale * 0.2) + mountain_factor * 0.3, 0.0, 1.0)
            height_value = clamp(height_value, 0.0, 1.0)
            var jitter := (rng.randf() - 0.5) * 0.01
            height_value = clamp(height_value + jitter, 0.0, 1.0)
            var index := y * size + x
            heightmap[index] = height_value
            if height_value < params.sea_level:
                sea_mask[index] = 1
            else:
                sea_mask[index] = 0

    if erosion_passes > 0:
        heightmap = _apply_erosion(heightmap, size, erosion_passes)

    var slope_map := _calculate_slope(heightmap, size)
    var contours := _build_contours(heightmap, size)

    return {
        "heightmap": heightmap,
        "slope": slope_map,
        "sea_mask": sea_mask,
        "contours": contours,
    }

func _apply_erosion(heightmap: PackedFloat32Array, size: int, passes: int) -> PackedFloat32Array:
    var result := heightmap.duplicate()
    var kernel := [0.05, 0.2, 0.5, 0.2, 0.05]
    for _i in range(passes):
        var temp := result.duplicate()
        for y in range(size):
            for x in range(size):
                var acc := 0.0
                var weight := 0.0
                for ky in range(kernel.size()):
                    var offset_y := ky - kernel.size() / 2
                    var yy := int(clamp(y + offset_y, 0, size - 1))
                    for kx in range(kernel.size()):
                        var offset_x := kx - kernel.size() / 2
                        var xx := int(clamp(x + offset_x, 0, size - 1))
                        var idx := yy * size + xx
                        var weight_factor := kernel[ky] * kernel[kx]
                        acc += result[idx] * weight_factor
                        weight += weight_factor
                var index := y * size + x
                temp[index] = acc / max(weight, 0.001)
        result = temp
    return result

func _calculate_slope(heightmap: PackedFloat32Array, size: int) -> PackedFloat32Array:
    var slope := PackedFloat32Array()
    slope.resize(size * size)
    for y in range(size):
        for x in range(size):
            var index := y * size + x
            var left := heightmap[index]
            if x > 0:
                left = heightmap[index - 1]
            var right := heightmap[index]
            if x < size - 1:
                right = heightmap[index + 1]
            var up := heightmap[index]
            if y > 0:
                up = heightmap[index - size]
            var down := heightmap[index]
            if y < size - 1:
                down = heightmap[index + size]
            var dx := (right - left) * 0.5
            var dy := (down - up) * 0.5
            var slope_value := sqrt(dx * dx + dy * dy)
            slope[index] = clamp(slope_value, 0.0, 1.0)
    return slope

func _build_contours(heightmap: PackedFloat32Array, size: int) -> Array[Dictionary]:
    var contours_by_level: Dictionary = {}
    for y in range(size):
        for x in range(size):
            var index := y * size + x
            var height_value := heightmap[index]
            var level := int(round(height_value / TERRAIN_CONTOUR_INTERVAL))
            var level_value := level * TERRAIN_CONTOUR_INTERVAL
            var delta := abs(height_value - level_value)
            if delta < TERRAIN_CONTOUR_INTERVAL * 0.1:
                if not contours_by_level.has(level):
                    contours_by_level[level] = {
                        "level": float(level_value),
                        "points": PackedVector2Array(),
                    }
                var contour: Dictionary = contours_by_level[level]
                var points: PackedVector2Array = contour["points"]
                points.append(Vector2(x, y))
    return contours_by_level.values()

func _generate_rivers(state: Dictionary) -> Dictionary:
    var size: int = state["map_size"]
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var rng: RandomNumberGenerator = state["rng"]

    var source_candidates: Array[int] = []
    var sample_step := max(1, size / 128)
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index := y * size + x
            if sea_mask[index] == 1:
                continue
            var altitude := heightmap[index]
            if altitude < params.river_source_alt_thresh:
                continue
            var slope_value := slope_map[index]
            if slope_value < 0.05:
                continue
            source_candidates.append(index)

    source_candidates.sort_custom(func(a: int, b: int) -> bool:
        return heightmap[a] > heightmap[b]
    )

    var polylines: Array[Dictionary] = []
    var visited: Dictionary = {}
    var desired_count := int(clamp(int(params.map_size / 256) * 2, 3, 48))

    for candidate_index in source_candidates:
        if polylines.size() >= desired_count:
            break
        if visited.has(candidate_index):
            continue
        var river_path := _trace_river(candidate_index, size, heightmap, sea_mask)
        if river_path.size() < 4:
            continue
        var discharge := float(river_path.size())
        var width := max(1.0, sqrt(discharge) * 0.15)
        var entry := {
            "points": river_path,
            "width": width,
            "discharge": discharge,
        }
        polylines.append(entry)
        for point in river_path:
            var px := int(point.x)
            var py := int(point.y)
            visited[py * size + px] = true

    var distance_map := _calculate_river_distance(polylines, size)
    var watersheds := _build_river_watersheds(polylines)
    var river_lookup := PackedByteArray()
    river_lookup.resize(size * size)
    for river in polylines:
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        for point in points:
            var px := int(clamp(int(round(point.x)), 0, size - 1))
            var py := int(clamp(int(round(point.y)), 0, size - 1))
            var index := py * size + px
            if index < 0 or index >= river_lookup.size():
                continue
            river_lookup[index] = 1
    state["river_lookup"] = river_lookup

    return {
        "polylines": polylines,
        "distance_map": distance_map,
        "watersheds": watersheds,
        "lookup": river_lookup,
    }

func _trace_river(start_index: int, size: int, heightmap: PackedFloat32Array, sea_mask: PackedByteArray) -> PackedVector2Array:
    var path := PackedVector2Array()
    var current := start_index
    var guard := 0
    var visited: Dictionary = {}
    while guard < size * 4:
        guard += 1
        var cx := current % size
        var cy := current / size
        path.append(Vector2(cx, cy))
        if sea_mask[current] == 1 or heightmap[current] <= params.sea_level:
            break
        visited[current] = true
        var next_index := _find_downhill_neighbor(current, size, heightmap)
        if next_index == current:
            break
        if visited.has(next_index):
            break
        current = next_index
    return path

func _find_downhill_neighbor(index: int, size: int, heightmap: PackedFloat32Array) -> int:
    var cx := index % size
    var cy := index / size
    var best_index := index
    var best_height := heightmap[index]
    for y_offset in range(-1, 2):
        for x_offset in range(-1, 2):
            if x_offset == 0 and y_offset == 0:
                continue
            var nx := cx + x_offset
            var ny := cy + y_offset
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            var neighbor_index := ny * size + nx
            var neighbor_height := heightmap[neighbor_index]
            if neighbor_height < best_height:
                best_height = neighbor_height
                best_index = neighbor_index
    return best_index

func _calculate_river_distance(polylines: Array[Dictionary], size: int) -> PackedFloat32Array:
    var distance := PackedFloat32Array()
    distance.resize(size * size)
    for i in range(distance.size()):
        distance[i] = 1e6

    var queue: Array[int] = []
    for river in polylines:
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        for point in points:
            var px := int(point.x)
            var py := int(point.y)
            var index := py * size + px
            if index < 0 or index >= distance.size():
                continue
            if distance[index] > 0.0:
                distance[index] = 0.0
                queue.append(index)

    var head := 0
    var neighbor_offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while head < queue.size():
        var current := queue[head]
        head += 1
        var cx := current % size
        var cy := current / size
        for offset in neighbor_offsets:
            var nx := cx + offset.x
            var ny := cy + offset.y
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            var neighbor_index := ny * size + nx
            var new_distance := distance[current] + 1.0
            if new_distance < distance[neighbor_index]:
                distance[neighbor_index] = new_distance
                queue.append(neighbor_index)
    return distance

func _build_river_watersheds(polylines: Array[Dictionary]) -> Array[Dictionary]:
    var watersheds: Array[Dictionary] = []
    for i in range(polylines.size()):
        var river: Dictionary = polylines[i]
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        if points.size() < 3:
            continue
        var hull := Geometry2D.convex_hull(points)
        if hull.is_empty():
            continue
        watersheds.append({
            "river_index": i,
            "polygon": hull,
        })
    return watersheds

func _generate_biomes(state: Dictionary) -> Dictionary:
    var size: int = state["map_size"]
    var total := size * size
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
        var latitude := abs((float(y) / float(size)) - 0.5) * 2.0
        for x in range(size):
            var index := y * size + x
            var altitude := heightmap[index]
            var base_temp := clamp(1.0 - latitude - altitude * 0.65, 0.0, 1.0)
            var temp_variation := temp_noise.get_noise_2d(float(x), float(y)) * 0.1
            var temp_value := clamp(base_temp + temp_variation, 0.0, 1.0)
            temperature[index] = temp_value

            var rain_base := 0.5 + rain_noise.get_noise_2d(float(x), float(y)) * 0.25
            var river_boost := clamp(1.0 - min(river_distance[index] / float(RIVER_INFLUENCE_RADIUS * 2), 1.0), 0.0, 1.0)
            var slope_shadow := clamp(1.0 - slope_map[index] * 0.6, 0.0, 1.0)
            var rainfall_value := clamp(rain_base * slope_shadow + river_boost * 0.4 + (1.0 - altitude) * 0.15, 0.0, 1.0)
            rainfall[index] = rainfall_value

            var biome := _classify_biome(temp_value, rainfall_value, altitude, slope_map[index], sea_mask[index] == 1)
            biome_map[index] = biome
            var tag := ""
            if sea_mask[index] == 0:
                if _has_adjacent_sea(x, y, size, sea_mask):
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

func _classify_biome(temp_value: float, rainfall_value: float, altitude: float, slope_value: float, is_sea: bool) -> String:
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

func _has_adjacent_sea(x: int, y: int, size: int, sea_mask: PackedByteArray) -> bool:
    for y_offset in range(-1, 2):
        for x_offset in range(-1, 2):
            if x_offset == 0 and y_offset == 0:
                continue
            var nx := x + x_offset
            var ny := y + y_offset
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            if sea_mask[ny * size + nx] == 1:
                return true
    return false

func _aggregate_biomes(biome_map: Array[String], size: int) -> Array[Dictionary]:
    var polygons: Array[Dictionary] = []
    var cell_size := max(4, size / 64)
    for y in range(0, size, cell_size):
        var y_end := min(y + cell_size, size)
        for x in range(0, size, cell_size):
            var x_end := min(x + cell_size, size)
            var counter: Dictionary = {}
            for sy in range(y, y_end):
                for sx in range(x, x_end):
                    var biome := biome_map[sy * size + sx]
                    counter[biome] = counter.get(biome, 0) + 1
            var best_biome := "grassland"
            var best_score := -1
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

func _generate_kingdoms(state: Dictionary) -> Dictionary:
    var size: int = state["map_size"]
    var total := size * size
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var temperature: PackedFloat32Array = state["temperature_map"]
    var rainfall: PackedFloat32Array = state["rainfall_map"]
    var river_distance: PackedFloat32Array = state["rivers"]["distance_map"]
    var biome_map: Array[String] = state["biome_map"]
    var rng: RandomNumberGenerator = state["rng"]

    var sample_step := max(1, size / 96)
    var candidates: Array[Dictionary] = []
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index := y * size + x
            if sea_mask[index] == 1:
                continue
            if slope_map[index] > 0.85:
                continue
            var habitability := (1.0 - abs(temperature[index] - 0.6)) * 0.6 + rainfall[index] * 0.4
            habitability = clamp(habitability, 0.0, 1.5)
            var river_bonus := clamp(1.0 - min(river_distance[index] / float(RIVER_INFLUENCE_RADIUS * 1.8), 1.0), 0.0, 1.0)
            var score := habitability + river_bonus
            score += rng.randf() * 0.15
            candidates.append({
                "index": index,
                "score": score,
            })

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var capitals: Array[Dictionary] = []
    var min_distance := float(size) / max(1.0, float(params.kingdom_count) * 1.8)
    var fallback_distance := max(8.0, min_distance * 0.5)

    for candidate in candidates:
        if capitals.size() >= params.kingdom_count:
            break
        var index: int = candidate["index"]
        var cx := index % size
        var cy := index / size
        var position := Vector2(cx, cy)
        var is_valid := true
        for capital in capitals:
            if position.distance_to(capital["position"]) < min_distance:
                is_valid = false
                break
        if not is_valid:
            continue
        capitals.append({
            "kingdom_id": capitals.size(),
            "index": index,
            "position": position,
            "score": candidate["score"],
            "biome": biome_map[index],
        })

    if capitals.size() < params.kingdom_count:
        for candidate in candidates:
            if capitals.size() >= params.kingdom_count:
                break
            var index := candidate["index"]
            var cx := index % size
            var cy := index / size
            var position := Vector2(cx, cy)
            var too_close := false
            for capital in capitals:
                if position.distance_to(capital["position"]) < fallback_distance:
                    too_close = true
                    break
            if too_close:
                continue
            capitals.append({
                "kingdom_id": capitals.size(),
                "index": index,
                "position": position,
                "score": candidate["score"],
                "biome": biome_map[index],
            })

    if capitals.is_empty():
        var default_index := size * size / 2 + size / 2
        capitals.append({
            "kingdom_id": 0,
            "index": default_index,
            "position": Vector2(size / 2, size / 2),
            "score": 0.0,
            "biome": "grassland",
        })

    var assignment := PackedInt32Array()
    assignment.resize(total)
    for i in range(assignment.size()):
        assignment[i] = -1

    for y in range(size):
        for x in range(size):
            var index := y * size + x
            if sea_mask[index] == 1:
                continue
            var best_cost := INF
            var best_kingdom := -1
            for capital in capitals:
                var capital_index: int = capital["index"]
                var cx := capital_index % size
                var cy := capital_index / size
                var dx := float(x - cx)
                var dy := float(y - cy)
                var distance := sqrt(dx * dx + dy * dy)
                var slope_penalty := slope_map[index] * 35.0
                var biome_penalty := 0.0
                if biome_map[index] != capital["biome"]:
                    biome_penalty = 10.0
                var river_penalty := 0.0
                if state["rivers"].has("distance_map"):
                    var dist_to_river := river_distance[index]
                    if dist_to_river < 2.5:
                        river_penalty = 8.0
                var cost := distance + slope_penalty + biome_penalty + river_penalty
                if cost < best_cost:
                    best_cost = cost
                    best_kingdom = capital["kingdom_id"]
            assignment[index] = best_kingdom

    var polygons: Array[Dictionary] = []
    var sample_mod := max(1, size / 128)
    for capital in capitals:
        var kingdom_id: int = capital["kingdom_id"]
        var points := PackedVector2Array()
        for y in range(0, size, sample_mod):
            for x in range(0, size, sample_mod):
                var index := y * size + x
                if assignment[index] == kingdom_id:
                    points.append(Vector2(x, y))
        if points.size() < 3:
            var fallback_polygon := PackedVector2Array()
            fallback_polygon.append(capital["position"] + Vector2(-10, -10))
            fallback_polygon.append(capital["position"] + Vector2(10, -10))
            fallback_polygon.append(capital["position"] + Vector2(10, 10))
            fallback_polygon.append(capital["position"] + Vector2(-10, 10))
            polygons.append({
                "kingdom_id": kingdom_id,
                "capital_candidate": capital["position"],
                "polygon": fallback_polygon,
            })
            continue
        var hull := Geometry2D.convex_hull(points)
        polygons.append({
            "kingdom_id": kingdom_id,
            "capital_candidate": capital["position"],
            "polygon": hull,
        })

    var border_lines := _build_border_lines(assignment, size)

    state["kingdom_assignment"] = assignment
    state["capitals"] = capitals

    return {
        "polygons": polygons,
        "borders": border_lines,
        "capitals": capitals,
    }

func _build_border_lines(assignment: PackedInt32Array, size: int) -> Array[Dictionary]:
    var borders: Array[Dictionary] = []
    for y in range(size - 1):
        for x in range(size - 1):
            var index := y * size + x
            var current := assignment[index]
            if current < 0:
                continue
            var right := assignment[index + 1]
            if right >= 0 and right != current and current < right:
                var line := PackedVector2Array()
                line.append(Vector2(x + 1, y))
                line.append(Vector2(x + 1, y + 1))
                borders.append({
                    "between": PackedInt32Array([current, right]),
                    "points": line,
                })
            var down := assignment[index + size]
            if down >= 0 and down != current and current < down:
                var line_down := PackedVector2Array()
                line_down.append(Vector2(x, y + 1))
                line_down.append(Vector2(x + 1, y + 1))
                borders.append({
                    "between": PackedInt32Array([current, down]),
                    "points": line_down,
                })
    return borders

func _generate_settlements(state: Dictionary) -> Dictionary:
    var size: int = state["map_size"]
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var rainfall: PackedFloat32Array = state["rainfall_map"]
    var temperature: PackedFloat32Array = state["temperature_map"]
    var river_distance: PackedFloat32Array = state["rivers"]["distance_map"]
    var rng: RandomNumberGenerator = state["rng"]

    var sample_step := max(1, size / 96)
    var city_candidates: Array[Dictionary] = []
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index := y * size + x
            var kingdom_id := assignment[index]
            if kingdom_id < 0:
                continue
            if sea_mask[index] == 1:
                continue
            var slope_value := slope_map[index]
            if slope_value > 0.75:
                continue
            var rainfall_value := rainfall[index]
            var temp_value := temperature[index]
            var river_bonus := clamp(1.0 - min(river_distance[index] / float(RIVER_INFLUENCE_RADIUS * 1.8), 1.0), 0.0, 1.0)
            var border_bonus := _distance_to_border(Vector2(x, y), state, params.map_size) < 6.0 ? 0.15 : 0.0
            var score := (1.0 - slope_value) * 0.5 + rainfall_value * 0.25 + (1.0 - abs(temp_value - 0.6)) * 0.2 + river_bonus * 0.3 + border_bonus
            score += rng.randf() * 0.05
            city_candidates.append({
                "position": Vector2(x, y),
                "kingdom_id": kingdom_id,
                "score": score,
                "index": index,
                "is_coast": _has_adjacent_sea(x, y, size, sea_mask),
            })

    city_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var cities: Array[Dictionary] = []
    var city_counts: Dictionary = {}
    var city_target_per_kingdom: Dictionary = {}

    for kingdom_id in range(params.kingdom_count):
        city_target_per_kingdom[kingdom_id] = max(1, int(size * size / float(params.kingdom_count * 16000)))
        city_counts[kingdom_id] = 0

    for candidate in city_candidates:
        var kingdom_id: int = candidate["kingdom_id"]
        if city_counts[kingdom_id] >= city_target_per_kingdom[kingdom_id]:
            continue
        var position: Vector2 = candidate["position"]
        if not _is_far_enough(position, cities, params.city_min_distance):
            continue
        var population := int(round(6000.0 + candidate["score"] * 20000.0))
        var city_entry := {
            "type": "city",
            "kingdom_id": kingdom_id,
            "position": position,
            "population": population,
            "port": candidate["is_coast"],
            "score": candidate["score"],
        }
        cities.append(city_entry)
        city_counts[kingdom_id] = city_counts[kingdom_id] + 1
    if cities.is_empty() and not city_candidates.is_empty():
        var fallback := city_candidates[0]
        cities.append({
            "type": "city",
            "kingdom_id": fallback["kingdom_id"],
            "position": fallback["position"],
            "population": 6000,
            "port": fallback["is_coast"],
            "score": fallback["score"],
        })

    var village_candidates := city_candidates.duplicate()
    village_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var villages: Array[Dictionary] = []
    var village_target_per_kingdom: Dictionary = {}
    for kingdom_id in range(params.kingdom_count):
        village_target_per_kingdom[kingdom_id] = max(2, city_counts.get(kingdom_id, 0) * 3)

    for candidate in village_candidates:
        var kingdom_id: int = candidate["kingdom_id"]
        if villages.filter(func(v: Dictionary) -> bool:
            return v["kingdom_id"] == kingdom_id
        ).size() >= village_target_per_kingdom[kingdom_id]:
            continue
        var position: Vector2 = candidate["position"]
        if not _is_far_enough(position, cities, params.village_min_distance):
            continue
        if not _is_far_enough(position, villages, params.village_min_distance):
            continue
        var population := int(round(800.0 + candidate["score"] * 3500.0))
        villages.append({
            "type": "village",
            "kingdom_id": kingdom_id,
            "position": position,
            "population": population,
            "port": candidate["is_coast"],
            "score": candidate["score"],
        })

    state["city_counts"] = city_counts
    state["cities"] = cities
    state["villages"] = villages

    return {
        "cities": cities,
        "villages": villages,
    }

func _is_far_enough(position: Vector2, existing: Array[Dictionary], minimum_distance: float) -> bool:
    for entry in existing:
        var other_position: Vector2 = entry["position"]
        if position.distance_to(other_position) < minimum_distance:
            return false
    return true

func _distance_to_border(position: Vector2, state: Dictionary, size: int) -> float:
    var borders: Array[Dictionary] = []
    if state.has("kingdoms"):
        var kingdoms_data = state["kingdoms"]
        if kingdoms_data is Dictionary:
            borders = kingdoms_data.get("borders", [])
    if borders.is_empty():
        return 9999.0
    var best := 9999.0
    for border in borders:
        var points: PackedVector2Array = border.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        var step := max(1, BORDER_SAMPLE_STEP)
        for i in range(0, points.size() - 1, step):
            var start := points[i]
            var end := points[min(i + 1, points.size() - 1)]
            var closest := Geometry2D.get_closest_point_to_segment(position, start, end)
            var distance := closest.distance_to(position)
            if distance < best:
                best = distance
    return best

class _DisjointSet:
    var parent: Array[int]
    var ranks: Array[int]

    func _init(size: int) -> void:
        parent = []
        ranks = []
        for i in range(size):
            parent.append(i)
            ranks.append(0)

    func find(value: int) -> int:
        if parent[value] != value:
            parent[value] = find(parent[value])
        return parent[value]

    func join(a: int, b: int) -> void:
        var root_a := find(a)
        var root_b := find(b)
        if root_a == root_b:
            return
        if ranks[root_a] < ranks[root_b]:
            parent[root_a] = root_b
        elif ranks[root_a] > ranks[root_b]:
            parent[root_b] = root_a
        else:
            parent[root_b] = root_a
            ranks[root_a] += 1

func _generate_roads(state: Dictionary) -> Dictionary:
    var cities: Array[Dictionary] = state["cities"]
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var size: int = state["map_size"]
    var rng: RandomNumberGenerator = state["rng"]
    var river_lookup: PackedByteArray = state.get("river_lookup", PackedByteArray())

    if cities.size() < 2:
        return {
            "polylines": [],
            "connectivity": {
                "components": 1,
                "isolated_cities": [],
            },
        }

    var edges: Array[Dictionary] = []
    for i in range(cities.size()):
        for j in range(i + 1, cities.size()):
            var pos_a: Vector2 = cities[i]["position"]
            var pos_b: Vector2 = cities[j]["position"]
            var distance := pos_a.distance_to(pos_b)
            edges.append({
                "a": i,
                "b": j,
                "distance": distance,
            })

    edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["distance"] < b["distance"]
    )

    var dsu := _DisjointSet.new(cities.size())
    var road_polylines: Array[Dictionary] = []
    var used_pairs: Dictionary = {}

    for edge in edges:
        var a: int = edge["a"]
        var b: int = edge["b"]
        if dsu.find(a) == dsu.find(b):
            continue
        var road := _create_road_between(cities[a], cities[b], "primary", assignment, sea_mask, slope_map, river_lookup, size)
        road_polylines.append(road)
        used_pairs[_road_pair_key(a, b)] = true
        dsu.join(a, b)

    for edge in edges:
        if rng.randf() > params.road_aggressiveness:
            continue
        var a: int = edge["a"]
        var b: int = edge["b"]
        var key := _road_pair_key(a, b)
        if used_pairs.has(key):
            continue
        var road := _create_road_between(cities[a], cities[b], "secondary", assignment, sea_mask, slope_map, river_lookup, size)
        road_polylines.append(road)
        used_pairs[key] = true

    var connectivity := _build_road_connectivity(cities, road_polylines)

    return {
        "polylines": road_polylines,
        "connectivity": connectivity,
    }

func _road_pair_key(a: int, b: int) -> String:
    return "%s-%s" % [min(a, b), max(a, b)]

func _create_road_between(
    city_a: Dictionary,
    city_b: Dictionary,
    road_type: String,
    assignment: PackedInt32Array,
    sea_mask: PackedByteArray,
    slope_map: PackedFloat32Array,
    river_lookup: PackedByteArray,
    size: int
) -> Dictionary:
    var start: Vector2 = city_a["position"]
    var end: Vector2 = city_b["position"]
    var path := _build_road_path(start, end, sea_mask, slope_map, size)
    var traversed := _sample_kingdoms_along_path(path, assignment, size)
    var crosses_river := _path_crosses_river(path, size, river_lookup)
    return {
        "type": road_type,
        "points": path,
        "length": _polyline_length(path),
        "traversed_kingdoms": traversed,
        "crosses_border": traversed.size() > 1,
        "crosses_river": crosses_river,
    }

func _build_road_path(
    start: Vector2,
    end: Vector2,
    sea_mask: PackedByteArray,
    slope_map: PackedFloat32Array,
    size: int
) -> PackedVector2Array:
    var path := PackedVector2Array()
    path.append(start)
    var mid := Vector2((start.x + end.x) * 0.5, (start.y + end.y) * 0.5)
    var alt_mid := Vector2(start.x, end.y)
    var alt_mid_two := Vector2(end.x, start.y)

    var best_midpoints := []
    best_midpoints.append(mid)
    best_midpoints.append(alt_mid)
    best_midpoints.append(alt_mid_two)

    var best_score := INF
    var best_path := PackedVector2Array()
    for candidate_midpoint in best_midpoints:
        var candidate_path := PackedVector2Array()
        candidate_path.append(start)
        candidate_path.append(candidate_midpoint)
        candidate_path.append(end)
        var score := _evaluate_path(candidate_path, sea_mask, slope_map, size)
        if score < best_score:
            best_score = score
            best_path = candidate_path
    path = best_path

    return _simplify_path(path)

func _evaluate_path(path: PackedVector2Array, sea_mask: PackedByteArray, slope_map: PackedFloat32Array, size: int) -> float:
    var penalty := 0.0
    for i in range(path.size() - 1):
        var segment_start := path[i]
        var segment_end := path[i + 1]
        var length := segment_start.distance_to(segment_end)
        var samples := max(1, int(length / 4.0))
        for sample in range(samples + 1):
            var t := float(sample) / float(samples)
            var position := segment_start.lerp(segment_end, t)
            var index := _index_from_position(position, size)
            var slope_value := slope_map[index]
            penalty += slope_value * 2.0
            if _is_water(position, sea_mask, size):
                penalty += 25.0
    return penalty

func _simplify_path(path: PackedVector2Array) -> PackedVector2Array:
    var simplified := PackedVector2Array()
    if path.is_empty():
        return simplified
    simplified.append(path[0])
    for i in range(1, path.size() - 1):
        var prev := simplified[simplified.size() - 1]
        var current := path[i]
        if current.distance_squared_to(prev) < 1.0:
            continue
        simplified.append(current)
    simplified.append(path[path.size() - 1])
    return simplified

func _is_water(position: Vector2, sea_mask: PackedByteArray, size: int) -> bool:
    var index := _index_from_position(position, size)
    return sea_mask[index] == 1

func _index_from_position(position: Vector2, size: int) -> int:
    var x := int(clamp(int(round(position.x)), 0, size - 1))
    var y := int(clamp(int(round(position.y)), 0, size - 1))
    return y * size + x

func _sample_kingdoms_along_path(path: PackedVector2Array, assignment: PackedInt32Array, size: int) -> PackedInt32Array:
    var kingdoms := []
    for i in range(path.size() - 1):
        var segment_start := path[i]
        var segment_end := path[i + 1]
        var length := segment_start.distance_to(segment_end)
        var samples := max(1, int(length / 6.0))
        for sample in range(samples + 1):
            var t := float(sample) / float(samples)
            var position := segment_start.lerp(segment_end, t)
            var kingdom_id := assignment[_index_from_position(position, size)]
            if kingdom_id < 0:
                continue
            if kingdom_id not in kingdoms:
                kingdoms.append(kingdom_id)
    return PackedInt32Array(kingdoms)

func _path_crosses_river(path: PackedVector2Array, size: int, river_lookup: PackedByteArray) -> bool:
    for i in range(path.size() - 1):
        var segment_start := path[i]
        var segment_end := path[i + 1]
        var length := segment_start.distance_to(segment_end)
        var samples := max(1, int(length / 4.0))
        for sample in range(samples + 1):
            var t := float(sample) / float(samples)
            var position := segment_start.lerp(segment_end, t)
            if _is_river(position, size, river_lookup):
                return true
    return false

func _is_river(position: Vector2, size: int, river_lookup: PackedByteArray) -> bool:
    if river_lookup.is_empty():
        return false
    var px := int(clamp(int(round(position.x)), 0, size - 1))
    var py := int(clamp(int(round(position.y)), 0, size - 1))
    var index := py * size + px
    if index < 0 or index >= river_lookup.size():
        return false
    return river_lookup[index] == 1

func _polyline_length(path: PackedVector2Array) -> float:
    var length := 0.0
    for i in range(path.size() - 1):
        length += path[i].distance_to(path[i + 1])
    return length

func _build_road_connectivity(cities: Array[Dictionary], roads: Array[Dictionary]) -> Dictionary:
    var adjacency: Dictionary = {}
    for i in range(cities.size()):
        adjacency[i] = []
    for road in roads:
        var points: PackedVector2Array = road.get("points", PackedVector2Array())
        if points.is_empty():
            continue
        var start := points[0]
        var end := points[points.size() - 1]
        var start_city := _find_city_index(start, cities)
        var end_city := _find_city_index(end, cities)
        if start_city == -1 or end_city == -1:
            continue
        adjacency[start_city].append(end_city)
        adjacency[end_city].append(start_city)
    var visited: Dictionary = {}
    var components := 0
    for i in range(cities.size()):
        if visited.has(i):
            continue
        components += 1
        var stack: Array[int] = [i]
        while not stack.is_empty():
            var current := stack.pop_back()
            if visited.has(current):
                continue
            visited[current] = true
            for neighbor in adjacency[current]:
                if not visited.has(neighbor):
                    stack.append(neighbor)
    var isolated: Array[int] = []
    for i in range(cities.size()):
        if adjacency[i].is_empty():
            isolated.append(i)
    return {
        "components": components,
        "isolated_cities": isolated,
    }

func _find_city_index(position: Vector2, cities: Array[Dictionary]) -> int:
    for i in range(cities.size()):
        var city_position: Vector2 = cities[i]["position"]
        if city_position.distance_to(position) < 1.5:
            return i
    return -1

func _generate_forts(state: Dictionary) -> Dictionary:
    var roads: Dictionary = state["roads"]
    var road_polylines: Array[Dictionary] = roads.get("polylines", [])
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var size: int = state["map_size"]
    var rng: RandomNumberGenerator = state["rng"]
    var cities: Array[Dictionary] = state["cities"]
    var city_counts: Dictionary = state["city_counts"]

    var candidates: Array[Dictionary] = []
    for road_index in range(road_polylines.size()):
        var road := road_polylines[road_index]
        var points: PackedVector2Array = road.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        for i in range(points.size() - 1):
            var mid := points[i].lerp(points[i + 1], 0.5)
            var index := _index_from_position(mid, size)
            var kingdom_id := assignment[index]
            if kingdom_id < 0:
                continue
            var elevation := heightmap[index]
            var slope_value := slope_map[index]
            if slope_value > 0.9:
                continue
            var border_distance := _distance_to_border(mid, state, size)
            var score := (1.0 - slope_value) + clamp(1.0 - border_distance / 12.0, 0.0, 1.0)
            if road.get("crosses_river", false):
                score += 0.4
            score += rng.randf() * 0.1
            candidates.append({
                "position": mid,
                "kingdom_id": kingdom_id,
                "score": score,
                "elevation": elevation,
                "road_index": road_index,
                "border_distance": border_distance,
            })

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var forts: Array[Dictionary] = []
    var per_kingdom_cap: Dictionary = {}
    var base_cap := params.fort_global_cap
    for kingdom_id in range(params.kingdom_count):
        var kingdom_city_count := city_counts.get(kingdom_id, 0)
        var dynamic_cap := 0
        if kingdom_city_count > 0:
            dynamic_cap = max(1, kingdom_city_count / 4)
        var allowed := dynamic_cap
        if kingdom_city_count > 0 and allowed < 1:
            allowed = 1
        if base_cap > 0:
            var base_limit := max(1, base_cap / max(1, params.kingdom_count))
            if kingdom_city_count > 0 and allowed < 1:
                allowed = 1
            if allowed > 0:
                allowed = min(allowed, base_limit)
            else:
                allowed = min(1, base_limit)
        per_kingdom_cap[kingdom_id] = allowed
    var face_off_distance_sq := FACE_OFF_DISTANCE * FACE_OFF_DISTANCE

    for candidate in candidates:
        var kingdom_id: int = candidate["kingdom_id"]
        if per_kingdom_cap.get(kingdom_id, 0) <= 0:
            continue
        var position: Vector2 = candidate["position"]
        var valid := true
        for fort in forts:
            if position.distance_squared_to(fort["position"]) < float(params.fort_spacing * params.fort_spacing):
                valid = false
                break
        if not valid:
            continue
        for fort in forts:
            if fort["kingdom_id"] == kingdom_id:
                continue
            if position.distance_squared_to(fort["position"]) < face_off_distance_sq:
                if candidate["border_distance"] < 4.0 and fort.get("border_distance", 0.0) < 4.0:
                    valid = false
                    break
        if not valid:
            continue
        var fort_type := "frontier"
        if candidate["border_distance"] < 4.0:
            fort_type = "border"
        elif candidate["score"] > 1.6:
            fort_type = "road_guard"
        forts.append({
            "kingdom_id": kingdom_id,
            "position": position,
            "priority_score": candidate["score"],
            "type": fort_type,
            "elevation": candidate["elevation"],
            "nearby_road": candidate["road_index"],
            "border_distance": candidate["border_distance"],
        })
        per_kingdom_cap[kingdom_id] = per_kingdom_cap[kingdom_id] - 1
        if base_cap > 0 and forts.size() >= base_cap:
            break

    return {
        "points": forts,
    }

static func validate_map(roads: Dictionary, rivers: Array) -> Array[String]:
    var issues: Array[String] = []
    if not roads.has("polylines"):
        issues.append("roads.missing_layer")
    else:
        for road in roads["polylines"]:
            if not road.has("points"):
                issues.append("roads.missing_points")
                continue
            var points: PackedVector2Array = road["points"]
            if points.size() < 2:
                issues.append("roads.segment_too_short")
            if road.get("traversed_kingdoms", PackedInt32Array()).is_empty():
                issues.append("roads.missing_traversed_kingdoms")
    if roads.has("connectivity"):
        var connectivity: Dictionary = roads["connectivity"]
        var isolated: Array = connectivity.get("isolated_cities", [])
        if not isolated.is_empty():
            issues.append("roads.isolated_cities")
    for river in rivers:
        if not (river is Dictionary):
            issues.append("rivers.invalid_entry")
            continue
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        if points.size() < 2:
            issues.append("rivers.segment_too_short")
        if river.get("discharge", 0.0) <= 0.0:
            issues.append("rivers.non_positive_discharge")
    return issues

static func export_bundle(
    path: String,
    map_data: Dictionary,
    rng_seed: int,
    version: String,
    width: float,
    height: float,
    unit_scale: float = 1.0
) -> void:
    var payload := {
        "version": version,
        "rng_seed": rng_seed,
        "unit_scale": unit_scale,
        "dimensions": {
            "width": width,
            "height": height,
        },
        "map": map_data,
    }
    var json := JSON.stringify(payload, "\t")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to export map bundle to %s" % path)
        return
    file.store_string(json)
    file.close()

static func load_bundle(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var content := file.get_as_text()
    file.close()
    var parse := JSON.parse_string(content)
    if parse is Dictionary:
        return parse
    return {}

static func generate_regions(
    cities: Array[Vector2],
    kingdom_count: int,
    width: float,
    height: float
) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = kingdom_count + int(width) * 13 + int(height) * 37
    var seeds: Array[Vector2] = []
    if cities.is_empty():
        for i in range(kingdom_count):
            seeds.append(Vector2(rng.randf_range(0.1, 0.9) * width, rng.randf_range(0.1, 0.9) * height))
    else:
        seeds = cities
    var cell_step := 32.0
    var grid_width := int(ceil(width / cell_step))
    var grid_height := int(ceil(height / cell_step))
    var assignment := []
    assignment.resize(grid_width * grid_height)
    for gy in range(grid_height):
        for gx in range(grid_width):
            var px := float(gx) * cell_step
            var py := float(gy) * cell_step
            var best_seed := -1
            var best_distance := INF
            for i in range(seeds.size()):
                var seed_position := seeds[i]
                var distance := Vector2(px, py).distance_squared_to(seed_position)
                if distance < best_distance:
                    best_distance = distance
                    best_seed = i
            assignment[gy * grid_width + gx] = best_seed
    var polygons: Array[Dictionary] = []
    for i in range(seeds.size()):
        var polygon := PackedVector2Array()
        for gy in range(grid_height):
            for gx in range(grid_width):
                if assignment[gy * grid_width + gx] != i:
                    continue
                var x0 := float(gx) * cell_step
                var y0 := float(gy) * cell_step
                polygon.append(Vector2(x0, y0))
                polygon.append(Vector2(x0 + cell_step, y0))
                polygon.append(Vector2(x0 + cell_step, y0 + cell_step))
                polygon.append(Vector2(x0, y0 + cell_step))
        if polygon.is_empty():
            continue
        var hull := Geometry2D.convex_hull(polygon)
        polygons.append({
            "seed": seeds[i],
            "polygon": hull,
        })
    return {
        "regions": polygons,
    }
