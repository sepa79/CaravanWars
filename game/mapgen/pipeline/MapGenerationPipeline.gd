extends RefCounted
class_name MapGenPipeline

const TerrainStageModule: Script = preload("res://mapgen/pipeline/TerrainStage.gd")
const RiverStageModule: Script = preload("res://mapgen/pipeline/RiverStage.gd")
const BiomeStageModule: Script = preload("res://mapgen/pipeline/BiomeStage.gd")
const KingdomBordersStageModule: Script = preload("res://mapgen/pipeline/KingdomBordersStage.gd")
const CitiesVillagesStageModule: Script = preload("res://mapgen/pipeline/CitiesVillagesStage.gd")
const RoadsStageModule: Script = preload("res://mapgen/pipeline/RoadsStage.gd")
const FortsStageModule: Script = preload("res://mapgen/pipeline/FortsStage.gd")
const MapNodeModule: Script = preload("res://mapview/MapNode.gd")

## Parameter container for map generation.
class MapGenParams:
    var rng_seed: int
    var city_count: int
    var max_river_count: int
    var min_connections: int
    var max_connections: int
    var min_city_distance: float
    var max_city_distance: float
    var crossroad_detour_margin: float
    var width: float
    var height: float
    var kingdom_count: int
    var max_forts_per_kingdom: int
    var village_count: int
    var village_per_city: int

    func _init(
        p_rng_seed: int = 0,
        p_city_count: int = 6,
        p_max_river_count: int = 1,
        p_min_connections: int = 1,
        p_max_connections: int = 3,
        p_min_city_distance: float = 20.0,
        p_max_city_distance: float = 40.0,
        p_crossroad_detour_margin: float = 5.0,
        p_width: float = 150.0,
        p_height: float = 150.0,
        p_kingdom_count: int = 3,
        p_max_forts_per_kingdom: int = 1,
        p_village_count: int = 10,
        p_village_per_city: int = 2
    ) -> void:
        rng_seed = p_rng_seed if p_rng_seed != 0 else Time.get_ticks_msec()
        city_count = p_city_count
        max_river_count = p_max_river_count
        var max_possible: int = min(7, max(1, p_city_count - 1))
        min_connections = clamp(p_min_connections, 1, max_possible)
        max_connections = clamp(p_max_connections, min_connections, max_possible)
        min_city_distance = min(p_min_city_distance, p_max_city_distance)
        max_city_distance = max(p_min_city_distance, p_max_city_distance)
        crossroad_detour_margin = p_crossroad_detour_margin
        width = clamp(p_width, 20.0, 500.0)
        height = clamp(p_height, 20.0, 500.0)
        kingdom_count = max(1, p_kingdom_count)
        max_forts_per_kingdom = max(0, p_max_forts_per_kingdom)
        village_count = max(0, p_village_count)
        village_per_city = max(0, p_village_per_city)

class MapGenContext:
    var params: MapGenParams
    var rng_seed: int
    var base_rng: RandomNumberGenerator
    var stage_rngs: Dictionary
    var vector_layers: Dictionary
    var raster_layers: Dictionary
    var data: Dictionary

    func _init(_params: MapGenParams) -> void:
        params = _params
        rng_seed = params.rng_seed
        base_rng = RandomNumberGenerator.new()
        base_rng.seed = rng_seed
        stage_rngs = {}
        vector_layers = {}
        raster_layers = {}
        data = {}

    func get_stage_rng(stage_id: String) -> RandomNumberGenerator:
        if stage_rngs.has(stage_id):
            return stage_rngs[stage_id]
        var rng := RandomNumberGenerator.new()
        var hashed: int = hash([rng_seed, stage_id])
        if hashed == 0:
            hashed = rng_seed
        rng.seed = hashed
        stage_rngs[stage_id] = rng
        return rng

    func set_vector_layer(name: String, value: Variant) -> void:
        vector_layers[name] = value

    func get_vector_layer(name: String, default_value: Variant = null) -> Variant:
        return vector_layers.get(name, default_value)

    func set_raster_layer(name: String, value: Variant) -> void:
        raster_layers[name] = value

    func get_raster_layer(name: String, default_value: Variant = null) -> Variant:
        return raster_layers.get(name, default_value)

    func set_data(key: String, value: Variant) -> void:
        data[key] = value

    func get_data(key: String, default_value: Variant = null) -> Variant:
        return data.get(key, default_value)

var params: MapGenParams

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params

func generate() -> Dictionary:
    var context := MapGenContext.new(params)
    var stages: Array[RefCounted] = [
        TerrainStageModule.new(),
        RiverStageModule.new(),
        BiomeStageModule.new(),
        KingdomBordersStageModule.new(),
        CitiesVillagesStageModule.new(),
        RoadsStageModule.new(),
        FortsStageModule.new(),
    ]
    for stage in stages:
        stage.run(context)
    return _build_result(context)

