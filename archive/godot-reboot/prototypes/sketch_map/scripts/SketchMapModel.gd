class_name SketchMapModel
extends RefCounted

const MAIN_REGION_GRAPH_PATH: String = "res://../../game/data/regions/silesia.json"
const FALLBACK_GRAPH_PATH: String = "res://data/demo_graph.json"
const REGION_MAP_MIN: Vector2 = Vector2(120, 90)
const REGION_MAP_SIZE: Vector2 = Vector2(980, 560)

var nodes_by_id: Dictionary = {}
var edges: Array[Dictionary] = []
var rivers: Array[Dictionary] = []
var terrain_areas_by_id: Dictionary = {}
var landmarks_by_id: Dictionary = {}
var map_nodes: Dictionary = {}
var map_edges: Dictionary = {}
var map_rivers: Dictionary = {}
var map_terrain_areas: Dictionary = {}
var map_landmarks: Dictionary = {}
var erased_nodes: Array[Dictionary] = []
var erased_edges: Array[Dictionary] = []
var erased_rivers: Array[Dictionary] = []
var bought_map_nodes: Dictionary = {}
var bought_map_edges: Dictionary = {}
var bought_map_rivers: Dictionary = {}
var bought_map_quality: float = -1.0
var copied_map_count: int = 0
var redraw_existing_marks: bool = false
var notes: Array[Dictionary] = []
var current_node_id: String = ""


func load_demo_graph() -> void:
    var parsed: Dictionary = _load_graph_json(MAIN_REGION_GRAPH_PATH)
    if parsed.is_empty():
        parsed = _load_graph_json(FALLBACK_GRAPH_PATH)
    if parsed.is_empty():
        push_error("Could not load any sketch map graph.")
        return

    nodes_by_id.clear()
    edges.clear()
    rivers.clear()
    terrain_areas_by_id.clear()
    landmarks_by_id.clear()
    map_nodes.clear()
    map_edges.clear()
    map_rivers.clear()
    map_terrain_areas.clear()
    map_landmarks.clear()
    erased_nodes.clear()
    erased_edges.clear()
    erased_rivers.clear()
    bought_map_nodes.clear()
    bought_map_edges.clear()
    bought_map_rivers.clear()
    bought_map_quality = -1.0
    copied_map_count = 0
    redraw_existing_marks = false
    notes.clear()

    if _is_region_graph(parsed):
        _load_region_graph(parsed)
    else:
        _load_legacy_demo_graph(parsed)

    if nodes_by_id.has("wroclaw"):
        current_node_id = "wroclaw"
    elif nodes_by_id.has("wroclaw_gate_inn"):
        current_node_id = "wroclaw_gate_inn"
    elif not nodes_by_id.is_empty():
        current_node_id = str(nodes_by_id.keys()[0])

    discover_node(current_node_id, "visited")
    discover_nearby(current_node_id, "seen")
    reveal_rivers_near(current_node_id)
    reveal_physical_layers_near(current_node_id, "seen")


func _load_graph_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        file = FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
    if file == null:
        push_warning("Could not open graph path: %s" % path)
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Graph is not a dictionary: %s" % path)
        return {}
    return parsed


func _is_region_graph(parsed: Dictionary) -> bool:
    return parsed.has("display_name") and str(parsed.get("id", "")) != "demo_sketch_map"


func _load_legacy_demo_graph(parsed: Dictionary) -> void:
    for node_value: Variant in parsed.get("nodes", []):
        if typeof(node_value) == TYPE_DICTIONARY:
            var node: Dictionary = node_value
            nodes_by_id[str(node.get("id", ""))] = node

    for edge_value: Variant in parsed.get("edges", []):
        if typeof(edge_value) == TYPE_DICTIONARY:
            edges.append(edge_value)

    for river_value: Variant in parsed.get("rivers", []):
        if typeof(river_value) == TYPE_DICTIONARY:
            rivers.append(river_value)


