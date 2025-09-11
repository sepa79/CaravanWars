extends RefCounted
class_name RoadNetwork

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")

func _lower_class(cls: String) -> String:
    match cls:
        "roman":
            return "road"
        "road":
            return "path"
        _:
            return cls

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Builds primary trade routes between cities.
## Pipeline: Delaunay triangulation → MST → per-city k-nearest edges.
func build_roads(
    cities: Array[Vector2],
    min_connections: int = 1,
    max_connections: int = 3,
    crossing_margin: float = 5.0,
    road_class: String = "road"
) -> Dictionary:
    var nodes: Dictionary = {}
    var edges: Dictionary = {}
    var node_id: int = 1
    var edge_id: int = 1

    var city_ids: Array[int] = []
    for city in cities:
        nodes[node_id] = MapNodeModule.new(node_id, MapNodeModule.TYPE_CITY, city, {})
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
        edges[edge_id] = EdgeModule.new(edge_id, "road", [start_node.pos2d, end_node.pos2d], [start_node.id, end_node.id], road_class, {})
        edge_id += 1

    var result: Dictionary = _insert_crossings(nodes, edges, node_id, edge_id)
    _prune_crossing_duplicates(nodes, edges, crossing_margin)
    return {
        "nodes": nodes,
        "edges": edges,
        "next_node_id": result["next_node_id"],
        "next_edge_id": result["next_edge_id"],
    }

## Links two nodes with a road and inserts crossings as needed.
func connect_nodes(
    roads: Dictionary,
    a_id: int,
    b_id: int,
    crossing_margin: float = 5.0,
    road_class: String = "road"
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var start: MapNode = nodes.get(a_id)
    var end: MapNode = nodes.get(b_id)
    if start == null or end == null:
        return
    edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [start.pos2d, end.pos2d], [start.id, end.id], road_class, {})
    next_edge_id += 1
    var res: Dictionary = _insert_crossings(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossing_duplicates(nodes, edges, crossing_margin)

## Branches villages off roads near cities.
func insert_villages(
    roads: Dictionary,
    min_per_city: int,
    max_per_city: int,
    offset: float = 5.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var adjacency: Dictionary = {}
    for eid in edges.keys():
        var e: Edge = edges[eid]
        for nid in e.endpoints:
            if not adjacency.has(nid):
                adjacency[nid] = []
            adjacency[nid].append(eid)
    for nid in nodes.keys():
        var node: MapNode = nodes[nid]
        if node.type != MapNodeModule.TYPE_CITY:
            continue
        var edge_ids: Array[int] = []
        edge_ids.append_array(adjacency.get(nid, []) as Array)
        if edge_ids.is_empty():
            continue
        # Fisher-Yates shuffle using our RNG
        for i in range(edge_ids.size() - 1, 0, -1):
            var j = rng.randi_range(0, i)
            var tmp = edge_ids[i]
            edge_ids[i] = edge_ids[j]
            edge_ids[j] = tmp
        var count: int = clamp(rng.randi_range(min_per_city, max_per_city), 0, edge_ids.size())
        for i in range(count):
            var eid: int = edge_ids[i]
            if not edges.has(eid):
                continue
            var edge: Edge = edges[eid]
            var other_id: int = edge.endpoints[0] if edge.endpoints[1] == nid else edge.endpoints[1]
            var start_pos: Vector2 = nodes[nid].pos2d
            var end_pos: Vector2 = nodes[other_id].pos2d
            var length: float = start_pos.distance_to(end_pos)
            var dir: Vector2 = (end_pos - start_pos).normalized()
            var dist_along: float = clamp(length * 0.3, 10.0, length - 10.0)
            var junction_pos: Vector2 = start_pos + dir * dist_along
            var junction_id: int = next_node_id
            next_node_id += 1
            nodes[junction_id] = MapNodeModule.new(junction_id, MapNodeModule.TYPE_CROSSING, junction_pos, {})
            edges.erase(eid)
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [start_pos, junction_pos], [nid, junction_id], edge.road_class, edge.attrs)
            next_edge_id += 1
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [junction_pos, end_pos], [junction_id, other_id], edge.road_class, edge.attrs)
            next_edge_id += 1
            var perp: Vector2 = Vector2(-dir.y, dir.x)
            if rng.randf() < 0.5:
                perp = -perp
            var village_pos: Vector2 = junction_pos + perp * offset
            var village_id: int = next_node_id
            next_node_id += 1
            nodes[village_id] = MapNodeModule.new(village_id, MapNodeModule.TYPE_VILLAGE, village_pos, {})
            var v_class: String = _lower_class(edge.road_class)
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [junction_pos, village_pos], [junction_id, village_id], v_class, edge.attrs)
            next_edge_id += 1
    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id

