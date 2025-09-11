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
    crossroad_margin: float = 5.0,
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

    var max_possible: int = min(7, cities.size() - 1)
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

    var result: Dictionary = _insert_crossroads(nodes, edges, node_id, edge_id)
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)
    return {
        "nodes": nodes,
        "edges": edges,
        "next_node_id": result["next_node_id"],
        "next_edge_id": result["next_edge_id"],
    }

## Links two nodes with a road and inserts crossroads as needed.
func connect_nodes(
    roads: Dictionary,
    a_id: int,
    b_id: int,
    crossroad_margin: float = 5.0,
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
    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

func _generate_point_around(p: Vector2, min_distance: float, max_distance: float) -> Vector2:
    var r: float = rng.randf_range(min_distance, max_distance)
    var angle: float = rng.randf() * TAU
    return Vector2(p.x + r * cos(angle), p.y + r * sin(angle))

func _poisson_cluster(center: Vector2, count: int, radius: float, width: float, height: float) -> Array[Vector2]:
    var min_distance: float = radius * 0.5
    var k: int = 30
    var min_x: float = max(0.0, center.x - radius)
    var min_y: float = max(0.0, center.y - radius)
    var max_x: float = min(width, center.x + radius)
    var max_y: float = min(height, center.y + radius)
    var region_w: float = max_x - min_x
    var region_h: float = max_y - min_y
    if region_w <= 0.0 or region_h <= 0.0:
        return []
    var cell_size: float = min_distance / sqrt(2.0)
    var grid_w: int = int(ceil(region_w / cell_size))
    var grid_h: int = int(ceil(region_h / cell_size))
    var grid: Array[int] = []
    for _i in range(grid_w * grid_h):
        grid.append(-1)
    var samples: Array[Vector2] = []
    var active: Array[int] = []
    samples.append(center)
    var idx: int = int((center.x - min_x) / cell_size) + int((center.y - min_y) / cell_size) * grid_w
    grid[idx] = 0
    active.append(0)
    while active.size() > 0 and samples.size() < count + 1:
        var ai: int = active[rng.randi_range(0, active.size() - 1)]
        var point: Vector2 = samples[ai]
        var found := false
        for _j in range(k):
            var p: Vector2 = _generate_point_around(point, min_distance, radius)
            if p.x < min_x or p.y < min_y or p.x > max_x or p.y > max_y:
                continue
            if p.distance_to(center) > radius:
                continue
            var gx: int = int((p.x - min_x) / cell_size)
            var gy: int = int((p.y - min_y) / cell_size)
            var ok := true
            for x in range(max(0, gx - 2), min(grid_w, gx + 3)):
                for y in range(max(0, gy - 2), min(grid_h, gy + 3)):
                    var gi: int = y * grid_w + x
                    var si: int = grid[gi]
                    if si != -1 and samples[si].distance_to(p) < min_distance:
                        ok = false
                        break
                if not ok:
                    break
            if ok:
                samples.append(p)
                active.append(samples.size() - 1)
                grid[gy * grid_w + gx] = samples.size() - 1
                found = true
                if samples.size() >= count + 1:
                    break
        if not found:
            active.erase(ai)
    var result: Array[Vector2] = []
    for i in range(1, samples.size()):
        result.append(samples[i])
    return result

## Generates per-city village clusters.
## Villages form path networks around each town and use roads
## to connect back to the town center.
func insert_villages(
    roads: Dictionary,
    min_per_city: int,
    max_per_city: int,
    radius: float = 5.0,
    width: float = 100.0,
    height: float = 100.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    for nid in nodes.keys():
        var city: MapNode = nodes[nid]
        if city.type != MapNodeModule.TYPE_CITY:
            continue
        var count: int = max(0, rng.randi_range(min_per_city, max_per_city))
        if count == 0:
            continue
        var positions: Array[Vector2] = _poisson_cluster(city.pos2d, count, radius, width, height)
        var village_ids: Array[int] = []
        for pos in positions:
            var vid: int = next_node_id
            next_node_id += 1
            nodes[vid] = MapNodeModule.new(vid, MapNodeModule.TYPE_VILLAGE, pos, {})
            village_ids.append(vid)
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [city.pos2d, pos], [nid, vid], "road", {})
            next_edge_id += 1
        if village_ids.size() > 1:
            village_ids.sort_custom(func(a_id, b_id):
                var va: Vector2 = nodes[a_id].pos2d - city.pos2d
                var vb: Vector2 = nodes[b_id].pos2d - city.pos2d
                return va.angle() < vb.angle()
            )
            for i in range(village_ids.size()):
                var a_id: int = village_ids[i]
                var b_id: int = village_ids[(i + 1) % village_ids.size()]
                var a_pos: Vector2 = nodes[a_id].pos2d
                var b_pos: Vector2 = nodes[b_id].pos2d
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [a_pos, b_pos], [a_id, b_id], "path", {})
                next_edge_id += 1
    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]

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
    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id + 1, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]

