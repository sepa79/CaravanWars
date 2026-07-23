class_name DebugMapModel
extends RefCounted

const MODE_TRUTH: String = "truth"
const MODE_PARTY: String = "party"
const REGION_MAP_MIN: Vector2 = Vector2(40, 34)
const REGION_MAP_SIZE: Vector2 = Vector2(620, 350)

var nodes_by_id: Dictionary[String, Dictionary] = {}
var edges_by_id: Dictionary[String, Dictionary] = {}
var terrain_areas_by_id: Dictionary[String, Dictionary] = {}
var landmarks_by_id: Dictionary[String, Dictionary] = {}
var edges: Array[Dictionary] = []
var rivers: Array[Dictionary] = []
var map_nodes: Dictionary[String, Dictionary] = {}
var map_edges: Dictionary[String, Dictionary] = {}
var map_terrain_areas: Dictionary[String, Dictionary] = {}
var map_landmarks: Dictionary[String, Dictionary] = {}
var map_rivers: Dictionary[String, Dictionary] = {}
var current_node_id: String = ""
var selected_party_id: String = ""
var map_mode: String = MODE_PARTY


func rebuild_from_server(server: RefCounted, party_id: String, mode: String) -> void:
    selected_party_id = party_id
    map_mode = mode
    _load_truth_graph(server.state.region_graph)
    map_nodes.clear()
    map_edges.clear()
    map_terrain_areas.clear()
    map_landmarks.clear()
    map_rivers.clear()

    if map_mode == MODE_TRUTH:
        _build_truth_map()
    else:
        _build_party_map(server, party_id)


func _load_truth_graph(region_graph: RefCounted) -> void:
    nodes_by_id.clear()
    edges_by_id.clear()
    terrain_areas_by_id.clear()
    landmarks_by_id.clear()
    edges.clear()
    rivers.clear()

    var bounds: Rect2 = _region_graph_bounds(region_graph)
    for node: RefCounted in region_graph.nodes_by_id.values():
        nodes_by_id[node.id] = {
            "id": node.id,
            "name": node.display_name,
            "kind": _map_node_kind(node.kind),
            "position": _region_map_position(node.position, bounds)
        }

    for edge: RefCounted in region_graph.edges_by_id.values():
        var route_points: PackedVector2Array = PackedVector2Array()
        for waypoint: RefCounted in edge.route_waypoints:
            route_points.append(_region_map_position(waypoint.position, bounds))
        edges_by_id[edge.id] = {
            "id": edge.id,
            "from": edge.origin_node_id,
            "to": edge.target_node_id,
            "kind": edge.kind,
            "route_points": route_points
        }
        edges.append(edges_by_id[edge.id])

    for area: RefCounted in region_graph.terrain_areas_by_id.values():
        terrain_areas_by_id[area.id] = _terrain_area_dictionary(area, bounds)

    for landmark: RefCounted in region_graph.landmarks_by_id.values():
        landmarks_by_id[landmark.id] = {
            "id": landmark.id,
            "name": landmark.display_name,
            "kind": _map_landmark_kind(landmark.kind),
            "position": _region_map_position(landmark.position, bounds)
        }


func _build_truth_map() -> void:
    for area_id: String in terrain_areas_by_id.keys():
        map_terrain_areas[area_id] = terrain_areas_by_id[area_id].duplicate(true)

    for node_id: String in nodes_by_id.keys():
        _add_map_node(node_id, "truth")

    for edge_id: String in edges_by_id.keys():
        _add_map_edge(edge_id, "truth")

    for landmark_id: String in landmarks_by_id.keys():
        _add_map_landmark(landmark_id, "truth")


func _build_party_map(server: RefCounted, party_id: String) -> void:
    var client_snapshot: Dictionary = server.get_client_snapshot(party_id)
    var party: Dictionary = client_snapshot.get("party", {})
    current_node_id = str(party.get("current_node_id", ""))
    var known_nodes: Variant = client_snapshot.get("known_nodes", [])
    if typeof(known_nodes) == TYPE_ARRAY:
        for node_value: Variant in known_nodes:
            if typeof(node_value) == TYPE_DICTIONARY:
                _add_map_node(str(node_value.get("node_id", "")), "known")

    var known_routes: Variant = client_snapshot.get("known_routes", [])
    if typeof(known_routes) == TYPE_ARRAY:
        for route_value: Variant in known_routes:
            if typeof(route_value) == TYPE_DICTIONARY:
                _add_map_edge(str(route_value.get("edge_id", "")), "known")

    for event_dictionary: Dictionary in server.get_recent_events(200):
        if str(event_dictionary.get("event_type", "")) != "worldsim_route_waypoint_observed":
            continue
        if str(event_dictionary.get("party_id", "")) != party_id:
            continue

        var details: Dictionary = event_dictionary.get("details", {})
        _add_map_edge(str(details.get("edge_id", "")), "observed")
        for landmark_id: String in _string_array_from_variant(details.get("landmark_ids", [])):
            _add_map_landmark(landmark_id, "observed")
        for area_id: String in _string_array_from_variant(details.get("terrain_area_ids", [])):
            _add_map_terrain_area(area_id, "observed")


func _add_map_node(node_id: String, source: String) -> void:
    if node_id.is_empty() or not nodes_by_id.has(node_id):
        return

    var node: Dictionary = nodes_by_id[node_id]
    map_nodes[node_id] = {
        "id": node_id,
        "name": str(node.get("name", node_id)),
        "kind": str(node.get("kind", "unknown")),
        "position": _map_position_for_source(node_id, node.get("position", Vector2.ZERO), source),
        "map_pos": _map_position_for_source(node_id, node.get("position", Vector2.ZERO), source),
        "label": str(node.get("name", node_id)),
        "variant": abs(hash("%s:%s" % [node_id, source])) % 4,
        "source": source
    }


