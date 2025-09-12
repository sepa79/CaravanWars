extends RefCounted
class_name RoadNetwork

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")
const CityPlacerModule = preload("res://map/CityPlacer.gd")
const MapUtils = preload("res://map/MapUtils.gd")

const _CLASS_PRIORITY := {
    "path": 1,
    "road": 2,
    "roman": 3,
}

func _class_rank(cls: String) -> int:
    return _CLASS_PRIORITY.get(cls, 0)

func _lower_of(a: String, b: String) -> String:
    return a if _class_rank(a) <= _class_rank(b) else b

func _highest_class_at_node(edges: Dictionary, node_id: int) -> String:
    var max_rank := 0
    var result := ""
    for e in edges.values():
        if e.endpoints.has(node_id):
            var r := _class_rank(e.road_class)
            if r > max_rank:
                max_rank = r
                result = e.road_class
    return result

func _branch_class_at_node(edges: Dictionary, node_id: int, default_class: String) -> String:
    var highest := _highest_class_at_node(edges, node_id)
    match highest:
        "roman":
            return "road"
        "road":
            return "path"
        "path":
            return "path"
        _:
            return default_class

func _resolve_branch_class(nodes: Dictionary, edges: Dictionary, a_id: int, b_id: int, proposed: String) -> String:
    var a_node: MapNode = nodes.get(a_id)
    var b_node: MapNode = nodes.get(b_id)
    if a_node != null and b_node != null and a_node.type == MapNodeModule.TYPE_CITY and b_node.type == MapNodeModule.TYPE_CITY:
        return proposed
    var class_a := _branch_class_at_node(edges, a_id, proposed)
    var class_b := _branch_class_at_node(edges, b_id, proposed)
    return _lower_of(class_a, class_b)

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
    var cls := _resolve_branch_class(nodes, edges, start.id, end.id, road_class)
    edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [start.pos2d, end.pos2d], [start.id, end.id], cls, {})
    next_edge_id += 1
    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

func _closest_point_on_polyline(p: Vector2, line: Array[Vector2]) -> Vector2:
    var best := line[0]
    var best_dist := p.distance_to(best)
    for i in range(line.size() - 1):
        var a: Vector2 = line[i]
        var b: Vector2 = line[i + 1]
        var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
        var d: float = p.distance_to(q)
        if d < best_dist:
            best_dist = d
            best = q
    return best

func _crossing_allowed(
    cross: Vector2,
    crossing_type: String,
    river_idx: int,
    river_dist: float,
    crossings: Dictionary,
    nodes: Dictionary
) -> bool:
    var existing: Array = crossings.get(river_idx, [])
    var nearest_bridge := INF
    for info in existing:
        var along: float = abs(info["distance"] - river_dist)
        if info["type"] == MapNodeModule.TYPE_BRIDGE:
            nearest_bridge = min(nearest_bridge, along)
            if crossing_type == MapNodeModule.TYPE_BRIDGE and along < 10.0:
                return false
            if crossing_type == MapNodeModule.TYPE_FORD and along < 4.0:
                return false
        else:
            if crossing_type == MapNodeModule.TYPE_BRIDGE and along < 6.0:
                return false
            if crossing_type == MapNodeModule.TYPE_FORD and along < 6.0:
                return false
    if nearest_bridge < 8.0:
        return false
    for n in nodes.values():
        if n.type == MapNodeModule.TYPE_FORT and n.pos2d.distance_to(cross) < 2.5:
            return false
    return true

func _downgrade_village_branches(roads: Dictionary, threshold: int) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var degree: Dictionary = {}
    for e in edges.values():
        for nid in e.endpoints:
            degree[nid] = degree.get(nid, 0) + 1
    for e in edges.values():
        if e.road_class != "road":
            continue
        var a_id: int = e.endpoints[0]
        var b_id: int = e.endpoints[1]
        var a_node: MapNode = nodes[a_id]
        var b_node: MapNode = nodes[b_id]
        if a_node.type == MapNodeModule.TYPE_VILLAGE and degree.get(a_id, 0) <= threshold:
            e.road_class = "path"
        elif b_node.type == MapNodeModule.TYPE_VILLAGE and degree.get(b_id, 0) <= threshold:
            e.road_class = "path"

