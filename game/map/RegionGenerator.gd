extends RefCounted
class_name RegionGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RegionModule = preload("res://map/Region.gd")

const EPS: float = 0.001

# Generates regions as Voronoi cells around city positions.
# Returns a dictionary mapping region id -> Region instance.
func generate_regions(cities: Array[Vector2]) -> Dictionary:
    var bounds := PackedVector2Array([
        Vector2(0, 0),
        Vector2(CityPlacerModule.WIDTH, 0),
        Vector2(CityPlacerModule.WIDTH, CityPlacerModule.HEIGHT),
        Vector2(0, CityPlacerModule.HEIGHT),
    ])
    var voronoi: Array = Geometry2D.voronoi_diagram(PackedVector2Array(cities), bounds)
    var regions: Dictionary = {}
    for i in range(voronoi.size()):
        var poly: PackedVector2Array = voronoi[i]
        if poly.size() < 3:
            continue
        poly = Geometry2D.sort_points_clockwise(poly)
        poly = _filter_points(poly)
        if poly.size() < 3:
            continue
        var arr: Array[Vector2] = []
        for p in poly:
            arr.append(p)
        regions[i + 1] = RegionModule.new(i + 1, arr, "")
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

