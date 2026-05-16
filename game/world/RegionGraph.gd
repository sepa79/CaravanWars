class_name RegionGraph
extends RefCounted

const REGION_GRAPH_NODE_SCRIPT: GDScript = preload("res://world/RegionGraphNode.gd")
const REGION_GRAPH_EDGE_SCRIPT: GDScript = preload("res://world/RegionGraphEdge.gd")

var id: String = ""
var display_name: String = ""
var description: String = ""
var nodes_by_id: Dictionary[String, RefCounted] = {}
var edges_by_id: Dictionary[String, RefCounted] = {}


func add_node(node: RefCounted) -> void:
    nodes_by_id[node.id] = node


func add_edge(edge: RefCounted) -> void:
    edges_by_id[edge.id] = edge


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

    return graph