func _add_map_edge(edge_id: String, source: String) -> void:
    if edge_id.is_empty() or not edges_by_id.has(edge_id):
        return

    var edge: Dictionary = edges_by_id[edge_id]
    var from_id: String = str(edge.get("from", ""))
    var to_id: String = str(edge.get("to", ""))
    _add_map_node(from_id, source)
    _add_map_node(to_id, source)

    var path: PackedVector2Array = PackedVector2Array()
    path.append(map_nodes[from_id].get("position", Vector2.ZERO))
    for index: int in range(0, edge.get("route_points", PackedVector2Array()).size()):
        var route_point: Vector2 = edge.get("route_points", PackedVector2Array())[index]
        path.append(_map_position_for_source("%s:%d" % [edge_id, index], route_point, source))
    path.append(map_nodes[to_id].get("position", Vector2.ZERO))

    map_edges[edge_id] = {
        "id": edge_id,
        "from": from_id,
        "to": to_id,
        "kind": str(edge.get("kind", "route")),
        "path": path,
        "source": source
    }


func _add_map_landmark(landmark_id: String, source: String) -> void:
    if landmark_id.is_empty() or not landmarks_by_id.has(landmark_id):
        return

    var landmark: Dictionary = landmarks_by_id[landmark_id]
    map_landmarks[landmark_id] = {
        "id": landmark_id,
        "name": str(landmark.get("name", landmark_id)),
        "kind": str(landmark.get("kind", "landmark")),
        "position": _map_position_for_source(landmark_id, landmark.get("position", Vector2.ZERO), source),
        "map_pos": _map_position_for_source(landmark_id, landmark.get("position", Vector2.ZERO), source),
        "label": str(landmark.get("name", landmark_id)),
        "variant": abs(hash("%s:%s" % [landmark_id, source])) % 4,
        "source": source
    }


func _add_map_terrain_area(area_id: String, source: String) -> void:
    if area_id.is_empty() or not terrain_areas_by_id.has(area_id):
        return

    var area: Dictionary = terrain_areas_by_id[area_id]
    var map_area: Dictionary = area.duplicate(true)
    map_area["source"] = source
    if str(area.get("shape", "polygon")) == "ellipse":
        map_area["center"] = _map_position_for_source(area_id, area.get("center", Vector2.ZERO), source)
    else:
        var points: Array[Vector2] = []
        var source_points: Array = area.get("points", [])
        for index: int in range(0, source_points.size()):
            points.append(_map_position_for_source("%s:%d" % [area_id, index], source_points[index], source))
        map_area["points"] = points
    map_terrain_areas[area_id] = map_area


func _terrain_area_dictionary(area: RefCounted, bounds: Rect2) -> Dictionary:
    var area_dictionary: Dictionary = {
        "id": area.id,
        "name": area.display_name,
        "kind": area.kind,
        "shape": area.shape
    }
    if area.shape == "ellipse":
        area_dictionary["center"] = _region_map_position(area.center, bounds)
        area_dictionary["radius"] = Vector2(
            area.radius.x / bounds.size.x * REGION_MAP_SIZE.x,
            area.radius.y / bounds.size.y * REGION_MAP_SIZE.y
        )
    else:
        var points: Array[Vector2] = []
        for point: Vector2 in area.polygon:
            points.append(_region_map_position(point, bounds))
        area_dictionary["points"] = points
    return area_dictionary


func _region_graph_bounds(region_graph: RefCounted) -> Rect2:
    var has_position: bool = false
    var min_pos: Vector2 = Vector2.ZERO
    var max_pos: Vector2 = Vector2.ZERO
    for node: RefCounted in region_graph.nodes_by_id.values():
        if not has_position:
            min_pos = node.position
            max_pos = node.position
            has_position = true
        else:
            min_pos = min_pos.min(node.position)
            max_pos = max_pos.max(node.position)

    if not has_position:
        return Rect2(Vector2.ZERO, Vector2.ONE)

    var bounds_size: Vector2 = max_pos - min_pos
    if bounds_size.x < 1.0:
        bounds_size.x = 1.0
    if bounds_size.y < 1.0:
        bounds_size.y = 1.0
    return Rect2(min_pos, bounds_size)


func _region_map_position(raw_pos: Vector2, bounds: Rect2) -> Vector2:
    var normalized: Vector2 = Vector2(
        (raw_pos.x - bounds.position.x) / bounds.size.x,
        (raw_pos.y - bounds.position.y) / bounds.size.y
    )
    return REGION_MAP_MIN + normalized * REGION_MAP_SIZE


func _map_position_for_source(object_id: String, true_pos: Vector2, source: String) -> Vector2:
    if source == "truth":
        return true_pos
    return true_pos + _stable_offset(object_id, source)


func _stable_offset(object_id: String, source: String) -> Vector2:
    var seed_value: int = abs(hash("%s:%s:debug_map" % [object_id, source]))
    var angle: float = float(seed_value % 6283) / 1000.0
    var radius: float = 18.0
    if source == "observed":
        radius = 10.0
    var variance: float = float((seed_value / 17) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.55 + variance))


func _map_node_kind(raw_kind: String) -> String:
    match raw_kind:
        "major_city", "regional_stronghold":
            return "town"
        "monastery":
            return "town"
        "mountain_pass":
            return "hill"
        "river_crossing":
            return "ford"
        "wilderness":
            return "camp"
        _:
            return "village"


func _map_landmark_kind(raw_kind: String) -> String:
    match raw_kind:
        "ford", "bridge", "hill", "tree", "shrine", "ruin", "stone":
            return raw_kind
        "river_bend":
            return "ford"
        _:
            return "landmark"


func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
