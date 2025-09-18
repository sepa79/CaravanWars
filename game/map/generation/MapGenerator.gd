extends RefCounted
class_name MapGenerator

const MapGenerationParams := preload("res://map/generation/MapGenerationParams.gd")
const TerrainStage := preload("res://map/generation/stages/TerrainStage.gd")
const RiverStage := preload("res://map/generation/stages/RiverStage.gd")
const BiomeStage := preload("res://map/generation/stages/BiomeStage.gd")
const KingdomStage := preload("res://map/generation/stages/KingdomStage.gd")
const SettlementStage := preload("res://map/generation/stages/SettlementStage.gd")
const RoadStage := preload("res://map/generation/stages/RoadStage.gd")
const FortStage := preload("res://map/generation/stages/FortStage.gd")

var params: MapGenerationParams

func _init(p_params: MapGenerationParams = MapGenerationParams.new()) -> void:
    params = p_params

func generate() -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = params.rng_seed

    var state: Dictionary = {
        "rng": rng,
        "map_size": params.map_size,
    }

    var terrain := TerrainStage.run(state, params)
    state["terrain"] = terrain

    var rivers := RiverStage.run(state, params)
    state["rivers"] = rivers

    var biomes := BiomeStage.run(state, params)
    state["biomes"] = biomes

    var kingdoms := KingdomStage.run(state, params)
    state["kingdoms"] = kingdoms

    var settlements := SettlementStage.run(state, params)
    state["settlements"] = settlements

    var roads := RoadStage.run(state, params)
    state["roads"] = roads

    var forts := FortStage.run(state, params)
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
    var parse: Variant = JSON.parse_string(content)
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