## Samples a global Poisson-disk layer of villages and connects each to
## the nearest Roman road or town. Low-traffic branches downgrade to paths.
func insert_villages(
    roads: Dictionary,
    min_per_city: int,
    max_per_city: int,
    r_min: float = 8.0,
    r_peak: float = 22.0,
    r_max: float = 40.0,
    width: float = 100.0,
    height: float = 100.0,
    downgrade_threshold: int = 1
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var placer := CityPlacerModule.new(rng)

    for cid in nodes.keys():
        var city: MapNode = nodes[cid]
        if city.type != MapNodeModule.TYPE_CITY:
            continue
        var count: int = rng.randi_range(min_per_city, max_per_city)
        if count <= 0:
            continue

        var attempts: Array[Vector2] = placer.place_cities(count * 2, r_min, r_max, r_max * 2.0, r_max * 2.0)
        var chosen: Array[Vector2] = []
        for p in attempts:
            var rel: Vector2 = p - Vector2(r_max, r_max)
            var dist: float = rel.length()
            if dist < r_min or dist > r_max:
                continue
            var weight: float = 1.0 - abs(dist - r_peak) / (r_max - r_min)
            if rng.randf() <= max(0.0, weight):
                chosen.append(rel)
            if chosen.size() >= count:
                break
        while chosen.size() < count:
            var angle: float = rng.randf() * TAU
            var rad: float = rng.randf_range(r_min, r_max)
            chosen.append(Vector2(cos(angle), sin(angle)) * rad)

        var cluster: Array[int] = []
        for rel in chosen:
            var pos: Vector2 = city.pos2d + rel
            pos = MapUtils.ensure_within_bounds(pos, width, height)
            var vid: int = next_node_id
            next_node_id += 1
            nodes[vid] = MapNodeModule.new(vid, MapNodeModule.TYPE_VILLAGE, pos, {})
            cluster.append(vid)

        var connected: Array[int] = []
        for vid in cluster:
            var vpos: Vector2 = nodes[vid].pos2d
            var best_edge: int = -1
            var best_point: Vector2 = Vector2.ZERO
            var best_dist: float = INF
            for eid in edges.keys():
                var edge: Edge = edges[eid]
                var q: Vector2 = _closest_point_on_polyline(vpos, edge.polyline)
                q = MapUtils.ensure_within_bounds(q, width, height)
                var d: float = vpos.distance_to(q)
                if d < best_dist:
                    best_dist = d
                    best_edge = eid
                    best_point = q
            if best_edge != -1 and best_dist <= r_max:
                var edge: Edge = edges[best_edge]
                var cross_id: int = next_node_id
                next_node_id += 1
                best_point = MapUtils.ensure_within_bounds(best_point, width, height)
                nodes[cross_id] = MapNodeModule.new(cross_id, MapNodeModule.TYPE_CROSSROAD, best_point, {})
                var start: Vector2 = edge.polyline[0]
                var end: Vector2 = edge.polyline[edge.polyline.size() - 1]
                var start_id: int = edge.endpoints[0]
                var end_id: int = edge.endpoints[1]
                edges.erase(best_edge)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [start, best_point], [start_id, cross_id], edge.road_class, edge.attrs)
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [best_point, end], [cross_id, end_id], edge.road_class, edge.attrs)
                next_edge_id += 1
                var v_cls := _resolve_branch_class(nodes, edges, vid, cross_id, "road")
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [vpos, best_point], [vid, cross_id], v_cls, {})
                next_edge_id += 1
                connected.append(vid)

        if connected.is_empty() and cluster.size() > 0:
            var nearest: int = cluster[0]
            var best: float = INF
            for vid in cluster:
                var d: float = nodes[vid].pos2d.distance_to(city.pos2d)
                if d < best:
                    best = d
                    nearest = vid
            var a_point := MapUtils.ensure_within_bounds(nodes[nearest].pos2d, width, height)
            var b_point := MapUtils.ensure_within_bounds(city.pos2d, width, height)
            var n_cls := _resolve_branch_class(nodes, edges, nearest, cid, "road")
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [a_point, b_point], [nearest, cid], n_cls, {})
            next_edge_id += 1
            connected.append(nearest)

        var candidates: Array[Dictionary] = []
        for i in range(cluster.size()):
            for j in range(i + 1, cluster.size()):
                var a_id: int = cluster[i]
                var b_id: int = cluster[j]
                var dist: float = nodes[a_id].pos2d.distance_to(nodes[b_id].pos2d)
                if dist < 6.0 or dist > 12.0:
                    continue
                candidates.append({"dist": dist, "a": a_id, "b": b_id})
        candidates.sort_custom(func(x, y): return x["dist"] < y["dist"])  # ascending

        var parent: Dictionary = {}
        for vid in cluster:
            parent[vid] = vid
        
        var find = func(v):
            while parent[v] != v:
                v = parent[v]
            return v

        var unite = func(a, b):
            parent[find.call(a)] = find.call(b)

        var mst: Array[Dictionary] = []
        for c in candidates:
            var a_root = find.call(c["a"])
            var b_root = find.call(c["b"])
            if a_root != b_root:
                unite.call(a_root, b_root)
                mst.append(c)

        for c in mst:
            var a_id = c["a"]
            var b_id = c["b"]
            var a_pos := MapUtils.ensure_within_bounds(nodes[a_id].pos2d, width, height)
            var b_pos := MapUtils.ensure_within_bounds(nodes[b_id].pos2d, width, height)
            var p_cls := _resolve_branch_class(nodes, edges, a_id, b_id, "path")
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "path", [a_pos, b_pos], [a_id, b_id], p_cls, {})
            next_edge_id += 1

        var remaining: Array[Dictionary] = []
        for c in candidates:
            if mst.has(c):
                continue
            remaining.append(c)
        var extra_count: int = int(ceil(float(mst.size()) * 0.2))
        var added: int = 0
        for c in remaining:
            if added >= extra_count:
                break
            var a_id = c["a"]
            var b_id = c["b"]
            var a_pos := MapUtils.ensure_within_bounds(nodes[a_id].pos2d, width, height)
            var b_pos := MapUtils.ensure_within_bounds(nodes[b_id].pos2d, width, height)
            var p_cls := _resolve_branch_class(nodes, edges, a_id, b_id, "path")
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "path", [a_pos, b_pos], [a_id, b_id], p_cls, {})
            next_edge_id += 1
            added += 1

        if mst.size() + added < cluster.size():
            for c in remaining.slice(added, remaining.size()):
                if c["dist"] > 8.0:
                    continue
                var a_id = c["a"]
                var b_id = c["b"]
                var a_pos := MapUtils.ensure_within_bounds(nodes[a_id].pos2d, width, height)
                var b_pos := MapUtils.ensure_within_bounds(nodes[b_id].pos2d, width, height)
                var p_cls := _resolve_branch_class(nodes, edges, a_id, b_id, "path")
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "path", [a_pos, b_pos], [a_id, b_id], p_cls, {})
                next_edge_id += 1
                break

    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _downgrade_village_branches(roads, downgrade_threshold)

