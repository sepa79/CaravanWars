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
    var voronoi: Array = _voronoi_diagram(PackedVector2Array(cities), bounds)
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
        regions[i + 1] = RegionModule.new(i + 1, arr, "")
    print("[RegionGenerator] finalized %s regions" % regions.size())
    return regions

# Computes Voronoi cells by iteratively clipping the bounding box with
# perpendicular bisectors between sites.
func _voronoi_diagram(points: PackedVector2Array, rect: Rect2) -> Array[PackedVector2Array]:
    print("[RegionGenerator] _voronoi_diagram with %s points" % points.size())
    var bounds_poly := PackedVector2Array([
        rect.position,
        rect.position + Vector2(rect.size.x, 0),
        rect.position + rect.size,
        rect.position + Vector2(0, rect.size.y),
    ])
    var far: float = max(rect.size.x, rect.size.y) * 2.0
    var result: Array[PackedVector2Array] = []
    for i in range(points.size()):
        var cell: PackedVector2Array = bounds_poly
        var p := points[i]
        for j in range(points.size()):
            if i == j:
                continue
            var q := points[j]
            var mid := (p + q) * 0.5
            var dir := (q - p).normalized()
            var normal := Vector2(dir.y, -dir.x)
            if normal.dot(p - mid) < 0:
                normal = -normal
            var half_plane := PackedVector2Array([
                mid + dir * far + normal * far,
                mid - dir * far + normal * far,
                mid - dir * far - normal * far,
                mid + dir * far - normal * far,
            ])
            var clipped := Geometry2D.intersect_polygons(cell, half_plane)
            if clipped.size() == 0:
                print("[RegionGenerator] cell %s clipped out by point %s" % [i, j])
                cell = PackedVector2Array()
                break
            cell = clipped[0]
        result.append(cell)
    return result

# Sorts polygon vertices clockwise around their centroid.
func _sort_clockwise(points: PackedVector2Array) -> PackedVector2Array:
    var centroid := Vector2.ZERO
    for p in points:
        centroid += p
    centroid /= points.size()
    var arr: Array = []
    for p in points:
        arr.append(p)
    arr.sort_custom(func(a: Vector2, b: Vector2):
        return (a - centroid).angle() > (b - centroid).angle())
    var sorted := PackedVector2Array(arr)
    if not Geometry2D.is_polygon_clockwise(sorted):
        arr.reverse()
        sorted = PackedVector2Array(arr)
    return sorted

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