func _load_region_graph(parsed: Dictionary) -> void:
    var node_values: Array = parsed.get("nodes", [])
    var bounds: Rect2 = _region_graph_bounds(node_values)

    for node_value: Variant in node_values:
        if typeof(node_value) != TYPE_DICTIONARY:
            continue

        var source_node: Dictionary = node_value
        var node_id: String = str(source_node.get("id", ""))
        if node_id.is_empty():
            continue

        var raw_kind: String = str(source_node.get("kind", "unknown"))
        var node: Dictionary = {
            "id": node_id,
            "name": str(source_node.get("display_name", node_id)),
            "kind": _map_region_kind(raw_kind),
            "raw_kind": raw_kind,
            "notes": str(source_node.get("notes", "")),
            "position": _region_map_position(_array_to_vec2(source_node.get("position", [0, 0])), bounds)
        }
        nodes_by_id[node_id] = node

    for edge_value: Variant in parsed.get("edges", []):
        if typeof(edge_value) != TYPE_DICTIONARY:
            continue

        var source_edge: Dictionary = edge_value
        var from_id: String = str(source_edge.get("from", ""))
        var to_id: String = str(source_edge.get("to", ""))
        if not nodes_by_id.has(from_id) or not nodes_by_id.has(to_id):
            continue

        var edge_id: String = str(source_edge.get("id", "%s_%s" % [from_id, to_id]))
        edges.append({
            "id": edge_id,
            "from": from_id,
            "to": to_id,
            "kind": str(source_edge.get("kind", "road")),
            "distance_km": float(source_edge.get("distance_km", 0.0)),
            "route_points": _region_route_points(source_edge, bounds)
        })

    for area_value: Variant in parsed.get("terrain_areas", []):
        if typeof(area_value) == TYPE_DICTIONARY:
            _load_region_terrain_area(area_value, bounds)

    for landmark_value: Variant in parsed.get("landmarks", []):
        if typeof(landmark_value) == TYPE_DICTIONARY:
            _load_region_landmark(landmark_value, bounds)

    _add_region_terrain(parsed)


func _load_region_terrain_area(source_area: Dictionary, bounds: Rect2) -> void:
    var area_id: String = str(source_area.get("id", ""))
    if area_id.is_empty():
        return

    var shape: String = str(source_area.get("shape", "polygon"))
    var area: Dictionary = {
        "id": area_id,
        "name": str(source_area.get("display_name", area_id)),
        "kind": str(source_area.get("kind", "unknown")),
        "shape": shape,
        "notes": str(source_area.get("notes", ""))
    }

    if shape == "ellipse":
        var center: Vector2 = _region_map_position(_array_to_vec2(source_area.get("center", [0, 0])), bounds)
        var raw_radius: Vector2 = _array_to_vec2(source_area.get("radius", [1, 1]))
        var radius: Vector2 = Vector2(
            raw_radius.x / bounds.size.x * REGION_MAP_SIZE.x,
            raw_radius.y / bounds.size.y * REGION_MAP_SIZE.y
        )
        area["center"] = center
        area["radius"] = radius
    else:
        var points: Array[Vector2] = []
        for point_value: Variant in source_area.get("polygon", []):
            points.append(_region_map_position(_array_to_vec2(point_value), bounds))
        area["points"] = points

    terrain_areas_by_id[area_id] = area


func _load_region_landmark(source_landmark: Dictionary, bounds: Rect2) -> void:
    var landmark_id: String = str(source_landmark.get("id", ""))
    if landmark_id.is_empty():
        return

    landmarks_by_id[landmark_id] = {
        "id": landmark_id,
        "name": str(source_landmark.get("display_name", landmark_id)),
        "kind": _map_landmark_kind(str(source_landmark.get("kind", "unknown"))),
        "raw_kind": str(source_landmark.get("kind", "unknown")),
        "position": _region_map_position(_array_to_vec2(source_landmark.get("position", [0, 0])), bounds),
        "elevation_m": float(source_landmark.get("elevation_m", 0.0)),
        "visibility_class": str(source_landmark.get("visibility_class", "local")),
        "notes": str(source_landmark.get("notes", ""))
    }


func _region_route_points(source_edge: Dictionary, bounds: Rect2) -> Array[Vector2]:
    var route_points: Array[Vector2] = []
    var geometry: Variant = source_edge.get("geometry", [])
    if typeof(geometry) != TYPE_ARRAY:
        return route_points

    for waypoint_value: Variant in geometry:
        if typeof(waypoint_value) != TYPE_DICTIONARY:
            continue

        var waypoint: Dictionary = waypoint_value
        route_points.append(_region_map_position(_array_to_vec2(waypoint.get("position", [0, 0])), bounds))
    return route_points


func _region_graph_bounds(node_values: Array) -> Rect2:
    var has_position: bool = false
    var min_pos: Vector2 = Vector2.ZERO
    var max_pos: Vector2 = Vector2.ZERO
    for node_value: Variant in node_values:
        if typeof(node_value) != TYPE_DICTIONARY:
            continue
        var node: Dictionary = node_value
        var pos: Vector2 = _array_to_vec2(node.get("position", [0, 0]))
        if not has_position:
            min_pos = pos
            max_pos = pos
            has_position = true
        else:
            min_pos = min_pos.min(pos)
            max_pos = max_pos.max(pos)

    if not has_position:
        return Rect2(Vector2.ZERO, Vector2.ONE)
    var size: Vector2 = max_pos - min_pos
    if size.x < 1.0:
        size.x = 1.0
    if size.y < 1.0:
        size.y = 1.0
    return Rect2(min_pos, size)