func _build_result(context: MapGenContext) -> Dictionary:
    var map_data: Dictionary = {
        "width": context.params.width,
        "height": context.params.height,
        "fertility": context.get_raster_layer("fertility", []),
        "roughness": context.get_raster_layer("roughness", []),
        "biomes": context.get_raster_layer("biomes", []),
        "rivers": context.get_vector_layer("rivers", []),
        "cities": context.get_vector_layer("cities", []),
        "villages": context.get_vector_layer("villages", []),
        "forts": context.get_vector_layer("forts", []),
        "roads": context.get_vector_layer("roads", {}),
        "regions": context.get_vector_layer("regions", {}),
        "kingdom_seeds": context.get_vector_layer("kingdom_seeds", []),
        "kingdom_names": context.get_data("kingdom_names", {}),
        "capitals": context.get_data("capitals", []),
    }
    var roads: Dictionary = map_data.get("roads", {})
    var nodes: Dictionary = roads.get("nodes", {})
    for idx in map_data.get("capitals", []):
        var nid: int = idx + 1
        if nodes.has(nid):
            var node: RefCounted = nodes[nid]
            node.attrs["is_capital"] = true
    return map_data

static func export_bundle(path: String, map_data: Dictionary, rng_seed: int, version: String, width: float, height: float, unit_scale: float = 1.0) -> void:
    var bundle: Dictionary = _bundle_from_map(map_data, rng_seed, version, width, height, unit_scale)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(bundle, "\t"))
        file.close()

static func _bundle_from_map(map_data: Dictionary, rng_seed: int, version: String, width: float, height: float, unit_scale: float) -> Dictionary:
    var bundle: Dictionary = {
        "meta": {
            "version": version,
            "seed": rng_seed,
            "map_size": int(max(width, height)),
            "unit_scale": unit_scale,
        },
        "fertility": map_data.get("fertility", []),
        "roughness": map_data.get("roughness", []),
        "nodes": [],
        "edges": [],
        "cities": [],
        "crossings": [],
        "forts": [],
        "kingdoms": [],
        "rivers": [],
        "climate_cells": [],
    }
    var roads: Dictionary = map_data.get("roads", {})
    var nodes: Dictionary = roads.get("nodes", {})
    var capital_by_kingdom: Dictionary = {}
    for node in nodes.values():
        bundle["nodes"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y})
        match node.type:
            MapNodeModule.TYPE_CITY:
                var kid: int = node.attrs.get("kingdom_id", 0)
                var is_cap: bool = node.attrs.get("is_capital", false)
                bundle["cities"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "kingdom_id": kid, "is_capital": is_cap})
                if is_cap:
                    capital_by_kingdom[kid] = node.id
            MapNodeModule.TYPE_FORT:
                bundle["forts"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "edge_id": node.attrs.get("edge_id", null), "crossing_id": node.attrs.get("crossing_id", null), "pair_id": node.attrs.get("pair_id", null)})
            MapNodeModule.TYPE_BRIDGE:
                bundle["crossings"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "type": "bridge", "river_id": node.attrs.get("river_id", null)})
            MapNodeModule.TYPE_FORD:
                bundle["crossings"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "type": "ford", "river_id": node.attrs.get("river_id", null)})
            _:
                pass
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        var length: float = 0.0
        for i in range(edge.polyline.size() - 1):
            length += edge.polyline[i].distance_to(edge.polyline[i + 1])
        var edict: Dictionary = {
            "id": edge.id,
            "a": edge.endpoints[0],
            "b": edge.endpoints[1],
            "class": edge.road_class.capitalize(),
            "length": length,
        }
        if edge.attrs.has("crossing_id"):
            edict["crossing_id"] = edge.attrs["crossing_id"]
        bundle["edges"].append(edict)
    for river in map_data.get("rivers", []):
        var poly: Array = []
        for p in river:
            poly.append([p.x, p.y])
        bundle["rivers"].append({"id": bundle["rivers"].size() + 1, "polyline": poly})
    var regions: Dictionary = map_data.get("regions", {})
    var names: Dictionary = map_data.get("kingdom_names", {})
    for region in regions.values():
        var poly: Array = []
        for p in region.boundary_nodes:
            poly.append([p.x, p.y])
        var kname: String = String(names.get(region.kingdom_id, "Kingdom %d" % region.kingdom_id))
        var cap_id: int = capital_by_kingdom.get(region.kingdom_id, 0)
        bundle["kingdoms"].append({
            "id": region.id,
            "kingdom_id": region.kingdom_id,
            "name": kname,
            "capital_city_id": cap_id,
            "polygon": poly,
        })
    return bundle