## Inserts a node in the middle of an edge and splits the edge.
func insert_node_on_edge(roads: Dictionary, edge_id: int, node_type: String) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var edge: Edge = edges.get(edge_id)
    if edge == null:
        return
    var start: Vector2 = edge.polyline[0]
    var end: Vector2 = edge.polyline[edge.polyline.size() - 1]
    var pos: Vector2 = (start + end) * 0.5
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    nodes[next_node_id] = MapNodeModule.new(next_node_id, node_type, pos, {})
    edges.erase(edge_id)
    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [start, pos], [edge.endpoints[0], next_node_id], edge.road_class, edge.attrs)
    next_edge_id += 1
    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [pos, end], [next_node_id, edge.endpoints[1]], edge.road_class, edge.attrs)
    next_edge_id += 1
    var res: Dictionary = _insert_crossings(nodes, edges, next_node_id + 1, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]

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
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [nodes[other1].pos2d, nodes[other2].pos2d], [other1, other2], e1.road_class, {})
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

## Splits roads where they cross rivers and inserts bridge nodes.
func insert_river_crossings(roads: Dictionary, rivers: Array, crossing_margin: float = 5.0) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)

    var changed := true
    while changed:
        changed = false
        var edge_ids: Array = edges.keys()
        for eid in edge_ids:
            var edge: Edge = edges[eid]
            var road_start: Vector2 = edge.polyline[0]
            var road_end: Vector2 = edge.polyline[edge.polyline.size() - 1]
            for poly in rivers:
                for i in range(poly.size() - 1):
                    var river_a: Vector2 = poly[i]
                    var river_b: Vector2 = poly[i + 1]
                    var inter: Variant = Geometry2D.segment_intersects_segment(road_start, road_end, river_a, river_b)
                    if inter == null:
                        continue
                    var cross: Vector2 = inter
                    if _point_on_endpoint(cross, road_start, road_end):
                        var node_id: int = edge.endpoints[0] if cross == road_start else edge.endpoints[1]
                        var node: MapNode = nodes.get(node_id)
                        if node != null and node.type != "bridge" and node.type != "ford":
                            node.type = "bridge"
                            changed = true
                        continue

                    var cross_id: int = next_node_id
                    next_node_id += 1
                    nodes[cross_id] = MapNodeModule.new(cross_id, MapNodeModule.TYPE_BRIDGE, cross, {})
                    var a_id: int = edge.endpoints[0]
                    var b_id: int = edge.endpoints[1]
                    edges.erase(eid)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [road_start, cross], [a_id, cross_id], edge.road_class, edge.attrs)
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, road_end], [cross_id, b_id], edge.road_class, edge.attrs)
                    next_edge_id += 1
                    changed = true
                    break
                if changed:
                    break
            if changed:
                break

    var res: Dictionary = _insert_crossings(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossing_duplicates(nodes, edges, crossing_margin)

## Adds a fort near each road segment that crosses between different kingdoms.
func insert_border_forts(roads: Dictionary, regions: Dictionary, offset: float = 10.0, max_per_kingdom: int = 1) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var fort_counts: Dictionary = {}
    var keys: Array = edges.keys()
    for eid in keys:
        var edge: Edge = edges[eid]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_region: Region = _region_for_point(nodes[a_id].pos2d, regions)
        var b_region: Region = _region_for_point(nodes[b_id].pos2d, regions)
        if a_region == null or b_region == null:
            continue
        if a_region.kingdom_id == b_region.kingdom_id:
            continue
        var cross: Vector2 = _border_intersection(nodes[a_id].pos2d, nodes[b_id].pos2d, a_region)
        var dir: Vector2 = (nodes[b_id].pos2d - nodes[a_id].pos2d).normalized()
        var junction_id: int = next_node_id
        next_node_id += 1
        nodes[junction_id] = MapNodeModule.new(junction_id, MapNodeModule.TYPE_CROSSING, cross, {})
        edges.erase(eid)
        edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [nodes[a_id].pos2d, cross], [a_id, junction_id], edge.road_class, edge.attrs)
        next_edge_id += 1
        edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, nodes[b_id].pos2d], [junction_id, b_id], edge.road_class, edge.attrs)
        next_edge_id += 1
        var spur_class: String = _lower_class(edge.road_class)
        var kid_a: int = a_region.kingdom_id
        if fort_counts.get(kid_a, 0) < max_per_kingdom:
            var fort_pos_a: Vector2 = cross - dir * offset
            var fort_id_a: int = next_node_id
            next_node_id += 1
            nodes[fort_id_a] = MapNodeModule.new(fort_id_a, MapNodeModule.TYPE_FORT, fort_pos_a, {})
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, fort_pos_a], [junction_id, fort_id_a], spur_class, edge.attrs)
            next_edge_id += 1
            fort_counts[kid_a] = fort_counts.get(kid_a, 0) + 1
        var kid_b: int = b_region.kingdom_id
        if fort_counts.get(kid_b, 0) < max_per_kingdom:
            var fort_pos_b: Vector2 = cross + dir * offset
            var fort_id_b: int = next_node_id
            next_node_id += 1
            nodes[fort_id_b] = MapNodeModule.new(fort_id_b, MapNodeModule.TYPE_FORT, fort_pos_b, {})
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, fort_pos_b], [junction_id, fort_id_b], spur_class, edge.attrs)
            next_edge_id += 1
            fort_counts[kid_b] = fort_counts.get(kid_b, 0) + 1
    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id