func remove_edge(roads: Dictionary, edge_id: int, crossroad_margin: float = 5.0) -> void:
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
        if node == null or node.type != "crossroad":
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
        # if more than two incident edges remain, keep crossroad as is

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

    var res2: Dictionary = _insert_crossroads(nodes, edges, roads.get("next_node_id", 1), roads.get("next_edge_id", 1))
    roads["next_node_id"] = res2["next_node_id"]
    roads["next_edge_id"] = res2["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

## Splits roads where they cross rivers and inserts bridge nodes.
func insert_river_crossings(roads: Dictionary, rivers: Array, crossroad_margin: float = 5.0) -> void:
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
                        if node != null and node.type != MapNodeModule.TYPE_BRIDGE and node.type != MapNodeModule.TYPE_FORD:
                            node.type = MapNodeModule.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNodeModule.TYPE_FORD
                            changed = true
                        continue

                    var cross_id: int = next_node_id
                    next_node_id += 1
                    var bridge_type: String = MapNodeModule.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNodeModule.TYPE_FORD
                    nodes[cross_id] = MapNodeModule.new(cross_id, bridge_type, cross, {})
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

    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

## Adds a fort near each road segment that crosses between different kingdoms.
func insert_border_forts(
    roads: Dictionary,
    regions: Dictionary,
    offset: float = 10.0,
    max_per_kingdom: int = 1,
    width: float = 100.0,
    height: float = 100.0
) -> void:
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
        cross.x = clamp(cross.x, 0.0, width)
        cross.y = clamp(cross.y, 0.0, height)
        var dir: Vector2 = (nodes[b_id].pos2d - nodes[a_id].pos2d).normalized()
        var junction_id: int = next_node_id
        next_node_id += 1
        nodes[junction_id] = MapNodeModule.new(junction_id, MapNodeModule.TYPE_CROSSROAD, cross, {})
        edges.erase(eid)
        edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [nodes[a_id].pos2d, cross], [a_id, junction_id], edge.road_class, edge.attrs)
        next_edge_id += 1
        edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, nodes[b_id].pos2d], [junction_id, b_id], edge.road_class, edge.attrs)
        next_edge_id += 1
        var spur_class: String = _lower_class(edge.road_class)
        var kid_a: int = a_region.kingdom_id
        if fort_counts.get(kid_a, 0) < max_per_kingdom:
            var fort_pos_a: Vector2 = cross - dir * offset
            fort_pos_a.x = clamp(fort_pos_a.x, 0.0, width)
            fort_pos_a.y = clamp(fort_pos_a.y, 0.0, height)
            var fort_id_a: int = next_node_id
            next_node_id += 1
            nodes[fort_id_a] = MapNodeModule.new(fort_id_a, MapNodeModule.TYPE_FORT, fort_pos_a, {})
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, fort_pos_a], [junction_id, fort_id_a], spur_class, edge.attrs)
            next_edge_id += 1
            fort_counts[kid_a] = fort_counts.get(kid_a, 0) + 1
        var kid_b: int = b_region.kingdom_id
        if fort_counts.get(kid_b, 0) < max_per_kingdom:
            var fort_pos_b: Vector2 = cross + dir * offset
            fort_pos_b.x = clamp(fort_pos_b.x, 0.0, width)
            fort_pos_b.y = clamp(fort_pos_b.y, 0.0, height)
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
func cleanup(roads: Dictionary, crossroad_margin: float = 5.0) -> void:
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

    var res: Dictionary = _insert_crossroads(nodes, edges, roads.get("next_node_id", 1), roads.get("next_edge_id", 1))
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

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

