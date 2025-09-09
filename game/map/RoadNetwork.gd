extends RefCounted
class_name RoadNetwork

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Builds primary trade routes between cities.
## Pipeline: Delaunay triangulation → MST → k-nearest edges.
## Villages are inserted every `village_spacing` units; a fort is placed near the center.
func build_roads(cities: Array[Vector2], k: int = 2, village_spacing: float = 25.0) -> Dictionary:
    var nodes: Dictionary = {}
    var edges: Dictionary = {}
    var node_id: int = 1
    var edge_id: int = 1

    var city_ids: Array[int] = []
    for city in cities:
        nodes[node_id] = MapNodeModule.new(node_id, "city", city, {})
        city_ids.append(node_id)
        node_id += 1

    var candidate_edges: Array[Vector2i] = _delaunay_edges(cities)
    var mst_edges: Array[Vector2i] = _minimum_spanning_tree(cities, candidate_edges)

    var final_edge_set: Dictionary = {}
    for e in mst_edges:
        final_edge_set[_pair_key(e.x, e.y)] = e

    for i in range(cities.size()):
        var distances: Array = []
        for j in range(cities.size()):
            if i == j:
                continue
            distances.append({"index": j, "dist": cities[i].distance_to(cities[j])})
        distances.sort_custom(func(a, b): return a["dist"] < b["dist"])
        for n in range(min(k, distances.size())):
            var j: int = distances[n]["index"]
            final_edge_set[_pair_key(i, j)] = Vector2i(i, j)

    for key in final_edge_set.keys():
        var pair: Vector2i = final_edge_set[key]
        var start_id: int = city_ids[pair.x]
        var end_id: int = city_ids[pair.y]
        var start_node: MapNode = nodes[start_id]
        var end_node: MapNode = nodes[end_id]
        var length: float = start_node.pos2d.distance_to(end_node.pos2d)
        var dir: Vector2 = (end_node.pos2d - start_node.pos2d).normalized()
        var dist: float = village_spacing
        var last_node: MapNode = start_node
        var fort_placed: bool = false
        while dist < length:
            var pos: Vector2 = start_node.pos2d + dir * dist
            var node_type: String = "village"
            if not fort_placed and abs(dist - length / 2.0) < village_spacing / 2.0:
                node_type = "fort"
                fort_placed = true
            var n_node: MapNode = MapNodeModule.new(node_id, node_type, pos, {})
            nodes[node_id] = n_node
            edges[edge_id] = EdgeModule.new(edge_id, "trade_route", [last_node.pos2d, pos], [last_node.id, node_id], {})
            edge_id += 1
            last_node = n_node
            node_id += 1
            dist += village_spacing
        edges[edge_id] = EdgeModule.new(edge_id, "trade_route", [last_node.pos2d, end_node.pos2d], [last_node.id, end_node.id], {})
        edge_id += 1

    return {
        "nodes": nodes,
        "edges": edges,
        "next_node_id": node_id,
        "next_edge_id": edge_id,
    }

func _pair_key(a: int, b: int) -> String:
    return "%d_%d" % [min(a, b), max(a, b)]

func _delaunay_edges(points: Array[Vector2]) -> Array[Vector2i]:
    var pts := PackedVector2Array(points)
    var tri := Geometry2D.triangulate_delaunay(pts)
    var edges_dict: Dictionary = {}
    for i in range(0, tri.size(), 3):
        _add_edge(edges_dict, tri[i], tri[i + 1])
        _add_edge(edges_dict, tri[i + 1], tri[i + 2])
        _add_edge(edges_dict, tri[i + 2], tri[i])
    var result: Array[Vector2i] = []
    for v in edges_dict.values():
        result.append(v)
    return result

func _add_edge(container: Dictionary, a: int, b: int) -> void:
    var key := _pair_key(a, b)
    if not container.has(key):
        container[key] = Vector2i(a, b)

func _minimum_spanning_tree(points: Array[Vector2], edges: Array[Vector2i]) -> Array[Vector2i]:
    var adjacency: Dictionary = {}
    for e in edges:
        if not adjacency.has(e.x):
            adjacency[e.x] = []
        if not adjacency.has(e.y):
            adjacency[e.y] = []
        adjacency[e.x].append(e.y)
        adjacency[e.y].append(e.x)

    var connected: Array[int] = [0]
    var remaining: Array[int] = []
    for i in range(1, points.size()):
        remaining.append(i)

    var result: Array[Vector2i] = []
    while remaining.size() > 0:
        var best_edge := Vector2i(-1, -1)
        var best_dist: float = INF
        for a in connected:
            for b in adjacency.get(a, []):
                if connected.has(b):
                    continue
                var d: float = points[a].distance_to(points[b])
                if d < best_dist:
                    best_dist = d
                    best_edge = Vector2i(a, b)
        result.append(best_edge)
        connected.append(best_edge.y)
        remaining.erase(best_edge.y)
    return result
