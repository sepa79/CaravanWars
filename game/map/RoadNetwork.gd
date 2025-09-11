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
    crossroad_margin: float = 0.3,
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
    crossroad_margin: float = 0.3,
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

func _edge_length(poly: Array[Vector2]) -> float:
    var len: float = 0.0
    for i in range(poly.size() - 1):
        len += poly[i].distance_to(poly[i + 1])
    return len

func _point_along(poly: Array[Vector2], from_start: bool, distance: float) -> Vector2:
    var remaining: float = distance
    var pts: Array[Vector2] = poly.duplicate()
    if not from_start:
        pts.reverse()
    for i in range(pts.size() - 1):
        var seg_len: float = pts[i].distance_to(pts[i + 1])
        if remaining <= seg_len:
            var t: float = remaining / seg_len
            return pts[i].lerp(pts[i + 1], t)
        remaining -= seg_len
    return pts[pts.size() - 1]

func _incident_edges(edges: Dictionary, node_id: int) -> Array[int]:
    var result: Array[int] = []
    for eid in edges.keys():
        var e: Edge = edges[eid]
        if e.endpoints.has(node_id):
            result.append(eid)
    return result

func _downgrade_village_branches(roads: Dictionary, threshold: int = 2) -> void:
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

## Generates village clusters around each city and connects them to the road network.
func insert_villages(
    roads: Dictionary,
    rivers: Array,
    width: float = 100.0,
    height: float = 100.0
) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    for cid in nodes.keys():
        var city: MapNode = nodes[cid]
        if city.type != MapNodeModule.TYPE_CITY:
            continue
        var roman_edges: Array[int] = []
        for eid in edges.keys():
            var e: Edge = edges[eid]
            if e.road_class == "roman" and e.endpoints.has(cid):
                roman_edges.append(eid)
        if roman_edges.is_empty():
            continue
        var hub_count: int = rng.randi_range(1, min(2, roman_edges.size()))
        roman_edges.shuffle()
        var hubs: Array[int] = []
        for i in range(hub_count):
            var edge_id: int = roman_edges[i]
            var edge: Edge = edges[edge_id]
            var from_start: bool = edge.endpoints[0] == cid
            var length: float = _edge_length(edge.polyline)
            var dist: float = clamp(rng.randf_range(10.0, 25.0), 0.0, length - 0.1)
            var hub_pos: Vector2 = _point_along(edge.polyline, from_start, dist)
            var hub_id: int = next_node_id
            next_node_id += 1
            nodes[hub_id] = MapNodeModule.new(hub_id, MapNodeModule.TYPE_VILLAGE, hub_pos, {})
            hubs.append(hub_id)
            var start_id: int = edge.endpoints[0]
            var end_id: int = edge.endpoints[1]
            edges.erase(edge_id)
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [edge.polyline[0], hub_pos], [start_id, hub_id], edge.road_class, edge.attrs)
            next_edge_id += 1
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [hub_pos, edge.polyline[edge.polyline.size() - 1]], [hub_id, end_id], edge.road_class, edge.attrs)
            next_edge_id += 1

        var cluster: Array[int] = hubs.duplicate()
        for hub_id in hubs:
            var hub_pos: Vector2 = nodes[hub_id].pos2d
            var count: int = rng.randi_range(1, 3)
            var local: Array[Vector2] = []
            var attempts: int = 0
            while local.size() < count and attempts < count * 10:
                var r: float = rng.randf_range(2.0, 10.0)
                var ang: float = rng.randf() * TAU
                var pos: Vector2 = hub_pos + Vector2(cos(ang), sin(ang)) * r
                pos.x = clamp(pos.x, 0.0, width)
                pos.y = clamp(pos.y, 0.0, height)
                var ok := true
                for q in local:
                    if q.distance_to(pos) < 2.0:
                        ok = false
                        break
                if ok:
                    local.append(pos)
                attempts += 1
            for p in local:
                var vid: int = next_node_id
                next_node_id += 1
                nodes[vid] = MapNodeModule.new(vid, MapNodeModule.TYPE_VILLAGE, p, {})
                cluster.append(vid)

        for vid in cluster:
            var incident: Array[int] = _incident_edges(edges, vid)
            var on_roman: bool = false
            for eid in incident:
                if edges[eid].road_class == "roman":
                    on_roman = true
                    break
            if on_roman:
                continue
            var vpos: Vector2 = nodes[vid].pos2d
            var best_edge: int = -1
            var best_point: Vector2 = Vector2.ZERO
            var classes: Array[String] = ["roman", "road", "path"]
            for cls in classes:
                var best_dist: float = INF
                best_edge = -1
                for eid in edges.keys():
                    var edge2: Edge = edges[eid]
                    if edge2.road_class != cls:
                        continue
                    var q: Vector2 = _closest_point_on_polyline(vpos, edge2.polyline)
                    var d: float = vpos.distance_to(q)
                    if d < best_dist:
                        best_dist = d
                        best_edge = eid
                        best_point = q
                if best_edge != -1:
                    var edge3: Edge = edges[best_edge]
                    var cross_id: int = next_node_id
                    next_node_id += 1
                    nodes[cross_id] = MapNodeModule.new(cross_id, MapNodeModule.TYPE_CROSSROAD, best_point, {})
                    var a_id: int = edge3.endpoints[0]
                    var b_id: int = edge3.endpoints[1]
                    edges.erase(best_edge)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge3.type, [edge3.polyline[0], best_point], [a_id, cross_id], edge3.road_class, edge3.attrs)
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge3.type, [best_point, edge3.polyline[edge3.polyline.size() - 1]], [cross_id, b_id], edge3.road_class, edge3.attrs)
                    next_edge_id += 1
                    var branch_class: String = _lower_class(edge3.road_class)
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [vpos, best_point], [vid, cross_id], branch_class, {})
                    next_edge_id += 1
                    break

        var proposals: Array = []
        for i in range(cluster.size()):
            for j in range(i + 1, cluster.size()):
                var a: int = cluster[i]
                var b: int = cluster[j]
                var d: float = nodes[a].pos2d.distance_to(nodes[b].pos2d)
                if d >= 6.0 and d <= 12.0:
                    proposals.append({"a": a, "b": b, "d": d})
        proposals.sort_custom(func(x, y): return x["d"] < y["d"])
        var parent: Dictionary = {}
        for id in cluster:
            parent[id] = id
        func find_root_local(x):
            while parent[x] != x:
                x = parent[x]
            return x
        var mst: Array = []
        for p in proposals:
            var ra = find_root_local(p["a"])
            var rb = find_root_local(p["b"])
            if ra != rb:
                parent[rb] = ra
                mst.append(p)
        for p in mst:
            var a_id2: int = p["a"]
            var b_id2: int = p["b"]
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [nodes[a_id2].pos2d, nodes[b_id2].pos2d], [a_id2, b_id2], "path", {})
            next_edge_id += 1
        var remaining: Array = []
        for p in proposals:
            if not mst.has(p):
                remaining.append(p)
        var extra: int = int(round(mst.size() * 0.2))
        for i in range(min(extra, remaining.size())):
            var idx: int = rng.randi_range(0, remaining.size() - 1)
            var pextra = remaining[idx]
            edges[next_edge_id] = EdgeModule.new(next_edge_id, "road", [nodes[pextra["a"]].pos2d, nodes[pextra["b"]].pos2d], [pextra["a"], pextra["b"]], "path", {})
            next_edge_id += 1
            remaining.remove_at(idx)

    var res: Dictionary = _insert_crossroads(nodes, edges, next_node_id, next_edge_id)
    roads["next_node_id"] = res["next_node_id"]
    roads["next_edge_id"] = res["next_edge_id"]
    _downgrade_village_branches(roads)

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

