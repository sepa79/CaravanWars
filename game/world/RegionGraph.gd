class_name RegionGraph
extends RefCounted

const REGION_GRAPH_NODE_SCRIPT: GDScript = preload("res://world/RegionGraphNode.gd")
const REGION_GRAPH_EDGE_SCRIPT: GDScript = preload("res://world/RegionGraphEdge.gd")
const REGION_TERRAIN_AREA_SCRIPT: GDScript = preload("res://world/RegionTerrainArea.gd")
const REGION_LANDMARK_SCRIPT: GDScript = preload("res://world/RegionLandmark.gd")

var id: String = ""
var display_name: String = ""
var description: String = ""
var nodes_by_id: Dictionary[String, RefCounted] = {}
var edges_by_id: Dictionary[String, RefCounted] = {}
var terrain_areas_by_id: Dictionary[String, RefCounted] = {}
var landmarks_by_id: Dictionary[String, RefCounted] = {}


func add_node(node: RefCounted) -> void:
    nodes_by_id[node.id] = node


func add_edge(edge: RefCounted) -> void:
    edges_by_id[edge.id] = edge


func add_terrain_area(area: RefCounted) -> void:
    terrain_areas_by_id[area.id] = area


func add_landmark(landmark: RefCounted) -> void:
    landmarks_by_id[landmark.id] = landmark


func has_node(node_id: String) -> bool:
    return nodes_by_id.has(node_id)


func get_node(node_id: String) -> RefCounted:
    return nodes_by_id.get(node_id)


func get_neighbors(node_id: String) -> Array[String]:
    var neighbor_ids: Array[String] = []
    for edge: RefCounted in edges_by_id.values():
        if edge.origin_node_id == node_id:
            neighbor_ids.append(edge.target_node_id)
        elif edge.target_node_id == node_id:
            neighbor_ids.append(edge.origin_node_id)
    return neighbor_ids


func get_edge_between(first_node_id: String, second_node_id: String) -> RefCounted:
    for edge: RefCounted in edges_by_id.values():
        var matches_forward: bool = edge.origin_node_id == first_node_id and edge.target_node_id == second_node_id
        var matches_reverse: bool = edge.origin_node_id == second_node_id and edge.target_node_id == first_node_id
        if matches_forward or matches_reverse:
            return edge
    return null


func get_edges_for_node(node_id: String) -> Array[RefCounted]:
    var route_edges: Array[RefCounted] = []
    for edge: RefCounted in edges_by_id.values():
        if edge.origin_node_id == node_id or edge.target_node_id == node_id:
            route_edges.append(edge)
    return route_edges


func get_terrain_area(area_id: String) -> RefCounted:
    return terrain_areas_by_id.get(area_id)


func get_landmark(landmark_id: String) -> RefCounted:
    return landmarks_by_id.get(landmark_id)


func validate() -> Array[String]:
    var validation_errors: Array[String] = []

    if id.is_empty():
        validation_errors.append("Region graph id is empty.")

    for node: RefCounted in nodes_by_id.values():
        if node.id.is_empty():
            validation_errors.append("Node has empty id.")

    for edge: RefCounted in edges_by_id.values():
        if edge.id.is_empty():
            validation_errors.append("Edge has empty id.")
        if not has_node(edge.origin_node_id):
            validation_errors.append("Edge %s references missing origin node %s." % [edge.id, edge.origin_node_id])
        if not has_node(edge.target_node_id):
            validation_errors.append("Edge %s references missing target node %s." % [edge.id, edge.target_node_id])
        if edge.distance_km <= 0.0:
            validation_errors.append("Edge %s has non-positive distance." % edge.id)
        validation_errors.append_array(_validate_route_waypoints(edge))

    for area: RefCounted in terrain_areas_by_id.values():
        if area.id.is_empty():
            validation_errors.append("Terrain area has empty id.")
        if area.shape == "polygon" and area.polygon.size() < 3:
            validation_errors.append("Terrain area %s polygon has fewer than 3 points." % area.id)
        if area.shape == "ellipse" and (area.radius.x <= 0.0 or area.radius.y <= 0.0):
            validation_errors.append("Terrain area %s ellipse has non-positive radius." % area.id)

    for landmark: RefCounted in landmarks_by_id.values():
        if landmark.id.is_empty():
            validation_errors.append("Landmark has empty id.")

    return validation_errors


