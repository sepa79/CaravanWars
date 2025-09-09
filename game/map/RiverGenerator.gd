extends RefCounted
class_name RiverGenerator

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Generates simple river polylines. Intersections with roads are converted
## to `bridge` or `ford` nodes with nearby forts.
func generate_rivers(roads: Dictionary, count: int = 1) -> Array:
    var rivers: Array = []

    for _i in range(count):
        var start = Vector2(rng.randi_range(0, 100), rng.randi_range(0, 100))
        var end = Vector2(rng.randi_range(0, 100), rng.randi_range(0, 100))
        var polyline: Array[Vector2] = _river_polyline(start, end)
        _process_intersections(polyline, roads)
        rivers.append(polyline)

    return rivers

func _river_polyline(start: Vector2, end: Vector2, segments: int = 5) -> Array[Vector2]:
    var pts: Array[Vector2] = [start]
    for i in range(1, segments - 1):
        var t: float = float(i) / float(segments - 1)
        var mid: Vector2 = start.lerp(end, t)
        var offset: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
        pts.append(mid + offset)
    pts.append(end)
    return pts

func _process_intersections(poly: Array[Vector2], roads: Dictionary) -> void:
    var nodes: Dictionary = roads["nodes"]
    var edges: Dictionary = roads["edges"]
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)

    for edge_id in edges.keys():
        var edge: Edge = edges[edge_id]
        var road_start: Vector2 = edge.polyline[0]
        var road_end: Vector2 = edge.polyline[1]
        for i in range(poly.size() - 1):
            var river_a: Vector2 = poly[i]
            var river_b: Vector2 = poly[i + 1]
            var intersection: Variant = Geometry2D.segment_intersects_segment(river_a, river_b, road_start, road_end)
            if intersection != null:
                var cross: Vector2 = intersection
                # Use Python-style conditional expression; '?' operator is disallowed.
                var bridge_type: String = "bridge" if rng.randf() < 0.5 else "ford"
                var bridge_id: int = next_node_id
                next_node_id += 1
                var bridge_node: MapNode = MapNodeModule.new(bridge_id, bridge_type, cross, {})
                nodes[bridge_id] = bridge_node

                var start_id: int = edge.endpoints[0]
                var end_id: int = edge.endpoints[1]
                edges.erase(edge_id)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [road_start, cross], [start_id, bridge_id], {})
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [cross, road_end], [bridge_id, end_id], {})
                next_edge_id += 1

                var dir: Vector2 = (road_end - road_start).normalized()
                var perp: Vector2 = Vector2(-dir.y, dir.x)
                var fort_pos: Vector2 = cross + perp * 2.0
                var fort_id: int = next_node_id
                next_node_id += 1
                var fort_node: MapNode = MapNodeModule.new(fort_id, "fort", fort_pos, {})
                nodes[fort_id] = fort_node
                edges[next_edge_id] = EdgeModule.new(next_edge_id, "trade_route", [cross, fort_pos], [bridge_id, fort_id], {})
                next_edge_id += 1

                poly.insert(i + 1, cross)

    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id
