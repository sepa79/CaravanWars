extends RefCounted
class_name RiverGenerator

var rng: RandomNumberGenerator

const MapNode = preload("res://map/MapNode.gd")
const Edge = preload("res://map/Edge.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Generates simple river polylines. Intersections with roads are converted
## to `bridge` or `ford` nodes.
func generate_rivers(roads: Dictionary, count: int = 1, width: float = 100.0, height: float = 100.0) -> Array:
    var rivers: Array = []

    for _i in range(count):
        var start: Vector2 = Vector2(rng.randf_range(0.0, width), rng.randf_range(0.0, height))
        var edge_choice: int = rng.randi_range(0, 3)
        var end: Vector2
        match edge_choice:
            0:
                end = Vector2(rng.randf_range(0.0, width), 0.0)
            1:
                end = Vector2(rng.randf_range(0.0, width), height)
            2:
                end = Vector2(0.0, rng.randf_range(0.0, height))
            _:
                end = Vector2(width, rng.randf_range(0.0, height))
        var polyline: Array[Vector2] = _river_polyline(start, end, 5, width, height)
        _process_intersections(polyline, roads)
        rivers.append(polyline)

    return rivers

func _river_polyline(start: Vector2, end: Vector2, segments: int = 5, width: float = 100.0, height: float = 100.0) -> Array[Vector2]:
    var pts: Array[Vector2] = [start]
    for i in range(1, segments - 1):
        var t: float = float(i) / float(segments - 1)
        var mid: Vector2 = start.lerp(end, t)
        var offset: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
        var p: Vector2 = mid + offset
        p.x = clamp(p.x, 0.0, width)
        p.y = clamp(p.y, 0.0, height)
        pts.append(p)
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
                var bridge_type: String = MapNode.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNode.TYPE_FORD
                var bridge_id: int = next_node_id
                next_node_id += 1
                var bridge_node: MapNode = MapNode.new(bridge_id, bridge_type, cross, {})
                nodes[bridge_id] = bridge_node

                var start_id: int = edge.endpoints[0]
                var end_id: int = edge.endpoints[1]
                edges.erase(edge_id)
                edges[next_edge_id] = Edge.new(next_edge_id, edge.type, [road_start, cross], [start_id, bridge_id], edge.road_class, edge.attrs)
                next_edge_id += 1
                edges[next_edge_id] = Edge.new(next_edge_id, edge.type, [cross, road_end], [bridge_id, end_id], edge.road_class, edge.attrs)
                next_edge_id += 1

                poly.insert(i + 1, cross)

    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id
