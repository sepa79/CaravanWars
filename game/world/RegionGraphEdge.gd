class_name RegionGraphEdge
extends RefCounted

const REGION_ROUTE_WAYPOINT_SCRIPT: GDScript = preload("res://world/RegionRouteWaypoint.gd")

var id: String = ""
var origin_node_id: String = ""
var target_node_id: String = ""
var distance_km: float = 0.0
var kind: String = ""
var waypoint_coordinates: Array[Vector2] = []
var route_waypoints: Array[RefCounted] = []


static func from_dictionary(edge_dictionary: Dictionary) -> RefCounted:
    var edge: RefCounted = new()
    edge.id = str(edge_dictionary.get("id", ""))
    edge.origin_node_id = str(edge_dictionary.get("from", ""))
    edge.target_node_id = str(edge_dictionary.get("to", ""))
    edge.distance_km = float(edge_dictionary.get("distance_km", 0.0))
    edge.kind = str(edge_dictionary.get("kind", "route"))

    var raw_waypoints: Variant = edge_dictionary.get("waypoints", [])
    if typeof(raw_waypoints) == TYPE_ARRAY:
        for raw_waypoint: Variant in raw_waypoints:
            if typeof(raw_waypoint) == TYPE_ARRAY and raw_waypoint.size() >= 2:
                edge.waypoint_coordinates.append(Vector2(float(raw_waypoint[0]), float(raw_waypoint[1])))

    var raw_geometry: Variant = edge_dictionary.get("geometry", [])
    if typeof(raw_geometry) == TYPE_ARRAY:
        for raw_route_waypoint: Variant in raw_geometry:
            if typeof(raw_route_waypoint) == TYPE_DICTIONARY:
                edge.route_waypoints.append(REGION_ROUTE_WAYPOINT_SCRIPT.from_dictionary(raw_route_waypoint))

    return edge
