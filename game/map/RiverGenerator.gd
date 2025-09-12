extends RefCounted
class_name RiverGenerator

var rng: RandomNumberGenerator

const MapNodeModule = preload("res://map/MapNode.gd")
const EdgeModule = preload("res://map/Edge.gd")
const MapUtils = preload("res://map/MapUtils.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Generates simple river polylines. Intersections with roads are converted
## to `bridge` or `ford` nodes.
func generate_rivers(roads: Dictionary, count: int = 1, width: float = 100.0, height: float = 100.0) -> Array:
    var rivers: Array = []

    for _i in range(count):
        var start: Vector2 = Vector2(rng.randf_range(0.0, width), rng.randf_range(0.0, height))
        start = MapUtils.ensure_within_bounds(start, width, height)
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
        end = MapUtils.ensure_within_bounds(end, width, height)
        var polyline: Array[Vector2] = _river_polyline(start, end, 5, width, height)
        _process_intersections(polyline, roads, width, height)
        rivers.append(polyline)

    return rivers

func _river_polyline(start: Vector2, end: Vector2, segments: int = 5, width: float = 100.0, height: float = 100.0) -> Array[Vector2]:
    var pts: Array[Vector2] = [start]
    for i in range(1, segments - 1):
        var t: float = float(i) / float(segments - 1)
        var mid: Vector2 = start.lerp(end, t)
        var offset: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
        var p: Vector2 = mid + offset
        p = MapUtils.ensure_within_bounds(p, width, height)
        pts.append(p)
    pts.append(end)
    return pts

func _crossing_allowed(
    cross: Vector2,
    crossing_type: String,
    river_dist: float,
    crossings: Array,
    nodes: Dictionary
) -> bool:
    var nearest_bridge := INF
    for info in crossings:
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

func _process_intersections(poly: Array[Vector2], roads: Dictionary, width: float, height: float) -> void:
    var nodes: Dictionary = roads["nodes"]
    var edges: Dictionary = roads["edges"]
    var next_node_id: int = roads.get("next_node_id", 1)
    var next_edge_id: int = roads.get("next_edge_id", 1)
    var crossings: Array = []

    for edge_id in edges.keys():
        var edge: Edge = edges[edge_id]
        var road_start: Vector2 = MapUtils.ensure_within_bounds(edge.polyline[0], width, height)
        var road_end: Vector2 = MapUtils.ensure_within_bounds(edge.polyline[1], width, height)
        for i in range(poly.size() - 1):
            var river_a: Vector2 = poly[i]
            var river_b: Vector2 = poly[i + 1]
            var intersection: Variant = Geometry2D.segment_intersects_segment(river_a, river_b, road_start, road_end)
            if intersection != null:
                var cross: Vector2 = MapUtils.ensure_within_bounds(intersection, width, height)
                if cross.distance_to(river_a) <= 0.3:
                    cross = river_a
                elif cross.distance_to(river_b) <= 0.3:
                    cross = river_b
                else:
                    poly.insert(i + 1, cross)

                var bridge_type: String = MapNodeModule.TYPE_BRIDGE if edge.road_class in ["road", "roman"] else MapNodeModule.TYPE_FORD
                var river_dist: float = MapUtils.distance_along_polyline(poly, i, cross)
                if edge.road_class != "roman" and not _crossing_allowed(cross, bridge_type, river_dist, crossings, nodes):
                    edges.erase(edge_id)
                    break

                var bridge_id: int = next_node_id
                next_node_id += 1
                var bridge_node: MapNode = MapNodeModule.new(bridge_id, bridge_type, cross, {})
                nodes[bridge_id] = bridge_node

                var start_id: int = edge.endpoints[0]
                var end_id: int = edge.endpoints[1]
                edges.erase(edge_id)
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [road_start, cross], [start_id, bridge_id], edge.road_class, edge.attrs)
                next_edge_id += 1
                edges[next_edge_id] = EdgeModule.new(next_edge_id, edge.type, [cross, road_end], [bridge_id, end_id], edge.road_class, edge.attrs)
                next_edge_id += 1
                crossings.append({"distance": river_dist, "type": bridge_type})
                break

    roads["next_node_id"] = next_node_id
    roads["next_edge_id"] = next_edge_id
