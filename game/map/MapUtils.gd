extends Object
class_name MapUtils

## Utility functions for map generation to ensure points stay within map bounds.
static func clamp_to_bounds(p: Vector2, width: float, height: float) -> Vector2:
    return Vector2(clamp(p.x, 0.0, width), clamp(p.y, 0.0, height))

static func is_within_bounds(p: Vector2, width: float, height: float) -> bool:
    return p.x >= 0.0 and p.x <= width and p.y >= 0.0 and p.y <= height

## Clamps the point to bounds and warns if it was out of range.
static func ensure_within_bounds(p: Vector2, width: float, height: float) -> Vector2:
    if not is_within_bounds(p, width, height):
        push_warning("[MapUtils] clamping out-of-bounds point %s" % p)
        return clamp_to_bounds(p, width, height)
    return p

## Returns the distance along a polyline up to the given point on segment `seg_idx`.
static func distance_along_polyline(poly: Array[Vector2], seg_idx: int, point: Vector2) -> float:
    var dist := 0.0
    for i in range(seg_idx):
        dist += poly[i].distance_to(poly[i + 1])
    dist += poly[seg_idx].distance_to(point)
    return dist

## Clamps every node and edge polyline in a road network.
static func clamp_roads(roads: Dictionary, width: float, height: float) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    for n in nodes.values():
        n.pos2d = ensure_within_bounds(n.pos2d, width, height)
    var edges: Dictionary = roads.get("edges", {})
    for e in edges.values():
        for i in range(e.polyline.size()):
            e.polyline[i] = ensure_within_bounds(e.polyline[i], width, height)

## Clamps all river polylines to map bounds.
static func clamp_rivers(rivers: Array, width: float, height: float) -> void:
    for river in rivers:
        for i in range(river.size()):
            river[i] = ensure_within_bounds(river[i], width, height)

## Ensures all map entities lie inside bounds.
static func clamp_map_data(data: Dictionary) -> void:
    var width: float = data.get("width", 100.0)
    var height: float = data.get("height", 100.0)
    if data.has("cities"):
        var cities: Array = data["cities"]
        for i in range(cities.size()):
            cities[i] = ensure_within_bounds(cities[i], width, height)
    if data.has("roads"):
        clamp_roads(data["roads"], width, height)
    if data.has("rivers"):
        clamp_rivers(data["rivers"], width, height)