func _region_map_position(raw_pos: Vector2, bounds: Rect2) -> Vector2:
    var normalized: Vector2 = Vector2(
        (raw_pos.x - bounds.position.x) / bounds.size.x,
        (raw_pos.y - bounds.position.y) / bounds.size.y
    )
    return REGION_MAP_MIN + normalized * REGION_MAP_SIZE


func _map_region_kind(raw_kind: String) -> String:
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
        "river_bend":
            return "ford"
        "ford", "bridge", "hill", "tree", "shrine", "ruin", "stone":
            return raw_kind
        _:
            return "landmark"


func _add_region_terrain(parsed: Dictionary) -> void:
    if str(parsed.get("id", "")) != "silesia":
        return

    var river_node_ids: Array[String] = ["glogow", "wroclaw", "odra_crossing", "opole", "raciborz"]
    var points: Array = []
    for node_id: String in river_node_ids:
        if nodes_by_id.has(node_id):
            points.append(nodes_by_id[node_id].get("position", [0, 0]))

    if points.size() >= 2:
        rivers.append({
            "id": "odra_hint",
            "name": "Odra",
            "points": points,
            "visible_near": river_node_ids
        })


func travel_to(node_id: String) -> bool:
    if not nodes_by_id.has(node_id):
        return false
    if not _has_known_or_true_edge(current_node_id, node_id):
        return false

    discover_node(node_id, "visited")
    discover_edge_between(current_node_id, node_id, "visited")
    current_node_id = node_id
    discover_nearby(node_id, "seen")
    reveal_rivers_near(node_id)
    reveal_physical_layers_near(node_id, "seen")
    notes.append({
        "text": "Road note: travelled to %s." % str(nodes_by_id[node_id].get("name", node_id)),
        "node_id": node_id,
        "source": "visited"
    })
    return true


func reveal_from_hill() -> void:
    var current_node: Dictionary = nodes_by_id.get(current_node_id, {})
    var current_kind: String = str(current_node.get("kind", "unknown"))
    var current_raw_kind: String = str(current_node.get("raw_kind", current_kind))
    if current_kind != "hill" and current_raw_kind != "mountain_pass" and current_raw_kind != "wilderness":
        notes.append({
            "text": "Need a high place to draw beyond the road.",
            "node_id": current_node_id,
            "source": "system"
        })
        return

    var revealed: Array[String] = _nearest_undiscovered_nodes(current_node_id, 3)
    for node_id: String in revealed:
        discover_node(node_id, "seen")
    reveal_distant_landmarks(current_node_id)
    notes.append({
        "text": "From high ground: rough marks added for %d distant place(s)." % revealed.size(),
        "node_id": current_node_id,
        "source": "seen"
    })


func add_tavern_rumor() -> void:
    var target_id: String = "opole" if nodes_by_id.has("opole") else _first_undiscovered_node()
    if target_id.is_empty():
        notes.append({
            "text": "Tavern rumor: nothing new worth adding.",
            "node_id": current_node_id,
            "source": "heard"
        })
        return

    discover_node(target_id, "heard")
    if _has_known_or_true_edge(current_node_id, target_id):
        discover_edge_between(current_node_id, target_id, "heard")
    notes.append({
        "text": "Tavern rumor: someone argues the road toward %s is worth marking." % str(nodes_by_id[target_id].get("name", target_id)),
        "node_id": target_id,
        "source": "heard"
    })


func buy_regional_map() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.randomize()
    bought_map_quality = snappedf(rng.randf_range(0.28, 0.88), 0.01)
    bought_map_nodes.clear()
    bought_map_edges.clear()
    bought_map_rivers.clear()

    var include_chance: float = lerpf(0.48, 0.98, bought_map_quality)
    for node_id: String in nodes_by_id.keys():
        if node_id == current_node_id or rng.randf() <= include_chance:
            _add_bought_node(node_id)

    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if not bought_map_nodes.has(from_id) or not bought_map_nodes.has(to_id):
            continue

        var edge_chance: float = lerpf(0.55, 1.0, bought_map_quality)
        if rng.randf() > edge_chance:
            continue

        var edge_id: String = str(edge.get("id", "%s_%s" % [from_id, to_id]))
        bought_map_edges[edge_id] = {
            "id": edge_id,
            "from": from_id,
            "to": to_id,
            "kind": str(edge.get("kind", "road")),
            "source": "bought",
            "medium": "charcoal",
            "status": "unverified",
            "path": _bought_edge_path(from_id, to_id, edge_id)
        }

    for river: Dictionary in rivers:
        var river_id: String = str(river.get("id", "river"))
        var points: Array[Vector2] = []
        for point_value: Variant in river.get("points", []):
            points.append(_bought_river_map_point(_array_to_vec2(point_value), river, river_id))
        if points.size() >= 2:
            bought_map_rivers[river_id] = {
                "id": river_id,
                "points": points,
                "source": "bought",
                "medium": "charcoal",
                "status": "unverified"
            }

    notes.append({
        "text": "Bought regional map. Seller quality estimate: %d%%." % int(round(bought_map_quality * 100.0)),
        "node_id": current_node_id,
        "source": "bought"
    })