func _validate_route_waypoints(edge: RefCounted) -> Array[String]:
    var validation_errors: Array[String] = []
    var previous_distance: float = -1.0
    for waypoint: RefCounted in edge.route_waypoints:
        if waypoint.id.is_empty():
            validation_errors.append("Edge %s has route waypoint with empty id." % edge.id)
        if waypoint.distance_from_start_km <= 0.0:
            validation_errors.append("Route waypoint %s on edge %s has non-positive distance_from_start_km." % [waypoint.id, edge.id])
        if waypoint.distance_from_start_km >= edge.distance_km:
            validation_errors.append("Route waypoint %s on edge %s is beyond edge distance." % [waypoint.id, edge.id])
        if waypoint.distance_from_start_km <= previous_distance:
            validation_errors.append("Route waypoint %s on edge %s is not ordered by distance." % [waypoint.id, edge.id])
        if waypoint.travel_time_modifier <= 0.0:
            validation_errors.append("Route waypoint %s on edge %s has non-positive travel_time_modifier." % [waypoint.id, edge.id])
        for terrain_area_id: String in waypoint.terrain_area_ids:
            if not terrain_areas_by_id.has(terrain_area_id):
                validation_errors.append("Route waypoint %s on edge %s references missing terrain area %s." % [waypoint.id, edge.id, terrain_area_id])
        for landmark_id: String in waypoint.landmark_ids:
            if not landmarks_by_id.has(landmark_id):
                validation_errors.append("Route waypoint %s on edge %s references missing landmark %s." % [waypoint.id, edge.id, landmark_id])
        previous_distance = waypoint.distance_from_start_km
    return validation_errors


static func from_dictionary(region_dictionary: Dictionary) -> RefCounted:
    var graph: RefCounted = new()
    graph.id = str(region_dictionary.get("id", ""))
    graph.display_name = str(region_dictionary.get("display_name", graph.id))
    graph.description = str(region_dictionary.get("description", ""))

    var raw_nodes: Variant = region_dictionary.get("nodes", [])
    if typeof(raw_nodes) == TYPE_ARRAY:
        for raw_node: Variant in raw_nodes:
            if typeof(raw_node) == TYPE_DICTIONARY:
                graph.add_node(REGION_GRAPH_NODE_SCRIPT.from_dictionary(raw_node))

    var raw_edges: Variant = region_dictionary.get("edges", [])
    if typeof(raw_edges) == TYPE_ARRAY:
        for raw_edge: Variant in raw_edges:
            if typeof(raw_edge) == TYPE_DICTIONARY:
                graph.add_edge(REGION_GRAPH_EDGE_SCRIPT.from_dictionary(raw_edge))

    var raw_terrain_areas: Variant = region_dictionary.get("terrain_areas", [])
    if typeof(raw_terrain_areas) == TYPE_ARRAY:
        for raw_area: Variant in raw_terrain_areas:
            if typeof(raw_area) == TYPE_DICTIONARY:
                graph.add_terrain_area(REGION_TERRAIN_AREA_SCRIPT.from_dictionary(raw_area))

    var raw_landmarks: Variant = region_dictionary.get("landmarks", [])
    if typeof(raw_landmarks) == TYPE_ARRAY:
        for raw_landmark: Variant in raw_landmarks:
            if typeof(raw_landmark) == TYPE_DICTIONARY:
                graph.add_landmark(REGION_LANDMARK_SCRIPT.from_dictionary(raw_landmark))

    return graph