## Inserts a node in the middle of an edge and splits the edge.
func insert_node_on_edge(roads: Dictionary, edge_id: int, node_type: String, width: float = 100.0, height: float = 100.0) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var edge: Edge = edges.get(edge_id)
    if edge == null:
        return
    var start: Vector2 = MapUtils.ensure_within_bounds(edge.polyline[0], width, height)
    var end: Vector2 = MapUtils.ensure_within_bounds(edge.polyline[edge.polyline.size() - 1], width, height)
    var pos: Vector2 = MapUtils.ensure_within_bounds((start + end) * 0.5, width, height)
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

## Splits roads where they cross rivers and inserts bridge or ford nodes.
## Also splits the river polyline at the crossing point, snapping to nearby
## river vertices within 0.3 U to avoid sharp bends.
func insert_river_crossings(
    roads: Dictionary,
    rivers: Array,
    width: float = 100.0,
    height: float = 100.0,
    crossroad_margin: float = 5.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var crossings_by_river: Dictionary = {}

    var changed := true
    while changed:
        changed = false
        var edge_ids: Array = edges.keys()
        for eid in edge_ids:
            var edge: Edge = edges[eid]
            var road_start: Vector2 = edge.polyline[0]
            var road_end: Vector2 = edge.polyline[edge.polyline.size() - 1]
            for r_idx in range(rivers.size()):
                var poly: Array = rivers[r_idx]
                for i in range(poly.size() - 1):
                    var river_a: Vector2 = poly[i]
                    var river_b: Vector2 = poly[i + 1]
                    var inter: Variant = Geometry2D.segment_intersects_segment(road_start, road_end, river_a, river_b)
                    if inter == null:
                        continue
                    var cross: Vector2 = MapUtils.ensure_within_bounds(inter, width, height)
                    if _point_on_endpoint(cross, road_start, road_end):
                        var node_id: int = edge.endpoints[0] if cross == road_start else edge.endpoints[1]
                        var node: MapNode = nodes.get(node_id)
                        if node != null and node.type != MapNodeModule.TYPE_BRIDGE and node.type != MapNodeModule.TYPE_FORD:
                            node.type = MapNodeModule.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNodeModule.TYPE_FORD
                            changed = true
                        continue

                    if cross.distance_to(river_a) <= 0.3:
                        cross = river_a
                    elif cross.distance_to(river_b) <= 0.3:
                        cross = river_b
                    else:
                        poly.insert(i + 1, cross)

                    var bridge_type: String = MapNodeModule.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNodeModule.TYPE_FORD
                    var river_dist: float = MapUtils.distance_along_polyline(poly, i, cross)
                    if edge.road_class != "roman" and not _crossing_allowed(cross, bridge_type, r_idx, river_dist, crossings_by_river, nodes):
                        edges.erase(eid)
                        changed = true
                        break

                    var cross_id: int = next_node_id
                    next_node_id += 1
                    nodes[cross_id] = MapNodeModule.new(cross_id, bridge_type, cross, {})
                    var a_id: int = edge.endpoints[0]
                    var b_id: int = edge.endpoints[1]
                    edges.erase(eid)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [road_start, cross], [a_id, cross_id], edge.road_class, edge.attrs)
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, road_end], [cross_id, b_id], edge.road_class, edge.attrs)
                    next_edge_id += 1
                    if not crossings_by_river.has(r_idx):
                        crossings_by_river[r_idx] = []
                    (crossings_by_river[r_idx] as Array).append({"distance": river_dist, "type": bridge_type})
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
    width: float = 100.0,
    height: float = 100.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)

    var city_counts: Dictionary = {}
    for n in nodes.values():
        if n.type == MapNodeModule.TYPE_CITY:
            var r: Region = _region_for_point(n.pos2d, regions)
            if r != null:
                city_counts[r.kingdom_id] = city_counts.get(r.kingdom_id, 0) + 1

    var caps: Dictionary = {}
    for kid in city_counts.keys():
        caps[kid] = max(1, int(ceil(city_counts[kid] * 0.5)))

    var forts_by_kingdom: Dictionary = {}
    var placed: Array = []

    var candidates: Array = []
    for eid in edges.keys():
        var edge: Edge = edges[eid]
        var a_id: int = edge.endpoints[0]
        var b_id: int = edge.endpoints[1]
        var reg_a: Region = _region_for_point(nodes[a_id].pos2d, regions)
        var reg_b: Region = _region_for_point(nodes[b_id].pos2d, regions)
        if reg_a == null or reg_b == null:
            continue
        if reg_a.kingdom_id == reg_b.kingdom_id:
            continue
        var cross: Vector2 = _border_intersection(nodes[a_id].pos2d, nodes[b_id].pos2d, reg_a)
        cross = MapUtils.ensure_within_bounds(cross, width, height)
        candidates.append({
            "pos": cross,
            "edge": eid,
            "class": edge.road_class,
            "a": a_id,
            "b": b_id,
            "kids": [reg_a.kingdom_id, reg_b.kingdom_id],
        })

    candidates.sort_custom(func(a, b):
        var p := {"roman": 0, "road": 1, "path": 2}
        return p.get(a["class"], 3) < p.get(b["class"], 3)
    )

    for cand in candidates:
        var cross: Vector2 = cand["pos"]
        var cls: String = cand["class"]
        var edge: Edge = edges.get(cand["edge"], null)
        if edge == null:
            continue
        var ids: Array = cand["kids"]
        for side in [0, 1]:
            var kid: int = ids[side]
            var cap: int = caps.get(kid, 0)
            if cap == 0:
                continue
            if forts_by_kingdom.get(kid, 0) >= cap:
                continue
            var blocked := false
            for f in placed:
                var d: float = f["pos"].distance_to(cross)
                if d < 2.0:
                    blocked = true
                    break
                if f["kingdom"] == kid and d < 8.0:
                    blocked = true
                    break
                if f["kingdom"] != kid and d <= 3.0:
                    blocked = true
                    break
            if blocked:
                continue
            for n in nodes.values():
                if n.type == MapNodeModule.TYPE_BRIDGE or n.type == MapNodeModule.TYPE_FORD:
                    if n.pos2d.distance_to(cross) < 2.5:
                        blocked = true
                        break
            if blocked:
                continue
            var src_id: int = cand["a"] if side == 0 else cand["b"]
            var dir: Vector2 = (nodes[src_id].pos2d - cross).normalized()
            var along: float = 2.0 if cls == "roman" else 1.4 if cls == "road" else 1.0
            var anchor: Vector2 = MapUtils.ensure_within_bounds(cross + dir * along, width, height)
            var lateral_dir: Vector2 = Vector2(-dir.y, dir.x)
            var lateral_sign: float = 1.0 if forts_by_kingdom.get(kid, 0) % 2 == 0 else -1.0
            var fort_pos: Vector2 = MapUtils.ensure_within_bounds(anchor + lateral_dir * 0.2 * lateral_sign, width, height)
            var fort_id: int = next_node_id
            next_node_id += 1
            nodes[fort_id] = MapNodeModule.new(fort_id, MapNodeModule.TYPE_FORT, fort_pos, {})
            var start_point := MapUtils.ensure_within_bounds(nodes[src_id].pos2d, width, height)
            var spur_cls := _resolve_branch_class(nodes, edges, src_id, fort_id, _lower_class(cls))
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [start_point, anchor, fort_pos], [src_id, fort_id], spur_cls, {})
            next_edge_id += 1
            forts_by_kingdom[kid] = forts_by_kingdom.get(kid, 0) + 1
            placed.append({"pos": cross, "kingdom": kid})

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
func cleanup(
    roads: Dictionary,
    crossroad_margin: float = 5.0,
    width: float = 100.0,
    height: float = 100.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)

    var split := _split_near_x_junctions(nodes, edges, next_node_id, next_edge_id, width, height)
    next_node_id = split["next_node_id"]
    next_edge_id = split["next_edge_id"]

    var remove_edges: Array[int] = []
    var lengths: Dictionary = {}
    for eid in edges.keys():
        var edge: Edge = edges[eid]
        var endpoints: Array[int] = edge.endpoints
        if endpoints.size() != 2 or not nodes.has(endpoints[0]) or not nodes.has(endpoints[1]):
            remove_edges.append(eid)
            continue
        var length: float = 0.0
        for i in range(edge.polyline.size() - 1):
            length += edge.polyline[i].distance_to(edge.polyline[i + 1])
        lengths[eid] = length
        if length <= 0.001:
            remove_edges.append(eid)
    for eid in remove_edges:
        edges.erase(eid)
    remove_edges.clear()

    next_edge_id = _bridge_parallel_links(nodes, edges, lengths, next_edge_id, 1.0)

    var degree: Dictionary = {}
    for e in edges.values():
        degree[e.endpoints[0]] = degree.get(e.endpoints[0], 0) + 1
        degree[e.endpoints[1]] = degree.get(e.endpoints[1], 0) + 1

    for eid in edges.keys():
        var length: float = lengths.get(eid, 0.0)
        if length >= 0.4:
            continue
        var edge: Edge = edges[eid]
        for idx in range(2):
            var nid: int = edge.endpoints[idx]
            if degree.get(nid, 0) != 1:
                continue
            var node: MapNode = nodes.get(nid)
            if node == null:
                continue
            var t: String = node.type
            if t in [MapNodeModule.TYPE_VILLAGE, MapNodeModule.TYPE_BRIDGE, MapNodeModule.TYPE_FORD, MapNodeModule.TYPE_FORT]:
                continue
            remove_edges.append(eid)
            break
    for eid in remove_edges:
        var e: Edge = edges[eid]
        edges.erase(eid)
        for nid in e.endpoints:
            degree[nid] = max(0, degree.get(nid, 0) - 1)

    var used: Dictionary = {}
    for e in edges.values():
        used[e.endpoints[0]] = true
        used[e.endpoints[1]] = true

    for nid in nodes.keys():
        if nodes[nid].type != "city" and not used.has(nid):
            nodes.erase(nid)

    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _prune_crossroad_duplicates(nodes, edges, crossroad_margin)

