extends RefCounted
class_name MapGenRiverGenerator

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://mapview/MapNode.gd")
const EdgeModule = preload("res://mapview/Edge.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Generates up to six rivers as curved splines derived from noise.  Each
## river is returned as a polyline sampled from a `Curve2D`.  Any road that
## intersects a river is split and a crossing node is inserted.  The
## crossing defaults to a bridge but can be changed later.
func generate_rivers(roads: Dictionary, count: int = 0, width: float = 100.0, height: float = 100.0) -> Array:
    var rivers: Array = []
    count = clamp(count, 0, 6)
    for rid in range(count):
        var start: Vector2 = _random_edge_point(width, height)
        var end: Vector2 = _random_edge_point(width, height)
        while start == end:
            end = _random_edge_point(width, height)

        var curve := Curve2D.new()
        curve.add_point(start)
        var noise := OpenSimplexNoise.new()
        noise.seed = rng.randi()
        noise.period = max(width, height)
        var steps := 8
        for i in range(1, steps):
            var t := float(i) / float(steps)
            var pos := start.lerp(end, t)
            var dir := (end - start).normalized()
            var perp := Vector2(-dir.y, dir.x)
            var nval := noise.get_noise_2d(pos.x, pos.y)
            var p := pos + perp * nval * 20.0
            p.x = clamp(p.x, 0.0, width)
            p.y = clamp(p.y, 0.0, height)
            curve.add_point(p)
        curve.add_point(end)
        var baked := curve.tessellate()
        var polyline: Array[Vector2] = []
        for p in baked:
            polyline.append(p)
        _process_intersections(polyline, roads, rid + 1)
        rivers.append(polyline)
    return rivers

func _random_edge_point(width: float, height: float) -> Vector2:
    var edge_choice: int = rng.randi_range(0, 3)
    match edge_choice:
        0:
            return Vector2(rng.randf_range(0.0, width), 0.0)
        1:
            return Vector2(rng.randf_range(0.0, width), height)
        2:
            return Vector2(0.0, rng.randf_range(0.0, height))
        _:
            return Vector2(width, rng.randf_range(0.0, height))

func _process_intersections(poly: Array[Vector2], roads: Dictionary, river_id: int) -> void:
    var nodes: Dictionary = roads["nodes"]
    var edges: Dictionary = roads["edges"]
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)

    for edge_id in edges.keys():
        var edge: MapViewEdge = edges[edge_id]
        var road_start: Vector2 = edge.polyline[0]
        var road_end: Vector2 = edge.polyline[1]
        for i in range(poly.size() - 1):
            var river_a: Vector2 = poly[i]
            var river_b: Vector2 = poly[i + 1]
            var intersection: Variant = Geometry2D.segment_intersects_segment(river_a, river_b, road_start, road_end)
            if intersection != null:
                var cross: Vector2 = intersection
                var cross_id: int = next_node_id
                next_node_id += 1
                var cross_node: MapViewNode = MapNodeModule.new(cross_id, MapNodeModule.TYPE_BRIDGE, cross, {"river_id": river_id})
                nodes[cross_id] = cross_node

                var start_id: int = edge.endpoints[0]
                var end_id: int = edge.endpoints[1]
                var attrs_a := edge.attrs.duplicate()
                attrs_a["crossing_id"] = cross_id
                var attrs_b := edge.attrs.duplicate()
                attrs_b["crossing_id"] = cross_id
                edges.erase(edge_id)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [road_start, cross], [start_id, cross_id], edge.road_class, attrs_a)
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, road_end], [cross_id, end_id], edge.road_class, attrs_b)
                next_edge_id += 1

                poly.insert(i + 1, cross)
                break

    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id