func _insert_crossroads(nodes: Dictionary, edges: Dictionary, next_node_id: int, next_edge_id: int) -> Dictionary:
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

                var cross_id: int = -1
                for nid in nodes.keys():
                    var n: MapNode = nodes[nid]
                    if n.pos2d.distance_to(cross) <= 0.5:
                        cross_id = nid
                        cross = n.pos2d
                        break
                var modified := false
                if cross_id == -1:
                    cross_id = next_node_id
                    next_node_id += 1
                    nodes[cross_id] = MapNodeModule.new(cross_id, MapNodeModule.TYPE_CROSSROAD, cross, {})
                    modified = true

                var a_ep0: int = edge_a.endpoints[0]
                var a_ep1: int = edge_a.endpoints[1]
                if cross_id != a_ep0 and cross_id != a_ep1:
                    edges.erase(id_a)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_a.type, [a_start, cross], [a_ep0, cross_id], edge_a.road_class, edge_a.attrs)
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_a.type, [cross, a_end], [cross_id, a_ep1], edge_a.road_class, edge_a.attrs)
                    next_edge_id += 1
                    modified = true

                var b_ep0: int = edge_b.endpoints[0]
                var b_ep1: int = edge_b.endpoints[1]
                if cross_id != b_ep0 and cross_id != b_ep1:
                    edges.erase(id_b)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_b.type, [b_start, cross], [b_ep0, cross_id], edge_b.road_class, edge_b.attrs)
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge_b.type, [cross, b_end], [cross_id, b_ep1], edge_b.road_class, edge_b.attrs)
                    next_edge_id += 1
                    modified = true

                if modified:
                    changed = true
                    break
            if changed:
                break
    if iterations == max_iterations:
        push_warning("[RoadNetwork] crossroad insertion iteration limit reached")
    return {
        "next_node_id": next_node_id,
        "next_edge_id": next_edge_id,
    }

func _prune_crossroad_duplicates(nodes: Dictionary, edges: Dictionary, margin: float) -> void:
    var city_edges: Dictionary = {}
    for id in edges.keys():
        var edge: Edge = edges[id]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_node: MapNode = nodes[a_id]
        var b_node: MapNode = nodes[b_id]
        if a_node.type == "city" and b_node.type == "city":
            city_edges[_pair_key(a_id, b_id)] = id

    var crossroad_links: Dictionary = {}
    for id in edges.keys():
        var edge: Edge = edges[id]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var a_node: MapNode = nodes[a_id]
        var b_node: MapNode = nodes[b_id]
        if a_node.type == "crossroad" and b_node.type == "city":
            if not crossroad_links.has(a_id):
                crossroad_links[a_id] = [] as Array[int]
            (crossroad_links[a_id] as Array[int]).append(b_id)
        elif b_node.type == "crossroad" and a_node.type == "city":
            if not crossroad_links.has(b_id):
                crossroad_links[b_id] = [] as Array[int]
            (crossroad_links[b_id] as Array[int]).append(a_id)

    for cross_id in crossroad_links.keys():
        var cities: Array[int] = crossroad_links[cross_id] as Array[int]
        for i in range(cities.size()):
            for j in range(i + 1, cities.size()):
                var a_id: int = cities[i]
                var b_id: int = cities[j]
                var key := _pair_key(a_id, b_id)
                if city_edges.has(key):
                    var direct_id: int = city_edges[key]
                    var direct_len: float = nodes[a_id].pos2d.distance_to(nodes[b_id].pos2d)
                    var crossroad_len: float = nodes[a_id].pos2d.distance_to(nodes[cross_id].pos2d) + \
                        nodes[cross_id].pos2d.distance_to(nodes[b_id].pos2d)
                    if crossroad_len - direct_len <= margin:
                        edges.erase(direct_id)
                        city_edges.erase(key)

func _point_on_endpoint(p: Vector2, a: Vector2, b: Vector2) -> bool:
    return p.distance_to(a) < 0.001 or p.distance_to(b) < 0.001
