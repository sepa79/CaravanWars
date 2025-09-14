extends RefCounted
class_name MapGenGenerator

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
    var min_villages_per_city: int
    var max_villages_per_city: int
    var village_downgrade_threshold: int

    func _init(
        p_rng_seed: int = 0,
        p_city_count: int = 3,
        p_max_river_count: int = 1,
        p_min_connections: int = 1,
        p_max_connections: int = 3,
        p_min_city_distance: float = 20.0,
        p_max_city_distance: float = 40.0,
        p_crossroad_detour_margin: float = 5.0,
        p_width: float = 100.0,
        p_height: float = 100.0,
        p_kingdom_count: int = 1,
        p_max_forts_per_kingdom: int = 1,
        p_min_villages_per_city: int = 0,
        p_max_villages_per_city: int = 2,
        p_village_downgrade_threshold: int = 1
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
        min_villages_per_city = max(0, p_min_villages_per_city)
        max_villages_per_city = max(min_villages_per_city, p_max_villages_per_city)
        village_downgrade_threshold = max(1, p_village_downgrade_threshold)

var params: MapGenParams
var rng: RandomNumberGenerator

const CityPlacerModule = preload("res://mapgen/CityPlacer.gd")
const RoadNetworkModule = preload("res://mapview/RoadNetwork.gd")
const RiverGeneratorModule: Script = preload("res://mapgen/RiverGenerator.gd")
const RegionGeneratorModule: Script = preload("res://mapgen/RegionGenerator.gd")
const NoiseUtil = preload("res://mapgen/NoiseUtil.gd")
const MapViewNode = preload("res://mapview/MapNode.gd")
const CITY_EDGE_MARGIN: float = 20.0
const VILLAGE_EDGE_MARGIN: float = 5.0

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params
    rng = RandomNumberGenerator.new()
    rng.seed = params.rng_seed

static func sample_village_ring(
    rng: RandomNumberGenerator,
    center: Vector2,
    count: int,
    inner_radius: float = 8.0,
    outer_radius: float = 40.0,
    width: float = 100.0,
    height: float = 100.0
) -> Array[Vector2]:
    var placer := CityPlacerModule.new(rng)
    var result: Array[Vector2] = []
    var attempts: int = 0
    var limit: int = count * 5
    while result.size() < count and attempts < limit:
        var needed: int = count - result.size()
        var samples: Array[Vector2] = placer.place_cities(
            needed,
            inner_radius,
            outer_radius,
            outer_radius * 2.0,
            outer_radius * 2.0
        )
        for p in samples:
            var pos: Vector2 = center + p - Vector2(outer_radius, outer_radius)
            var dist: float = pos.distance_to(center)
            if dist < inner_radius or dist > outer_radius:
                continue
            if pos.x < VILLAGE_EDGE_MARGIN or pos.y < VILLAGE_EDGE_MARGIN or pos.x > width - VILLAGE_EDGE_MARGIN or pos.y > height - VILLAGE_EDGE_MARGIN:
                continue
            var ok: bool = true
            for existing in result:
                if existing.distance_to(pos) < inner_radius:
                    ok = false
                    break
            if ok:
                result.append(pos)
                if result.size() >= count:
                    break
        attempts += 1
    return result

func generate() -> Dictionary:
    var map_data: Dictionary = {
        "width": params.width,
        "height": params.height,
    }
    var width_i: int = int(params.width)
    var height_i: int = int(params.height)
    var noise_seed: int = rng.randi()
    var nutil := NoiseUtil.new()
    var fertility_field: Array = nutil.generate_field(
        nutil.create_simplex(noise_seed, 3),
        width_i,
        height_i,
        0.1
    )
    var roughness_field: Array = nutil.compute_roughness(fertility_field)
    map_data["fertility"] = fertility_field
    map_data["roughness"] = roughness_field
    var city_stage := CityPlacerModule.new(rng)
    var city_info: Dictionary = city_stage.select_city_sites(
        fertility_field,
        params.city_count,
        params.min_city_distance,
        CITY_EDGE_MARGIN
    )
    var cities: Array[Vector2] = city_info.get("cities", [])
    map_data["cities"] = cities
    map_data["capitals"] = city_info.get("capitals", [])
    print("[MapGenerator] placed %s cities" % cities.size())

    var region_stage = RegionGeneratorModule.new()
    var regions: Dictionary = region_stage.generate_regions(cities, params.kingdom_count, params.width, params.height)
    map_data["regions"] = regions
    print("[MapGenerator] generated %s regions" % regions.size())

    var road_stage := RoadNetworkModule.new(rng)
    var roads := road_stage.build_roads(
        cities,
        params.min_connections,
        params.max_connections,
        params.crossroad_detour_margin,
        "roman"
    )
    var nodes: Dictionary = roads.get("nodes", {})
    for idx in map_data.get("capitals", []):
        var nid: int = idx + 1
        var node: MapViewNode = nodes.get(nid) as MapViewNode
        if node != null:
            node.attrs["is_capital"] = true
    road_stage.insert_villages(
        roads,
        params.min_villages_per_city,
        params.max_villages_per_city,
        params.width,
        params.height,
        params.village_downgrade_threshold
    )
    road_stage.insert_border_forts(roads, regions, 10.0, params.max_forts_per_kingdom, params.width, params.height)
    map_data["roads"] = roads

    var river_stage = RiverGeneratorModule.new(rng)
    var rivers: Array = river_stage.generate_rivers(roads, params.max_river_count, params.width, params.height)
    map_data["rivers"] = rivers

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
        "villages": [],
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
            MapViewNode.TYPE_CITY:
                var kid: int = node.attrs.get("kingdom_id", 0)
                var is_cap: bool = node.attrs.get("is_capital", false)
                bundle["cities"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "kingdom_id": kid, "is_capital": is_cap})
                if is_cap:
                    capital_by_kingdom[kid] = node.id
            MapViewNode.TYPE_VILLAGE:
                bundle["villages"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "city_id": node.attrs.get("city_id", 0), "road_node_id": node.attrs.get("road_node_id", 0), "production": node.attrs.get("production", {})})
            MapViewNode.TYPE_FORT:
                bundle["forts"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "edge_id": node.attrs.get("edge_id", null), "crossing_id": node.attrs.get("crossing_id", null), "pair_id": node.attrs.get("pair_id", null)})
            MapViewNode.TYPE_BRIDGE:
                bundle["crossings"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "type": "bridge", "river_id": node.attrs.get("river_id", null)})
            MapViewNode.TYPE_FORD:
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
