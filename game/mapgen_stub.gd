extends RefCounted
class_name MapGenStub

const MapNodeModule: Script = preload("res://mapview/MapNode.gd")
const EdgeModule: Script = preload("res://mapview/Edge.gd")
const RegionModule: Script = preload("res://mapview/Region.gd")

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
        city_count = max(0, p_city_count)
        max_river_count = max(0, p_max_river_count)
        var max_possible: int = min(7, max(1, city_count - 1))
        min_connections = clamp(p_min_connections, 1, max_possible)
        max_connections = clamp(p_max_connections, min_connections, max_possible)
        min_city_distance = min(p_min_city_distance, p_max_city_distance)
        max_city_distance = max(p_min_city_distance, p_max_city_distance)
        crossroad_detour_margin = max(0.0, p_crossroad_detour_margin)
        width = clamp(p_width, 20.0, 500.0)
        height = clamp(p_height, 20.0, 500.0)
        kingdom_count = max(0, p_kingdom_count)
        max_forts_per_kingdom = max(0, p_max_forts_per_kingdom)
        village_count = max(0, p_village_count)
        village_per_city = max(0, p_village_per_city)

var params: MapGenParams

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params

func generate() -> Dictionary:
    return create_map(params)

static func create_map(map_params: MapGenParams) -> Dictionary:
    var map_data: Dictionary = _empty_map(map_params.width, map_params.height)
    map_data["meta"] = {
        "seed": map_params.rng_seed,
        "width": map_params.width,
        "height": map_params.height,
    }
    var cities: Array[Vector2] = _generate_cities(map_params)
    map_data["cities"] = cities
    map_data["kingdom_seeds"] = cities.duplicate()
    if cities.size() > 0:
        map_data["capitals"] = [0]
    var regions: Dictionary = generate_regions(cities, map_params.kingdom_count, map_params.width, map_params.height)
    map_data["regions"] = regions
    return map_data

static func generate_regions(
    cities: Array[Vector2],
    kingdom_count: int,
    width: float,
    height: float
) -> Dictionary:
    var regions: Dictionary = {}
    if kingdom_count <= 0 or width <= 0.0 or height <= 0.0:
        return regions
    var slices: int = clamp(kingdom_count, 1, max(1, cities.size()))
    var slice_width: float = width / float(slices)
    for i in range(slices):
        var x0: float = slice_width * float(i)
        var x1: float = slice_width * float(i + 1)
        var polygon: Array[Vector2] = [
            Vector2(x0, 0.0),
            Vector2(x1, 0.0),
            Vector2(x1, height),
            Vector2(x0, height),
        ]
        var region = RegionModule.new(i + 1, polygon, "", i + 1)
        regions[region.id] = region
    return regions

static func validate_map(_roads: Dictionary, _rivers: Array) -> Array[String]:
    return []

static func export_bundle(
    path: String,
    map_data: Dictionary,
    rng_seed: int,
    version: String,
    width: float,
    height: float,
    unit_scale: float = 1.0
) -> void:
    var bundle: Dictionary = {
        "meta": {
            "version": version,
            "seed": rng_seed,
            "width": width,
            "height": height,
            "unit_scale": unit_scale,
        },
        "map": _serialize_map(map_data),
    }
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(bundle, "\t"))
        file.close()

