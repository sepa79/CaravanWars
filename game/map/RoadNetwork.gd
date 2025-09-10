extends RefCounted
class_name RoadNetwork

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Builds primary trade routes between cities.
## Pipeline: Delaunay triangulation → MST → per-city k-nearest edges.
## Villages are inserted every `village_spacing` units; a fort is placed near the center.
func build_roads(
    cities: Array[Vector2],
    min_connections: int = 1,
    max_connections: int = 3,
    crossing_margin: float = 5.0,
    village_spacing: float = 25.0
) -> Dictionary:
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

    var max_possible: int = cities.size() - 1
    min_connections = clamp(min_connections, 1, max_possible)
    max_connections = clamp(max_connections, min_connections, max_possible)
    var k_values: Array[int] = []
    for _city in cities:
        k_values.append(rng.randi_range(min_connections, max_connections))

    for i in range(cities.size()):
        var distances: Array = []
        for j in range(cities.size()):
            if i == j:
                continue
            distances.append({"index": j, "dist": cities[i].distance_to(cities[j])})
        distances.sort_custom(func(a, b): return a["dist"] < b["dist"])
        var k_i: int = k_values[i]
        for n in range(min(k_i, distances.size())):
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

    var result: Dictionary = _insert_crossings(nodes, edges, node_id, edge_id)
    _prune_crossing_duplicates(nodes, edges, crossing_margin)
    return {
        "nodes": nodes,
        "edges": edges,
        "next_node_id": result["next_node_id"],
        "next_edge_id": result["next_edge_id"],
    }

## Links two nodes with a road, inserting villages and crossings as needed.
func connect_nodes(roads: Dictionary, a_id: int, b_id: int, village_spacing: float = 25.0, crossing_margin: float = 5.0) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var start: MapNode = nodes.get(a_id)
    var end: MapNode = nodes.get(b_id)
    if start == null or end == null:
        return
    var length: float = start.pos2d.distance_to(end.pos2d)
    var dir: Vector2 = (end.pos2d - start.pos2d).normalized()
    var dist: float = village_spacing
    var last_node: MapNode = start
    while dist < length:
        var pos: Vector2 = start.pos2d + dir * dist
        var n_node: MapNode = MapNodeModule.new(next_node_id, "village", pos, {})
        nodes[next_node_id] = n_node
        edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [last_node.pos2d, pos], [last_node.id, next_node_id], {})
        last_node = n_node
        next_node_id += 1
        next_edge_id += 1
        dist += village_spacing
    edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [last_node.pos2d, end.pos2d], [last_node.id, end.id], {})
    next_edge_id += 1
    var res: Dictionary = _insert_crossings(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossing_duplicates(nodes, edges, crossing_margin)

func remove_edge(roads: Dictionary, edge_id: int, crossing_margin: float = 5.0) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var edge: Edge = edges.get(edge_id)
    if edge == null:
        return

    var endpoints: Array[int] = [edge.endpoints[0], edge.endpoints[1]]
    edges.erase(edge_id)

    var next_edge_id: int = roads.get("next_edge_id", 1)
    for nid in endpoints:
        var node: MapNode = nodes.get(nid)
        if node == null or node.type != "crossing":
            continue
        var incident: Array[int] = []
        for eid in edges.keys():
            var e: Edge = edges[eid]
            if e.endpoints.has(nid):
                incident.append(eid)
        if incident.size() == 0:
            nodes.erase(nid)
        elif incident.size() == 1:
            edges.erase(incident[0])
            nodes.erase(nid)
        elif incident.size() == 2:
            var e1: Edge = edges[incident[0]]
            var e2: Edge = edges[incident[1]]
            var other1: int = e1.endpoints[0] if e1.endpoints[1] == nid else e1.endpoints[1]
            var other2: int = e2.endpoints[0] if e2.endpoints[1] == nid else e2.endpoints[1]
            edges.erase(incident[0])
            edges.erase(incident[1])
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [nodes[other1].pos2d, nodes[other2].pos2d], [other1, other2], {})
            next_edge_id += 1
            nodes.erase(nid)
        # if more than two incident edges remain, keep crossing as is

    roads["next_edge_id"] = max(next_edge_id, roads.get("next_edge_id", 1))

    var used: Dictionary = {}
    for e in edges.values():
        used[e.endpoints[0]] = true
        used[e.endpoints[1]] = true
    var to_remove: Array[int] = []
    for id in nodes.keys():
        if nodes[id].type != "city" and not used.has(id):
            to_remove.append(id)
    for id in to_remove:
        nodes.erase(id)

    var res2: Dictionary = _insert_crossings(nodes, edges, roads.get("next_node_id", 1), roads.get("next_edge_id", 1))
    roads["next_node_id"] = res2["next_node_id"]
    roads["next_edge_id"] = res2["next_edge_id"]
    _prune_crossing_duplicates(nodes, edges, crossing_margin)

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
    if edges_dict.is_empty():
        var all_pairs: Array[Vector2i] = []
        for i in range(points.size()):
            for j in range(i + 1, points.size()):
                all_pairs.append(Vector2i(i, j))
        return all_pairs
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
        if best_edge.y == -1:
            var a_id: int = connected[0]
            var b_id: int = remaining[0]
            best_dist = points[a_id].distance_to(points[b_id])
            for a in connected:
                for b in remaining:
                    var d: float = points[a].distance_to(points[b])
                    if d < best_dist:
                        best_dist = d
                        a_id = a
                        b_id = b
            best_edge = Vector2i(a_id, b_id)
            push_warning("[RoadNetwork] disconnected graph; forcing MST link")
        result.append(best_edge)
        connected.append(best_edge.y)
        remaining.erase(best_edge.y)
    return result