## Merges nodes that lie closer than `tolerance` and updates connected edges.
func merge_close_nodes(roads: Dictionary, tolerance: float = 0.3) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var changed := true
    while changed:
        changed = false
        var ids: Array = nodes.keys()
        for i in range(ids.size()):
            var id_a: int = ids[i]
            if not nodes.has(id_a):
                continue
            var node_a: MapNode = nodes[id_a]
            for j in range(i + 1, ids.size()):
                var id_b: int = ids[j]
                if not nodes.has(id_b):
                    continue
                var node_b: MapNode = nodes[id_b]
                if node_a.pos2d.distance_to(node_b.pos2d) <= tolerance:
                    _merge_node_pair(nodes, edges, id_a, id_b)
                    changed = true
                    break
            if changed:
                break
    _remove_duplicate_edges(edges)

func _merge_node_pair(nodes: Dictionary, edges: Dictionary, keep_id: int, remove_id: int) -> void:
    var keep: MapNode = nodes[keep_id]
    var remove: MapNode = nodes[remove_id]
    for eid in edges.keys():
        if not edges.has(eid):
            continue
        var edge: Edge = edges[eid]
        for idx in range(2):
            if edge.endpoints[idx] == remove_id:
                edge.endpoints[idx] = keep_id
                if idx == 0:
                    edge.polyline[0] = keep.pos2d
                else:
                    edge.polyline[edge.polyline.size() - 1] = keep.pos2d
        if edge.endpoints[0] == edge.endpoints[1]:
            edges.erase(eid)
    nodes.erase(remove_id)