func copy_bought_map_to_player() -> void:
    if bought_map_quality < 0.0:
        notes.append({
            "text": "No bought map to copy from.",
            "node_id": current_node_id,
            "source": "system"
        })
        return

    copied_map_count += 1
    var copied_nodes: int = 0
    var copied_edges: int = 0
    var copied_rivers: int = 0

    for node_id: String in bought_map_nodes.keys():
        if map_nodes.has(node_id):
            continue

        var bought_node: Dictionary = bought_map_nodes[node_id]
        var copied_pos: Vector2 = bought_node.get("map_pos", Vector2.ZERO) + _copy_offset(node_id)
        map_nodes[node_id] = {
            "id": node_id,
            "name": str(bought_node.get("name", node_id)),
            "kind": str(bought_node.get("kind", "unknown")),
            "true_pos": bought_node.get("true_pos", copied_pos),
            "map_pos": copied_pos,
            "source": "copied",
            "medium": "charcoal",
            "status": "unverified",
            "accuracy": _copied_accuracy(),
            "label": "%s*" % str(bought_node.get("label", node_id)),
            "variant": abs(hash("%s:copied:%d" % [node_id, copied_map_count])) % 4
        }
        copied_nodes += 1

    for edge_id: String in bought_map_edges.keys():
        if map_edges.has(edge_id):
            continue

        var bought_edge: Dictionary = bought_map_edges[edge_id]
        var from_id: String = str(bought_edge.get("from", ""))
        var to_id: String = str(bought_edge.get("to", ""))
        if not map_nodes.has(from_id) or not map_nodes.has(to_id):
            continue

        map_edges[edge_id] = {
            "id": edge_id,
            "from": from_id,
            "to": to_id,
            "kind": str(bought_edge.get("kind", "road")),
            "source": "copied",
            "medium": "charcoal",
            "status": "unverified",
            "accuracy": _copied_accuracy(),
            "path": _copied_edge_path(from_id, to_id, edge_id)
        }
        copied_edges += 1

    for river_id: String in bought_map_rivers.keys():
        if map_rivers.has(river_id):
            continue

        var bought_river: Dictionary = bought_map_rivers[river_id]
        var points: Array[Vector2] = []
        for i: int in range(0, bought_river.get("points", []).size()):
            var point: Vector2 = bought_river.get("points", [])[i]
            points.append(_copied_river_point(point, river_id, i))

        if points.size() >= 2:
            map_rivers[river_id] = {
                "id": river_id,
                "points": points,
                "source": "copied",
                "medium": "charcoal",
                "status": "unverified"
            }
            copied_rivers += 1

    notes.append({
        "text": "Copied from bought map: %d places, %d roads, %d river fragments. Copy accuracy: %d%%." % [copied_nodes, copied_edges, copied_rivers, int(round(_copied_accuracy() * 100.0))],
        "node_id": current_node_id,
        "source": "copied"
    })


func discover_nearby(node_id: String, source: String) -> void:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if from_id == node_id:
            discover_node(to_id, source)
            discover_edge_between(from_id, to_id, source)
        elif to_id == node_id:
            discover_node(from_id, source)
            discover_edge_between(from_id, to_id, source)