func _region_for_point(p: Vector2, regions: Dictionary) -> Region:
    for region in regions.values():
        var pts := PackedVector2Array()
        for v in region.boundary_nodes:
            pts.append(v)
        if Geometry2D.is_point_in_polygon(p, pts):
            return region
    return null

func _border_intersection(a: Vector2, b: Vector2, region: Region) -> Vector2:
    var pts: Array[Vector2] = region.boundary_nodes
    for i in range(pts.size()):
        var p1: Vector2 = pts[i]
        var p2: Vector2 = pts[(i + 1) % pts.size()]
        var inter: Variant = Geometry2D.segment_intersects_segment(a, b, p1, p2)
        if inter != null:
            return inter
    return (a + b) * 0.5

## Sanitizes a road network dictionary by pruning invalid edges and nodes.
func cleanup(roads: Dictionary, crossing_margin: float = 5.0) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})

    var remove_edges: Array[int] = []
    for eid in edges.keys():
        var edge: Edge = edges[eid]
        var endpoints: Array[int] = edge.endpoints
        if endpoints.size() != 2 or not nodes.has(endpoints[0]) or not nodes.has(endpoints[1]):
            remove_edges.append(eid)
            continue
        var length: float = 0.0
        for i in range(edge.polyline.size() - 1):
            length += edge.polyline[i].distance_to(edge.polyline[i + 1])
        if length <= 0.001:
            remove_edges.append(eid)
    for eid in remove_edges:
        edges.erase(eid)

    var used: Dictionary = {}
    for e in edges.values():
        used[e.endpoints[0]] = true
        used[e.endpoints[1]] = true

    for nid in nodes.keys():
        if nodes[nid].type != "city" and not used.has(nid):
            nodes.erase(nid)

    var res: Dictionary = _insert_crossings(nodes, edges, roads.get("next_node_id", 1), roads.get("next_edge_id", 1))
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
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
                nodes[cross_id] = MapNodeModule.new(cross_id, MapNodeModule.TYPE_CROSSING, cross, {})

                var a_ep0: int = edge_a.endpoints[0]
                var a_ep1: int = edge_a.endpoints[1]
                edges.erase(id_a)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_a.type, [a_start, cross], [a_ep0, cross_id], edge_a.road_class, edge_a.attrs)
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_a.type, [cross, a_end], [cross_id, a_ep1], edge_a.road_class, edge_a.attrs)
                next_edge_id += 1

                var b_ep0: int = edge_b.endpoints[0]
                var b_ep1: int = edge_b.endpoints[1]
                edges.erase(id_b)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_b.type, [b_start, cross], [b_ep0, cross_id], edge_b.road_class, edge_b.attrs)
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_b.type, [cross, b_end], [cross_id, b_ep1], edge_b.road_class, edge_b.attrs)
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