func _insert_crossings(nodes: Dictionary, edges: Dictionary, next_node_id: int, next_edge_id: int) -> Dictionary:
    var edge_ids = edges.keys()
    var changed := true
    var iterations: int = 0
    var max_iterations: int = 1000
    while changed and iterations < max_iterations:
        changed = false
        edge_ids = edges.keys()
        iterations += 1
        for i in range(edge_ids.size()):
            var id_a: int = edge_ids[i]
            var edge_a: Edge = edges[id_a]
            var a_start: Vector2 = edge_a.polyline[0]
            var a_end: Vector2 = edge_a.polyline[1]
            for j in range(i + 1, edge_ids.size()):
                var id_b: int = edge_ids[j]
                var edge_b: Edge = edges[id_b]
                var b_start: Vector2 = edge_b.polyline[0]
                var b_end: Vector2 = edge_b.polyline[1]
                var inter: Variant = Geometry2D.segment_intersects_segment(a_start, a_end, b_start, b_end)
                if inter == null:
                    continue
                var cross: Vector2 = inter
                if _point_on_endpoint(cross, a_start, a_end) or _point_on_endpoint(cross, b_start, b_end):
                    continue

                var cross_id: int = next_node_id
                next_node_id += 1
                nodes[cross_id] = MapNodeModule.new(cross_id, "crossing", cross, {})

                var a_ep0: int = edge_a.endpoints[0]
                var a_ep1: int = edge_a.endpoints[1]
                edges.erase(id_a)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [a_start, cross], [a_ep0, cross_id], {})
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [cross, a_end], [cross_id, a_ep1], {})
                next_edge_id += 1

                var b_ep0: int = edge_b.endpoints[0]
                var b_ep1: int = edge_b.endpoints[1]
                edges.erase(id_b)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [b_start, cross], [b_ep0, cross_id], {})
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [cross, b_end], [cross_id, b_ep1], {})
                next_edge_id += 1

                changed = true
                break
            if changed:
                break
    if iterations == max_iterations:
        push_warning("[RoadNetwork] crossing insertion iteration limit reached")
    return {
        "next_node_id": next_node_id,
        "next_edge_id": next_edge_id,
    }

func _prune_crossing_duplicates(nodes: Dictionary, edges: Dictionary, margin: float) -> void:
    var city_edges: Dictionary = {}
    for id in edges.keys():
        var edge: Edge = edges[id]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_node: MapNode = nodes[a_id]
        var b_node: MapNode = nodes[b_id]
        if a_node.type == "city" and b_node.type == "city":
            city_edges[_pair_key(a_id, b_id)] = id

    var crossing_links: Dictionary = {}
    for id in edges.keys():
        var edge: Edge = edges[id]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_node: MapNode = nodes[a_id]
        var b_node: MapNode = nodes[b_id]
        if a_node.type == "crossing" and b_node.type == "city":
            if not crossing_links.has(a_id):
                crossing_links[a_id] = [] as Array[int]
            (crossing_links[a_id] as Array[int]).append(b_id)
        elif b_node.type == "crossing" and a_node.type == "city":
            if not crossing_links.has(b_id):
                crossing_links[b_id] = [] as Array[int]
            (crossing_links[b_id] as Array[int]).append(a_id)

    for cross_id in crossing_links.keys():
        var cities: Array[int] = crossing_links[cross_id] as Array[int]
        for i in range(cities.size()):
            for j in range(i + 1, cities.size()):
                var a_id: int = cities[i]
                var b_id: int = cities[j]
                var key := _pair_key(a_id, b_id)
                if city_edges.has(key):
                    var direct_id: int = city_edges[key]
                    var direct_len: float = nodes[a_id].pos2d.distance_to(nodes[b_id].pos2d)
                    var crossing_len: float = nodes[a_id].pos2d.distance_to(nodes[cross_id].pos2d) + \
                        nodes[cross_id].pos2d.distance_to(nodes[b_id].pos2d)
                    if crossing_len - direct_len <= margin:
                        edges.erase(direct_id)
                        city_edges.erase(key)

func _point_on_endpoint(p: Vector2, a: Vector2, b: Vector2) -> bool:
    return p.distance_to(a) < 0.001 or p.distance_to(b) < 0.001