static func load_bundle(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var text := file.get_as_text()
    file.close()
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        return {}
    var bundle: Dictionary = data
    var map_section: Dictionary = bundle.get("map", {})
    var width: float = float(map_section.get("width", 150.0))
    var height: float = float(map_section.get("height", 150.0))
    var map_data: Dictionary = _empty_map(width, height)
    map_data["meta"] = bundle.get("meta", {})
    map_data["cities"] = _parse_points(map_section.get("cities", []))
    map_data["villages"] = _parse_points(map_section.get("villages", []))
    map_data["rivers"] = _parse_polylines(map_section.get("rivers", []))
    map_data["kingdom_names"] = map_section.get("kingdom_names", {})
    map_data["capitals"] = map_section.get("capitals", [])
    map_data["regions"] = _parse_regions(map_section.get("regions", []))
    map_data["roads"] = _parse_roads(map_section.get("roads", {}))
    return map_data

static func _generate_cities(map_params: MapGenParams) -> Array[Vector2]:
    var cities: Array[Vector2] = []
    var count: int = clamp(map_params.city_count, 0, 24)
    if count <= 0:
        return cities
    var center := Vector2(map_params.width * 0.5, map_params.height * 0.5)
    if count == 1:
        cities.append(center)
        return cities
    var radius: float = min(map_params.width, map_params.height) * 0.35
    if radius <= 0.0:
        radius = 1.0
    for i in range(count):
        var angle: float = TAU * float(i) / float(count)
        var pos := center + Vector2(cos(angle), sin(angle)) * radius
        pos.x = clamp(pos.x, 0.0, map_params.width)
        pos.y = clamp(pos.y, 0.0, map_params.height)
        cities.append(pos)
    return cities

static func _empty_map(width: float, height: float) -> Dictionary:
    return {
        "width": width,
        "height": height,
        "fertility": [],
        "roughness": [],
        "biomes": [],
        "rivers": [],
        "cities": [],
        "villages": [],
        "forts": [],
        "roads": _empty_roads(),
        "regions": {},
        "kingdom_seeds": [],
        "kingdom_names": {},
        "capitals": [],
    }

static func _empty_roads() -> Dictionary:
    return {
        "nodes": {},
        "edges": {},
        "next_node_id": 1,
        "next_edge_id": 1,
    }

static func _serialize_map(map_data: Dictionary) -> Dictionary:
    return {
        "width": map_data.get("width", 0.0),
        "height": map_data.get("height", 0.0),
        "cities": _serialize_points(map_data.get("cities", [])),
        "villages": _serialize_points(map_data.get("villages", [])),
        "rivers": _serialize_polylines(map_data.get("rivers", [])),
        "kingdom_names": map_data.get("kingdom_names", {}),
        "capitals": map_data.get("capitals", []),
        "regions": _serialize_regions(map_data.get("regions", {})),
        "roads": _serialize_roads(map_data.get("roads", {})),
    }

static func _serialize_points(points: Array) -> Array:
    var result: Array = []
    for point in points:
        if typeof(point) == TYPE_VECTOR2:
            var vec: Vector2 = point
            result.append([vec.x, vec.y])
    return result

static func _serialize_polylines(polylines: Array) -> Array:
    var result: Array = []
    for polyline in polylines:
        if polyline is Array:
            var pts: Array = []
            for p in polyline:
                if typeof(p) == TYPE_VECTOR2:
                    var vec: Vector2 = p
                    pts.append([vec.x, vec.y])
            result.append(pts)
    return result

static func _serialize_regions(regions: Dictionary) -> Array:
    var result: Array = []
    for region in regions.values():
        if region != null and region.has_method("to_dict"):
            result.append(region.to_dict())
    return result

static func _serialize_roads(roads: Dictionary) -> Dictionary:
    var serialized_nodes: Array = []
    var serialized_edges: Array = []
    var nodes: Dictionary = roads.get("nodes", {})
    for node in nodes.values():
        if node != null and node.has_method("to_dict"):
            serialized_nodes.append(node.to_dict())
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        if edge != null and edge.has_method("to_dict"):
            serialized_edges.append(edge.to_dict())
    return {
        "nodes": serialized_nodes,
        "edges": serialized_edges,
        "next_node_id": roads.get("next_node_id", 1),
        "next_edge_id": roads.get("next_edge_id", 1),
    }

static func _parse_points(points: Array) -> Array[Vector2]:
    var result: Array[Vector2] = []
    for value in points:
        if value is Array and value.size() >= 2:
            result.append(Vector2(float(value[0]), float(value[1])))
    return result

static func _parse_polylines(polylines: Array) -> Array:
    var result: Array = []
    for polyline in polylines:
        if polyline is Array:
            var pts: Array[Vector2] = []
            for p in polyline:
                if p is Array and p.size() >= 2:
                    pts.append(Vector2(float(p[0]), float(p[1])))
            result.append(pts)
    return result

static func _parse_regions(regions: Array) -> Dictionary:
    var result: Dictionary = {}
    for entry in regions:
        if entry is Dictionary:
            var rid: int = int(entry.get("id", result.size() + 1))
            var points: Array = entry.get("boundary_nodes", [])
            var poly: Array[Vector2] = _parse_points(points)
            var region = RegionModule.new(
                rid,
                poly,
                String(entry.get("narrator", "")),
                int(entry.get("kingdom_id", rid))
            )
            result[region.id] = region
    return result

static func _parse_roads(roads: Dictionary) -> Dictionary:
    if roads.is_empty():
        return _empty_roads()
    var node_dict: Dictionary = {}
    for node_entry in roads.get("nodes", []):
        if node_entry is Dictionary:
            var nid: int = int(node_entry.get("id", node_dict.size() + 1))
            var pos_data = node_entry.get("pos2d", [0.0, 0.0])
            var pos := Vector2.ZERO
            if pos_data is Array and pos_data.size() >= 2:
                pos = Vector2(float(pos_data[0]), float(pos_data[1]))
            var ntype: String = String(node_entry.get("type", MapNodeModule.TYPE_CROSSROAD))
            var attrs: Dictionary = node_entry.get("attrs", {})
            node_dict[nid] = MapNodeModule.new(nid, ntype, pos, attrs)
    var edge_dict: Dictionary = {}
    for edge_entry in roads.get("edges", []):
        if edge_entry is Dictionary:
            var eid: int = int(edge_entry.get("id", edge_dict.size() + 1))
            var pts: Array[Vector2] = []
            for p in edge_entry.get("polyline", []):
                if p is Array and p.size() >= 2:
                    pts.append(Vector2(float(p[0]), float(p[1])))
            var endpoints: Array[int] = []
            for endpoint in edge_entry.get("endpoints", []):
                endpoints.append(int(endpoint))
            if endpoints.size() != 2:
                continue
            var road_class: String = String(edge_entry.get("class", "road"))
            var attrs: Dictionary = edge_entry.get("attrs", {})
            edge_dict[eid] = EdgeModule.new(eid, "road", pts, endpoints, road_class, attrs)
    return {
        "nodes": node_dict,
        "edges": edge_dict,
        "next_node_id": int(roads.get("next_node_id", node_dict.size() + 1)),
        "next_edge_id": int(roads.get("next_edge_id", edge_dict.size() + 1)),
    }