func _remove_duplicate_edges(edges: Dictionary) -> void:
    var seen: Dictionary = {}
    for eid in edges.keys():
        if not edges.has(eid):
            continue
        var edge: Edge = edges[eid]
        var key := _pair_key(edge.endpoints[0], edge.endpoints[1])
        if seen.has(key):
            edges.erase(eid)
        else:
            seen[key] = eid

func _edge_length(edge: Edge) -> float:
    var length: float = 0.0
    for i in range(edge.polyline.size() - 1):
        length += edge.polyline[i].distance_to(edge.polyline[i + 1])
    return length

func _split_near_x_junctions(
    nodes: Dictionary,
    edges: Dictionary,
    next_node_id: int,
    next_edge_id: int,
    width: float,
    height: float,
    offset: float = 0.3
) -> Dictionary:
    var node_ids: Array = nodes.keys()
    for nid in node_ids:
        if not nodes.has(nid):
            continue
        var node: MapNode = nodes[nid]
        var incident: Array[int] = []
        for eid in edges.keys():
            var e: Edge = edges[eid]
            if e.endpoints.has(nid):
                incident.append(eid)
        if incident.size() != 4:
            continue
        var dirs: Array[Vector2] = []
        var other_ids: Array[int] = []
        for eid in incident:
            var e: Edge = edges[eid]
            var other: int = e.endpoints[0] if e.endpoints[1] == nid else e.endpoints[1]
            other_ids.append(other)
            dirs.append((nodes[other].pos2d - node.pos2d).normalized())
        var best_i := 0
        var best_j := 1
        var best_score: float = abs(PI - dirs[0].angle_to(dirs[1]))
        for i in range(dirs.size()):
            for j in range(i + 1, dirs.size()):
                var score: float = abs(PI - dirs[i].angle_to(dirs[j]))
                if score < best_score:
                    best_score = score
                    best_i = i
                    best_j = j
        if best_score > deg_to_rad(30.0):
            continue
        var pair_a: Array[int] = [incident[best_i], incident[best_j]]
        var remaining_indices: Array[int] = []
        for idx in range(incident.size()):
            if idx != best_i and idx != best_j:
                remaining_indices.append(idx)
        var pair_b: Array[int] = [incident[remaining_indices[0]], incident[remaining_indices[1]]]
        var dir_b: Vector2 = (dirs[remaining_indices[0]] + dirs[remaining_indices[1]]).normalized()
        var new_pos: Vector2 = MapUtils.ensure_within_bounds(node.pos2d + dir_b * offset, width, height)
        nodes[next_node_id] = MapNodeModule.new(next_node_id, MapNodeModule.TYPE_CROSSROAD, new_pos, {})
        for eid in pair_b:
            var e: Edge = edges[eid]
            var idx_ep: int = 0 if e.endpoints[0] == nid else 1
            e.endpoints[idx_ep] = next_node_id
            if idx_ep == 0:
                e.polyline[0] = new_pos
            else:
                e.polyline[e.polyline.size() - 1] = new_pos
        var cls := _resolve_branch_class(
            nodes,
            edges,
            nid,
            next_node_id,
            _lower_of(edges[pair_a[0]].road_class, edges[pair_a[1]].road_class)
        )
        edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [node.pos2d, new_pos], [nid, next_node_id], cls, {})
        next_edge_id += 1
        next_node_id += 1
    return {"next_node_id": next_node_id, "next_edge_id": next_edge_id}