func remove_edge(roads: Dictionary, edge_id: int, crossroad_margin: float = 0.3) -> void:
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
func insert_river_crossings(roads: Dictionary, rivers: Array, crossroad_margin: float = 0.3) -> void:
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
                    var seg1_id: int = next_edge_id
                    next_edge_id += 1
                    edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, road_end], [cross_id, b_id], edge.road_class, edge.attrs)
                    var seg2_id: int = next_edge_id
                    next_edge_id += 1
                    if bridge_type == MapNodeModule.TYPE_BRIDGE and edge.road_class == "road":
                        for sid in [seg1_id, seg2_id]:
                            var seg: Edge = edges[sid]
                            var idx: int = seg.endpoints[0] == cross_id ? 0 : 1
                            var other: int = seg.endpoints[1 - idx]
                            var len: float = nodes[cross_id].pos2d.distance_to(nodes[other].pos2d)
                            if len > 0.2:
                                var pos2: Vector2 = _point_along(seg.polyline, idx == 0, 0.2)
                                var approach_id: int = next_node_id
                                next_node_id += 1
                                nodes[approach_id] = MapNodeModule.new(approach_id, MapNodeModule.TYPE_CROSSROAD, pos2, {})
                                edges.erase(sid)
                                if idx == 0:
                                    edges[next_edge_id] = EdgeModule.new(next_edge_id, seg.type, [seg.polyline[0], pos2], [cross_id, approach_id], "road", seg.attrs)
                                    next_edge_id += 1
                                    edges[next_edge_id] = EdgeModule.new(next_edge_id, seg.type, [pos2, seg.polyline[seg.polyline.size() - 1]], [approach_id, other], _lower_class("road"), seg.attrs)
                                    next_edge_id += 1
                                else:
                                    edges[next_edge_id] = EdgeModule.new(next_edge_id, seg.type, [seg.polyline[0], pos2], [other, approach_id], _lower_class("road"), seg.attrs)
                                    next_edge_id += 1
                                    edges[next_edge_id] = EdgeModule.new(next_edge_id, seg.type, [pos2, seg.polyline[seg.polyline.size() - 1]], [approach_id, cross_id], "road", seg.attrs)
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
            var reg: Region = _region_for_point(n.pos2d, regions)
            if reg != null:
                city_counts[reg.kingdom_id] = city_counts.get(reg.kingdom_id, 0) + 1
    var caps: Dictionary = {}
    for kid in city_counts.keys():
        caps[kid] = max(1, int(ceil(city_counts[kid] * 0.5)))
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
        var spur_class: String = _lower_class(edge.road_class)
        var kid_a: int = a_region.kingdom_id
        var kid_b: int = b_region.kingdom_id
        var can_a: bool = fort_counts.get(kid_a, 0) < caps.get(kid_a, 0)
        var can_b: bool = fort_counts.get(kid_b, 0) < caps.get(kid_b, 0)
        var choose_a: bool = false
        if can_a and (not can_b or fort_counts.get(kid_a, 0) <= fort_counts.get(kid_b, 0)):
            choose_a = true
        elif not can_a and not can_b:
            continue
        var dist: float = 2.0 if edge.road_class == "roman" else (1.4 if edge.road_class == "road" else 1.0)
        if choose_a:
            var fort_pos: Vector2 = cross - dir * dist
            fort_pos.x = clamp(fort_pos.x, 0.0, width)
            fort_pos.y = clamp(fort_pos.y, 0.0, height)
            var fort_id: int = next_node_id
            next_node_id += 1
            nodes[fort_id] = MapNodeModule.new(fort_id, MapNodeModule.TYPE_FORT, fort_pos, {})
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [nodes[a_id].pos2d, cross, fort_pos], [a_id, fort_id], spur_class, edge.attrs)
            next_edge_id += 1
            fort_counts[kid_a] = fort_counts.get(kid_a, 0) + 1
        else:
            var fort_pos_b: Vector2 = cross + dir * dist
            fort_pos_b.x = clamp(fort_pos_b.x, 0.0, width)
            fort_pos_b.y = clamp(fort_pos_b.y, 0.0, height)
            var fort_id_b: int = next_node_id
            next_node_id += 1
            nodes[fort_id_b] = MapNodeModule.new(fort_id_b, MapNodeModule.TYPE_FORT, fort_pos_b, {})
            edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [nodes[b_id].pos2d, cross, fort_pos_b], [b_id, fort_id_b], spur_class, edge.attrs)
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
func cleanup(roads: Dictionary, crossroad_margin: float = 0.3) -> void:
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
                    if n.pos2d.distance_to(cross) <= 0.3:
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
