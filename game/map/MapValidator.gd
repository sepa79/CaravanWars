extends RefCounted
class_name MapValidator

func validate(roads: Dictionary, rivers: Array) -> Array[String]:
    var errors: Array[String] = []
    if not _road_network_connected(roads):
        errors.append("road network disconnected")
    if not _no_dangling_edges(roads):
        errors.append("dangling edges present")
    if not _valid_river_intersections(roads, rivers):
        errors.append("river-road intersection missing bridge or ford")
    return errors

func _road_network_connected(roads: Dictionary) -> bool:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    if nodes.is_empty():
        return true
    var adjacency: Dictionary = {}
    for edge in edges.values():
        var a: int = edge.endpoints[0]
        var b: int = edge.endpoints[1]
        if not adjacency.has(a):
            adjacency[a] = []
        if not adjacency.has(b):
            adjacency[b] = []
        adjacency[a].append(b)
        adjacency[b].append(a)
    var visited: Dictionary = {}
    var to_visit: Array[int] = [nodes.keys()[0]]
    while to_visit.size() > 0:
        var current: int = to_visit.pop_back()
        if visited.has(current):
            continue
        visited[current] = true
        for neighbor in adjacency.get(current, []):
            if not visited.has(neighbor):
                to_visit.append(neighbor)
    return visited.size() == nodes.size()

func _no_dangling_edges(roads: Dictionary) -> bool:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        if edge.endpoints.size() != 2:
            return false
        var start_id: int = edge.endpoints[0]
        var end_id: int = edge.endpoints[1]
        if not nodes.has(start_id) or not nodes.has(end_id):
            return false
        var start_node: MapNode = nodes[start_id]
        var end_node: MapNode = nodes[end_id]
        if edge.polyline.size() < 2:
            return false
        var a: Vector2 = edge.polyline[0]
        var b: Vector2 = edge.polyline[edge.polyline.size() - 1]
        if a != start_node.pos2d or b != end_node.pos2d:
            return false
    return true

func _valid_river_intersections(roads: Dictionary, rivers: Array) -> bool:
    var nodes: Dictionary = roads.get("nodes", {})
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        var road_start: Vector2 = edge.polyline[0]
        var road_end: Vector2 = edge.polyline[1]
        for poly in rivers:
            for i in range(poly.size() - 1):
                var river_a: Vector2 = poly[i]
                var river_b: Vector2 = poly[i + 1]
                var cross: Variant = Geometry2D.segment_intersects_segment(river_a, river_b, road_start, road_end)
                if cross != null:
                    var intersection: Vector2 = cross
                    if intersection != road_start and intersection != road_end:
                        return false
                    var node_index: int = edge.endpoints[0] if intersection == road_start else edge.endpoints[1]
                    var node: MapNode = nodes[node_index]
                    if node.type != "bridge" and node.type != "ford":
                        return false
    return true