func reveal_physical_layers_near(node_id: String, source: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    var node_pos: Vector2 = _array_to_vec2(nodes_by_id[node_id].get("position", [0, 0]))
    for landmark_id: String in landmarks_by_id.keys():
        var landmark: Dictionary = landmarks_by_id[landmark_id]
        var landmark_pos: Vector2 = _array_to_vec2(landmark.get("position", [0, 0]))
        var reveal_distance: float = 190.0 if str(landmark.get("visibility_class", "")) == "major" else 105.0
        if landmark_pos.distance_to(node_pos) <= reveal_distance:
            discover_landmark(landmark_id, source)

    for area_id: String in terrain_areas_by_id.keys():
        var area: Dictionary = terrain_areas_by_id[area_id]
        if _terrain_area_near(area, node_pos, 130.0):
            discover_terrain_area(area_id, source)


func reveal_distant_landmarks(node_id: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    var node_pos: Vector2 = _array_to_vec2(nodes_by_id[node_id].get("position", [0, 0]))
    for landmark_id: String in landmarks_by_id.keys():
        var landmark: Dictionary = landmarks_by_id[landmark_id]
        if str(landmark.get("visibility_class", "")) != "major":
            continue

        var landmark_pos: Vector2 = _array_to_vec2(landmark.get("position", [0, 0]))
        if landmark_pos.distance_to(node_pos) <= 430.0:
            discover_landmark(landmark_id, "seen")


func discover_landmark(landmark_id: String, source: String) -> void:
    if not landmarks_by_id.has(landmark_id):
        return

    if map_landmarks.has(landmark_id):
        var existing: Dictionary = map_landmarks[landmark_id]
        if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
            existing["source"] = source
            existing["medium"] = _medium_for_source(source)
            existing["status"] = _status_for_source(source)
            existing["accuracy"] = _accuracy_for_source(source)
            existing["label"] = _label_for_landmark(landmarks_by_id[landmark_id], source)
            map_landmarks[landmark_id] = existing
        return

    var landmark: Dictionary = landmarks_by_id[landmark_id]
    var true_pos: Vector2 = _array_to_vec2(landmark.get("position", [0, 0]))
    map_landmarks[landmark_id] = {
        "id": landmark_id,
        "name": str(landmark.get("name", landmark_id)),
        "kind": str(landmark.get("kind", "landmark")),
        "true_pos": true_pos,
        "map_pos": true_pos + _stable_offset(landmark_id, source),
        "source": source,
        "medium": _medium_for_source(source),
        "status": _status_for_source(source),
        "accuracy": _accuracy_for_source(source),
        "label": _label_for_landmark(landmark, source),
        "variant": abs(hash("%s:%s:landmark" % [landmark_id, source])) % 4
    }


func discover_terrain_area(area_id: String, source: String) -> void:
    if not terrain_areas_by_id.has(area_id):
        return

    if map_terrain_areas.has(area_id):
        var existing: Dictionary = map_terrain_areas[area_id]
        if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
            existing["source"] = source
            existing["medium"] = _medium_for_source(source)
            existing["status"] = _status_for_source(source)
            map_terrain_areas[area_id] = existing
        return

    var area: Dictionary = terrain_areas_by_id[area_id]
    var map_area: Dictionary = {
        "id": area_id,
        "name": str(area.get("name", area_id)),
        "kind": str(area.get("kind", "unknown")),
        "shape": str(area.get("shape", "polygon")),
        "source": source,
        "medium": _medium_for_source(source),
        "status": _status_for_source(source)
    }
    if str(area.get("shape", "polygon")) == "ellipse":
        map_area["center"] = _array_to_vec2(area.get("center", [0, 0])) + _stable_offset(area_id, source) * 0.45
        map_area["radius"] = _array_to_vec2(area.get("radius", [1, 1]))
    else:
        var points: Array[Vector2] = []
        for i: int in range(0, area.get("points", []).size()):
            var point: Vector2 = area.get("points", [])[i]
            points.append(point + _stable_offset("%s:%d" % [area_id, i], source) * 0.35)
        map_area["points"] = points
    map_terrain_areas[area_id] = map_area


func _terrain_area_near(area: Dictionary, node_pos: Vector2, max_distance: float) -> bool:
    if str(area.get("shape", "polygon")) == "ellipse":
        var center: Vector2 = _array_to_vec2(area.get("center", [0, 0]))
        var radius: Vector2 = _array_to_vec2(area.get("radius", [0, 0]))
        return center.distance_to(node_pos) <= max_distance + max(radius.x, radius.y)

    for point: Vector2 in area.get("points", []):
        if point.distance_to(node_pos) <= max_distance:
            return true
    return false


func discover_node(node_id: String, source: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    if map_nodes.has(node_id):
        var existing: Dictionary = map_nodes[node_id]
        if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
            var true_pos: Vector2 = _array_to_vec2(nodes_by_id[node_id].get("position", [0, 0]))
            var improved_pos: Vector2 = true_pos + _stable_offset(node_id, source)
            var should_reposition: bool = redraw_existing_marks and _should_reposition_node(existing, nodes_by_id[node_id], improved_pos)
            if should_reposition:
                _erase_node_mark(existing)
            existing["source"] = source
            existing["medium"] = _medium_for_source(source)
            existing["status"] = _status_for_source(source)
            existing["accuracy"] = _accuracy_for_source(source)
            existing["label"] = _label_for_node(nodes_by_id[node_id], source)
            if should_reposition:
                existing["map_pos"] = improved_pos
            existing["variant"] = abs(hash("%s:%s" % [node_id, source])) % 4
            map_nodes[node_id] = existing
        return

    var node: Dictionary = nodes_by_id[node_id]
    var true_pos: Vector2 = _array_to_vec2(node.get("position", [0, 0]))
    map_nodes[node_id] = {
        "id": node_id,
        "name": str(node.get("name", node_id)),
        "kind": str(node.get("kind", "unknown")),
        "true_pos": true_pos,
        "map_pos": true_pos + _stable_offset(node_id, source),
        "source": source,
        "medium": _medium_for_source(source),
        "status": _status_for_source(source),
        "accuracy": _accuracy_for_source(source),
        "label": _label_for_node(node, source),
        "variant": abs(hash("%s:%s" % [node_id, source])) % 4
    }


func discover_edge_between(a_id: String, b_id: String, source: String) -> void:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if (from_id == a_id and to_id == b_id) or (from_id == b_id and to_id == a_id):
            var edge_id: String = str(edge.get("id", "%s_%s" % [a_id, b_id]))
            if map_edges.has(edge_id):
                var existing: Dictionary = map_edges[edge_id]
                if _source_rank(source) > _source_rank(str(existing.get("source", ""))):
                    if redraw_existing_marks:
                        _erase_edge_mark(existing)
                    existing["source"] = source
                    existing["medium"] = _medium_for_source(source)
                    existing["status"] = _status_for_source(source)
                    existing["accuracy"] = _accuracy_for_source(source)
                    if redraw_existing_marks:
                        existing["path"] = _edge_path(from_id, to_id, edge_id, source)
                    map_edges[edge_id] = existing
                return

            discover_node(from_id, source)
            discover_node(to_id, source)
            map_edges[edge_id] = {
                "id": edge_id,
                "from": from_id,
                "to": to_id,
                "kind": str(edge.get("kind", "road")),
                "source": source,
                "medium": _medium_for_source(source),
                "status": _status_for_source(source),
                "accuracy": _accuracy_for_source(source),
                "path": _edge_path(from_id, to_id, edge_id, source)
            }
            return


func reveal_rivers_near(node_id: String) -> void:
    for river: Dictionary in rivers:
        var visible_near: Array = river.get("visible_near", [])
        if visible_near.has(node_id):
            var river_id: String = str(river.get("id", "river"))
            if not map_rivers.has(river_id) or _source_rank(str(map_rivers[river_id].get("source", ""))) < _source_rank("seen"):
                var should_redraw_river: bool = redraw_existing_marks or _river_has_player_anchor(river)
                if map_rivers.has(river_id) and should_redraw_river:
                    _erase_river_mark(map_rivers[river_id])
                elif map_rivers.has(river_id) and not should_redraw_river:
                    var existing: Dictionary = map_rivers[river_id]
                    existing["source"] = "seen"
                    existing["medium"] = _medium_for_source("seen")
                    existing["status"] = _status_for_source("seen")
                    map_rivers[river_id] = existing
                    continue

                var points: Array[Vector2] = []
                for point_value: Variant in river.get("points", []):
                    points.append(_river_map_point(_array_to_vec2(point_value), river, river_id))
                map_rivers[river_id] = {
                    "id": river_id,
                    "points": points,
                    "source": "seen",
                    "medium": _medium_for_source("seen"),
                    "status": _status_for_source("seen")
                }


func get_known_destinations() -> Array[String]:
    var destinations: Array[String] = []
    for edge_id: String in map_edges.keys():
        var edge: Dictionary = map_edges[edge_id]
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if from_id == current_node_id and map_nodes.has(to_id):
            destinations.append(to_id)
        elif to_id == current_node_id and map_nodes.has(from_id):
            destinations.append(from_id)
    destinations.sort()
    return destinations


func _has_known_or_true_edge(a_id: String, b_id: String) -> bool:
    for edge: Dictionary in edges:
        var from_id: String = str(edge.get("from", ""))
        var to_id: String = str(edge.get("to", ""))
        if (from_id == a_id and to_id == b_id) or (from_id == b_id and to_id == a_id):
            return true
    return false


func _nearest_undiscovered_nodes(from_id: String, limit: int) -> Array[String]:
    var result: Array[String] = []
    if not nodes_by_id.has(from_id):
        return result

    var from_pos: Vector2 = _array_to_vec2(nodes_by_id[from_id].get("position", Vector2.ZERO))
    var candidates: Array[Dictionary] = []
    for node_id_value: Variant in nodes_by_id.keys():
        var node_id: String = str(node_id_value)
        if node_id == from_id or map_nodes.has(node_id):
            continue
        var node_pos: Vector2 = _array_to_vec2(nodes_by_id[node_id].get("position", Vector2.ZERO))
        candidates.append({
            "id": node_id,
            "distance": from_pos.distance_to(node_pos)
        })

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
    )

    for candidate: Dictionary in candidates:
        if result.size() >= limit:
            break
        result.append(str(candidate.get("id", "")))
    return result


func _first_undiscovered_node() -> String:
    for node_id_value: Variant in nodes_by_id.keys():
        var node_id: String = str(node_id_value)
        if not map_nodes.has(node_id):
            return node_id
    return ""


func _edge_path(from_id: String, to_id: String, edge_id: String, source: String) -> PackedVector2Array:
    var from_pos: Vector2 = map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = map_nodes[to_id]["map_pos"]
    var edge: Dictionary = _edge_by_id(edge_id)
    var route_points: Array = edge.get("route_points", [])
    if not route_points.is_empty():
        var path: PackedVector2Array = PackedVector2Array()
        path.append(from_pos)
        for i: int in range(0, route_points.size()):
            var route_point: Vector2 = route_points[i]
            path.append(route_point + _stable_offset("%s:route:%d" % [edge_id, i], source) * 0.45)
        path.append(to_pos)
        return path

    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend: float = float((abs(hash(edge_id)) % 80) - 40)
    if source == "heard":
        bend *= 1.8
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _edge_by_id(edge_id: String) -> Dictionary:
    for edge: Dictionary in edges:
        if str(edge.get("id", "")) == edge_id:
            return edge
    return {}


func _add_bought_node(node_id: String) -> void:
    if not nodes_by_id.has(node_id):
        return

    var node: Dictionary = nodes_by_id[node_id]
    var true_pos: Vector2 = _array_to_vec2(node.get("position", [0, 0]))
    bought_map_nodes[node_id] = {
        "id": node_id,
        "name": str(node.get("name", node_id)),
        "kind": str(node.get("kind", "unknown")),
        "true_pos": true_pos,
        "map_pos": true_pos + _bought_offset(node_id),
        "source": "bought",
        "medium": "charcoal",
        "status": "unverified",
        "accuracy": bought_map_quality,
        "label": _bought_label_for_node(node),
        "variant": abs(hash("%s:bought:%d" % [node_id, int(bought_map_quality * 100.0)])) % 4
    }


func _bought_edge_path(from_id: String, to_id: String, edge_id: String) -> PackedVector2Array:
    var from_pos: Vector2 = bought_map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = bought_map_nodes[to_id]["map_pos"]
    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend_strength: float = lerpf(95.0, 18.0, bought_map_quality)
    var bend: float = float((abs(hash("%s:bought" % edge_id)) % int(bend_strength * 2.0)) - int(bend_strength))
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _copied_edge_path(from_id: String, to_id: String, edge_id: String) -> PackedVector2Array:
    var from_pos: Vector2 = map_nodes[from_id]["map_pos"]
    var to_pos: Vector2 = map_nodes[to_id]["map_pos"]
    var midpoint: Vector2 = (from_pos + to_pos) * 0.5
    var direction: Vector2 = (to_pos - from_pos).normalized()
    var normal: Vector2 = Vector2(-direction.y, direction.x)
    var bend_strength: float = lerpf(120.0, 26.0, _copied_accuracy())
    var bend: float = float((abs(hash("%s:copied:%d" % [edge_id, copied_map_count])) % int(bend_strength * 2.0)) - int(bend_strength))
    return PackedVector2Array([from_pos, midpoint + normal * bend, to_pos])


func _bought_river_map_point(true_point: Vector2, river: Dictionary, river_id: String) -> Vector2:
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not nodes_by_id.has(visible_node_id) or not bought_map_nodes.has(visible_node_id):
            continue

        var node_true_pos: Vector2 = _array_to_vec2(nodes_by_id[visible_node_id].get("position", [0, 0]))
        if true_point.distance_to(node_true_pos) <= 2.0:
            return bought_map_nodes[visible_node_id].get("map_pos", node_true_pos)

    return true_point + _bought_offset("%s:river" % river_id) * 0.45


func _copied_river_point(source_point: Vector2, river_id: String, point_index: int) -> Vector2:
    var river: Dictionary = _river_by_id(river_id)
    if river.is_empty():
        return source_point + _copy_offset("%s:river:%d" % [river_id, point_index]) * 0.35

    var true_points: Array = river.get("points", [])
    if point_index >= true_points.size():
        return source_point + _copy_offset("%s:river:%d" % [river_id, point_index]) * 0.35

    var true_point: Vector2 = _array_to_vec2(true_points[point_index])
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not nodes_by_id.has(visible_node_id) or not map_nodes.has(visible_node_id):
            continue

        var node_true_pos: Vector2 = _array_to_vec2(nodes_by_id[visible_node_id].get("position", [0, 0]))
        if true_point.distance_to(node_true_pos) <= 2.0:
            return map_nodes[visible_node_id].get("map_pos", source_point)

    return source_point + _copy_offset("%s:river:%d" % [river_id, point_index]) * 0.35


func _river_by_id(river_id: String) -> Dictionary:
    for river: Dictionary in rivers:
        if str(river.get("id", "")) == river_id:
            return river
    return {}


func _river_map_point(true_point: Vector2, river: Dictionary, river_id: String) -> Vector2:
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not nodes_by_id.has(visible_node_id) or not map_nodes.has(visible_node_id):
            continue

        var node_true_pos: Vector2 = _array_to_vec2(nodes_by_id[visible_node_id].get("position", [0, 0]))
        if true_point.distance_to(node_true_pos) <= 2.0:
            return map_nodes[visible_node_id].get("map_pos", node_true_pos)

    return true_point + _stable_offset(river_id, "river") * 0.35


func _bought_offset(id: String) -> Vector2:
    var seed: int = abs(hash("%s:bought:%d" % [id, int(bought_map_quality * 100.0)]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = lerpf(92.0, 10.0, bought_map_quality)
    var variance: float = float((seed / 19) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.45 + variance))


func _copy_offset(id: String) -> Vector2:
    var seed: int = abs(hash("%s:copy:%d" % [id, copied_map_count]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = lerpf(52.0, 8.0, _copied_accuracy())
    var variance: float = float((seed / 23) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.35 + variance))


func _copied_accuracy() -> float:
    var character_copy_skill: float = 0.56
    return clamp(bought_map_quality * 0.72 + character_copy_skill * 0.28, 0.18, 0.9)


func _bought_label_for_node(node: Dictionary) -> String:
    var name: String = str(node.get("name", "unknown"))
    if bought_map_quality < 0.45:
        return "%s?" % name
    return name


func _erase_node_mark(node: Dictionary) -> void:
    if str(node.get("source", "")) == "visited":
        return
    var erased: Dictionary = node.duplicate(true)
    erased["status"] = "erased"
    erased["medium"] = "charcoal"
    erased_nodes.append(erased)


func _erase_edge_mark(edge: Dictionary) -> void:
    if str(edge.get("source", "")) == "visited":
        return
    var erased: Dictionary = edge.duplicate(true)
    erased["status"] = "erased"
    erased["medium"] = "charcoal"
    erased_edges.append(erased)


func _erase_river_mark(river: Dictionary) -> void:
    var erased: Dictionary = river.duplicate(true)
    erased["status"] = "erased"
    erased["medium"] = "charcoal"
    erased_rivers.append(erased)


func _should_reposition_node(existing: Dictionary, node: Dictionary, improved_pos: Vector2) -> bool:
    var kind: String = str(node.get("kind", "unknown"))
    if kind == "bridge" or kind == "ford":
        return true

    var current_pos: Vector2 = existing.get("map_pos", improved_pos)
    return current_pos.distance_to(improved_pos) > 160.0


func _river_has_player_anchor(river: Dictionary) -> bool:
    var visible_near: Array = river.get("visible_near", [])
    for visible_node_id_value: Variant in visible_near:
        var visible_node_id: String = str(visible_node_id_value)
        if not map_nodes.has(visible_node_id):
            continue

        var kind: String = str(map_nodes[visible_node_id].get("kind", "unknown"))
        var source: String = str(map_nodes[visible_node_id].get("source", ""))
        if (kind == "bridge" or kind == "ford") and _source_rank(source) >= _source_rank("seen"):
            return true
    return false


func _stable_offset(id: String, source: String) -> Vector2:
    var seed: int = abs(hash("%s:%s:sketch" % [id, source]))
    var angle: float = float(seed % 6283) / 1000.0
    var radius: float = 8.0
    match source:
        "visited":
            radius = 12.0
        "seen":
            radius = 34.0
        "heard":
            radius = 74.0
        _:
            radius = 28.0
    var variance: float = float((seed / 17) % 100) / 100.0
    return Vector2(cos(angle), sin(angle)) * (radius * (0.55 + variance))


func _accuracy_for_source(source: String) -> float:
    match source:
        "visited":
            return 0.82
        "seen":
            return 0.52
        "heard":
            return 0.24
        _:
            return 0.4


func _source_rank(source: String) -> float:
    match source:
        "visited":
            return 3.0
        "seen":
            return 2.0
        "copied":
            return 1.4
        "heard":
            return 1.0
        _:
            return 0.0


func _label_for_node(node: Dictionary, source: String) -> String:
    var name: String = str(node.get("name", "unknown"))
    if source == "heard":
        return "%s?" % name
    return name


func _label_for_landmark(landmark: Dictionary, source: String) -> String:
    var name: String = str(landmark.get("name", "unknown"))
    if source == "heard":
        return "%s?" % name
    return name


func _medium_for_source(source: String) -> String:
    match source:
        "visited":
            return "ink"
        "seen":
            return "thin_ink"
        "heard", "copied", "bought":
            return "charcoal"
        _:
            return "charcoal"


func _status_for_source(source: String) -> String:
    match source:
        "visited":
            return "verified"
        "seen":
            return "observed"
        _:
            return "unverified"


func _array_to_vec2(value: Variant) -> Vector2:
    if typeof(value) == TYPE_VECTOR2:
        return value
    if typeof(value) == TYPE_ARRAY and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO
