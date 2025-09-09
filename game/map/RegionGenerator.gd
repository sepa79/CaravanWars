extends RefCounted
class_name RegionGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RegionModule = preload("res://map/Region.gd")

# Generates regions as Voronoi cells around city positions.
# Returns a dictionary mapping region id -> Region instance.
func generate_regions(cities: Array[Vector2]) -> Dictionary:
    var regions: Dictionary = {}
    for i in range(cities.size()):
        var polygon: Array[Vector2] = _voronoi_cell(cities, i)
        regions[i + 1] = RegionModule.new(i + 1, polygon, "")
    return regions

func _voronoi_cell(points: Array[Vector2], index: int) -> Array[Vector2]:
    var bounds: Array[Vector2] = [
        Vector2(0, 0),
        Vector2(CityPlacerModule.WIDTH, 0),
        Vector2(CityPlacerModule.WIDTH, CityPlacerModule.HEIGHT),
        Vector2(0, CityPlacerModule.HEIGHT),
    ]
    var cell: Array[Vector2] = bounds.duplicate()
    var p: Vector2 = points[index]
    for j in range(points.size()):
        if j == index:
            continue
        var q: Vector2 = points[j]
        cell = _clip_cell(cell, p, q)
    return cell

# Clips polygon 'poly' by the half-plane of perpendicular bisector between p and q.
func _clip_cell(poly: Array[Vector2], p: Vector2, q: Vector2) -> Array[Vector2]:
    if poly.is_empty():
        return []
    var result: Array[Vector2] = []
    var mid: Vector2 = (p + q) * 0.5
    var dir: Vector2 = (q - p).normalized()
    var normal: Vector2 = Vector2(dir.y, -dir.x)
    # ensure normal points toward p side
    if (p - mid).dot(normal) < 0:
        normal = -normal
    for i in range(poly.size()):
        var a: Vector2 = poly[i]
        var b: Vector2 = poly[(i + 1) % poly.size()]
        var da: float = (a - mid).dot(normal)
        var db: float = (b - mid).dot(normal)
        if da >= 0:
            result.append(a)
        if da * db < 0:
            var t: float = da / (da - db)
            var intersection: Vector2 = a + (b - a) * t
            result.append(intersection)
    return result
