extends RefCounted
class_name MapViewSnapshot

var rng_seed: int
var version: String
var nodes: Dictionary
var edges: Dictionary
var regions: Dictionary

func _init(p_rng_seed: int, p_version: String) -> void:
    rng_seed = p_rng_seed
    version = p_version
    nodes = {}
    edges = {}
    regions = {}

static func from_map(map_data: Dictionary, p_rng_seed: int, p_version: String) -> MapViewSnapshot:
    var snapshot := MapViewSnapshot.new(p_rng_seed, p_version)
    var roads: Dictionary = map_data.get("roads", {})
    for node in roads.get("nodes", {}).values():
        snapshot.nodes[node.id] = node
    for edge in roads.get("edges", {}).values():
        snapshot.edges[edge.id] = edge
    for region in map_data.get("regions", {}).values():
        snapshot.regions[region.id] = region
    return snapshot

func to_dict() -> Dictionary:
    var node_list: Array = []
    for node in nodes.values():
        node_list.append(node.to_dict())
    var edge_list: Array = []
    for edge in edges.values():
        edge_list.append(edge.to_dict())
    var region_list: Array = []
    for region in regions.values():
        region_list.append(region.to_dict())
    return {
        "meta": {"seed": rng_seed, "version": version},
        "nodes": node_list,
        "edges": edge_list,
        "regions": region_list,
    }

func diff(previous: MapViewSnapshot) -> Dictionary:
    return {
        "meta": {"seed": rng_seed, "version": version},
        "nodes": _diff_section(nodes, previous.nodes),
        "edges": _diff_section(edges, previous.edges),
        "regions": _diff_section(regions, previous.regions),
    }

func _diff_section(current: Dictionary, previous: Dictionary) -> Dictionary:
    var added: Array = []
    var updated: Array = []
    var removed: Array = []
    for id in current.keys():
        if not previous.has(id):
            added.append(current[id].to_dict())
        elif current[id].to_dict() != previous[id].to_dict():
            updated.append(current[id].to_dict())
    for id in previous.keys():
        if not current.has(id):
            removed.append(id)
    return {"added": added, "updated": updated, "removed": removed}
