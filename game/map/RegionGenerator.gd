extends RefCounted
class_name RegionGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RegionModule = preload("res://map/Region.gd")

const EPS: float = 0.001

# Generates regions as Voronoi cells around city positions.
# Returns a dictionary mapping region id -> Region instance.
func generate_regions(cities: Array[Vector2]) -> Dictionary:
    print("[RegionGenerator] generating regions for %s cities" % cities.size())
    var bounds := Rect2(Vector2.ZERO, Vector2(CityPlacerModule.WIDTH, CityPlacerModule.HEIGHT))
    var voronoi: Array = _voronoi_diagram(cities, bounds)
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
    return regions

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

# Computes Voronoi cells for each point, clipped to the map bounds.
func _voronoi_diagram(points: Array[Vector2], bounds: Rect2) -> Array:
    var pts := PackedVector2Array(points)
    var tri := Geometry2D.triangulate_delaunay(pts)
    var neighbors: Array = []
    neighbors.resize(points.size())
    for i in range(points.size()):
        neighbors[i] = {}
    if tri.is_empty():
        for i in range(points.size()):
            for j in range(points.size()):
                if i != j:
                    neighbors[i][j] = true
    else:
        for t in range(0, tri.size(), 3):
            var a: int = tri[t]
            var b: int = tri[t + 1]
            var c: int = tri[t + 2]
            neighbors[a][b] = true
            neighbors[a][c] = true
            neighbors[b][a] = true
            neighbors[b][c] = true
            neighbors[c][a] = true
            neighbors[c][b] = true
    var base := PackedVector2Array([
        bounds.position,
        bounds.position + Vector2(bounds.size.x, 0),
        bounds.position + bounds.size,
        bounds.position + Vector2(0, bounds.size.y),
    ])
    var cells: Array = []
    for i in range(points.size()):
        var poly: PackedVector2Array = base.duplicate()
        for j in neighbors[i].keys():
            poly = _clip_poly(poly, points[i], points[j])
            if poly.size() < 3:
                break
        cells.append(poly)
    return cells

# Clips polygon by the half-plane defined by the bisector between p and q.
func _clip_poly(poly: PackedVector2Array, p: Vector2, q: Vector2) -> PackedVector2Array:
    if poly.is_empty():
        return poly
    var result := PackedVector2Array()
    var mid: Vector2 = (p + q) * 0.5
    var normal: Vector2 = q - p
    for i in range(poly.size()):
        var a: Vector2 = poly[i]
        var b: Vector2 = poly[(i + 1) % poly.size()]
        var da: float = (a - mid).dot(normal)
        var db: float = (b - mid).dot(normal)
        if da <= EPS:
            result.append(a)
        if da * db < -EPS * EPS:
            var t: float = da / (da - db)
            result.append(a + (b - a) * t)
    return result

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

