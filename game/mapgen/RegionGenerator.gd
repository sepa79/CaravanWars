extends RefCounted
class_name MapGenRegionGenerator

const RegionModule = preload("res://mapview/Region.gd")
const VoronoiModule = preload("res://mapgen/Voronoi.gd")

const EPS: float = 0.001

# Generates regions as Voronoi cells around city positions.
# Returns a dictionary mapping region id -> Region instance.
func generate_regions(
    cities: Array[Vector2],
    kingdom_count: int = 3,
    width: float = 150.0,
    height: float = 150.0,
    rivers: Array = []
) -> Dictionary:
    print("[RegionGenerator] generating regions for %s cities" % cities.size())
    var bounds := Rect2(Vector2.ZERO, Vector2(width, height))
    var voronoi: Array[PackedVector2Array] = VoronoiModule.cells(cities, bounds, rivers)
    print("[RegionGenerator] computed %s raw cells" % voronoi.size())
    var regions: Dictionary = {}
    for i in range(voronoi.size()):
        var poly: PackedVector2Array = voronoi[i]
        print("[RegionGenerator] cell %s has %s vertices before filtering" % [i, poly.size()])
        if poly.size() < 3:
            print("[RegionGenerator] cell %s discarded: less than 3 vertices" % i)
            continue
        poly = _sort_clockwise(poly)
        poly = _filter_points(poly)
        print("[RegionGenerator] cell %s has %s vertices after filtering" % [i, poly.size()])
        if poly.size() < 3:
            print("[RegionGenerator] cell %s discarded after filtering" % i)
            continue
        var arr: Array[Vector2] = []
        for p in poly:
            arr.append(p)
        print("[RegionGenerator] cell %s vertices: %s" % [i, arr])
        regions[i + 1] = RegionModule.new(i + 1, arr, "")
    print("[RegionGenerator] finalized %s regions" % regions.size())
    _assign_kingdoms(regions, kingdom_count)
    return regions

func _assign_kingdoms(regions: Dictionary, kingdom_count: int) -> void:
    var total: int = regions.size()
    var k: int = clamp(kingdom_count, 1, total)
    if k < kingdom_count:
        print("[RegionGenerator] requested %s kingdoms but only %s regions" % [kingdom_count, total])
    var adjacency: Dictionary = _build_adjacency(regions)
    var ids: Array = regions.keys()
    ids.sort()
    var queue: Array[int] = []
    for i in range(k):
        var idx: int = int(float(i) * ids.size() / float(k))
        var start_id: int = ids[idx]
        regions[start_id].kingdom_id = i + 1
        queue.append(start_id)
    var front: int = 0
    while front < queue.size():
        var current: int = queue[front]
        front += 1
        var kid: int = regions[current].kingdom_id
        for n in adjacency.get(current, []):
            if regions[n].kingdom_id == 0:
                regions[n].kingdom_id = kid
                queue.append(n)
    for region in regions.values():
        if region.kingdom_id == 0:
            region.kingdom_id = 1

func _build_adjacency(regions: Dictionary) -> Dictionary:
    var adjacency: Dictionary = {}
    var edge_map: Dictionary = {}
    for region in regions.values():
        var pts: Array[Vector2] = region.boundary_nodes
        for i in range(pts.size()):
            var a: Vector2 = pts[i]
            var b: Vector2 = pts[(i + 1) % pts.size()]
            var key: String = _edge_key(a, b)
            if not edge_map.has(key):
                edge_map[key] = []
            edge_map[key].append(region.id)
    for key in edge_map.keys():
        var ids: Array = edge_map[key]
        if ids.size() == 2:
            var a_id: int = ids[0]
            var b_id: int = ids[1]
            if not adjacency.has(a_id):
                adjacency[a_id] = []
            if not adjacency.has(b_id):
                adjacency[b_id] = []
            adjacency[a_id].append(b_id)
            adjacency[b_id].append(a_id)
    return adjacency

func _edge_key(a: Vector2, b: Vector2) -> String:
    var ax: int = int(round(a.x / EPS))
    var ay: int = int(round(a.y / EPS))
    var bx: int = int(round(b.x / EPS))
    var by: int = int(round(b.y / EPS))
    if ax > bx or (ax == bx and ay > by):
        var tx: int = ax
        var ty: int = ay
        ax = bx
        ay = by
        bx = tx
        by = ty
    return "%s_%s_%s_%s" % [ax, ay, bx, by]

# Removes duplicate and collinear points.
func _filter_points(points: PackedVector2Array) -> PackedVector2Array:
    var cleaned := PackedVector2Array()
    var n := points.size()
    if n == 0:
        return cleaned
    for i in range(n):
        var prev: Vector2 = points[(i - 1 + n) % n]
        var curr: Vector2 = points[i]
        var next: Vector2 = points[(i + 1) % n]
        if curr.distance_to(prev) <= EPS:
            continue
        if abs((curr - prev).cross(next - curr)) <= EPS:
            continue
        if cleaned.is_empty() or curr.distance_to(cleaned[cleaned.size() - 1]) > EPS:
            cleaned.append(curr)
    if cleaned.size() > 2 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= EPS:
        cleaned.remove_at(cleaned.size() - 1)
    return cleaned

# Orders polygon vertices clockwise around their centroid.
func _sort_clockwise(points: PackedVector2Array) -> PackedVector2Array:
    var center := Vector2.ZERO
    for p in points:
        center += p
    center /= points.size()
    var arr: Array = []
    for p in points:
        arr.append(p)
    arr.sort_custom(func(a, b):
        return atan2(a.y - center.y, a.x - center.x) > atan2(b.y - center.y, b.x - center.x)
    )
    var sorted := PackedVector2Array()
    for p in arr:
        sorted.append(p)
    return sorted