func _bridge_parallel_links(nodes: Dictionary, edges: Dictionary, lengths: Dictionary, next_edge_id: int, threshold: float) -> int:
    var edge_ids: Array = edges.keys()
    var i: int = 0
    while i < edge_ids.size():
        var id_a: int = edge_ids[i]
        if not edges.has(id_a):
            i += 1
            continue
        var edge_a: Edge = edges[id_a]
        var a0: Vector2 = nodes[edge_a.endpoints[0]].pos2d
        var a1: Vector2 = nodes[edge_a.endpoints[1]].pos2d
        var dir_a: Vector2 = (a1 - a0).normalized()
        var j: int = i + 1
        while j < edge_ids.size():
            var id_b: int = edge_ids[j]
            if not edges.has(id_b):
                j += 1
                continue
            var edge_b: Edge = edges[id_b]
            var b0: Vector2 = nodes[edge_b.endpoints[0]].pos2d
            var b1: Vector2 = nodes[edge_b.endpoints[1]].pos2d
            var dir_b: Vector2 = (b1 - b0).normalized()
            if abs(dir_a.dot(dir_b)) < 0.95:
                j += 1
                continue
            var pair := Geometry2D.get_closest_points_between_segments(a0, a1, b0, b1)
            var dist: float = pair[0].distance_to(pair[1])
            if dist > threshold:
                j += 1
                continue
            var len_a: float = lengths.get(id_a, _edge_length(edge_a))
            var len_b: float = lengths.get(id_b, _edge_length(edge_b))
            var keep: Edge = edge_a
            var keep_id: int = id_a
            var remove: Edge = edge_b
            var remove_id: int = id_b
            if len_a < len_b:
                keep = edge_b
                keep_id = id_b
                remove = edge_a
                remove_id = id_a
            var best: Vector2i = Vector2i(remove.endpoints[0], keep.endpoints[0])
            var best_d: float = nodes[best.x].pos2d.distance_to(nodes[best.y].pos2d)
            for rn in remove.endpoints:
                for kn in keep.endpoints:
                    var d: float = nodes[rn].pos2d.distance_to(nodes[kn].pos2d)
                    if d < best_d:
                        best_d = d
                        best = Vector2i(rn, kn)
            if best_d <= threshold:
                var a_pos: Vector2 = nodes[best.x].pos2d
                var b_pos: Vector2 = nodes[best.y].pos2d
                var cls := _resolve_branch_class(nodes, edges, best.x, best.y, _lower_of(remove.road_class, keep.road_class))
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [a_pos, b_pos], [best.x, best.y], cls, {})
                lengths[next_edge_id] = a_pos.distance_to(b_pos)
                next_edge_id += 1
            edges.erase(remove_id)
            lengths.erase(remove_id)
            edge_ids = edges.keys()
            i = -1
            break
        i += 1
    return next_edge_id

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
