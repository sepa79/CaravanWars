extends RefCounted
class_name MapGenVoronoi

const EPS: float = 0.001
const RIVER_SNAP_TOLERANCE: float = 5.0
const INF: float = 1.0e12

static func cells(
    points: Array[Vector2],
    bounds: Rect2,
    rivers: Array = []
) -> Array[PackedVector2Array]:
    var result: Array[PackedVector2Array] = []
    if points.is_empty():
        return result
    var neighbors: Array[Dictionary] = _compute_neighbors(points)
    var base: PackedVector2Array = PackedVector2Array([
        bounds.position,
        bounds.position + Vector2(bounds.size.x, 0.0),
        bounds.position + bounds.size,
        bounds.position + Vector2(0.0, bounds.size.y),
    ])
    for i in range(points.size()):
        var cell: PackedVector2Array = base.duplicate()
        for j in neighbors[i].keys():
            cell = _clip_poly(cell, points[i], points[j])
            if cell.size() < 3:
                break
        if not rivers.is_empty() and cell.size() >= 2:
            cell = _snap_cell_to_rivers(cell, rivers, RIVER_SNAP_TOLERANCE)
        result.append(cell)
    return result

static func _compute_neighbors(points: Array[Vector2]) -> Array[Dictionary]:
    var neighbors: Array[Dictionary] = []
    neighbors.resize(points.size())
    for idx in range(points.size()):
        neighbors[idx] = {}
    var pts: PackedVector2Array = PackedVector2Array(points)
    var tri: PackedInt32Array = Geometry2D.triangulate_delaunay(pts)
    if tri.is_empty():
        for i in range(points.size()):
            for j in range(points.size()):
                if i != j:
                    neighbors[i][j] = true
        return neighbors
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
    return neighbors

static func _clip_poly(poly: PackedVector2Array, p: Vector2, q: Vector2) -> PackedVector2Array:
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

static func _snap_cell_to_rivers(
    cell: PackedVector2Array,
    rivers: Array,
    tolerance: float
) -> PackedVector2Array:
    var snapped := PackedVector2Array()
    var vertex_count: int = cell.size()
    if vertex_count == 0:
        return snapped
    for i in range(vertex_count):
        var a: Vector2 = cell[i]
        var b: Vector2 = cell[(i + 1) % vertex_count]
        var edge_points: PackedVector2Array = _edge_with_river(a, b, rivers, tolerance)
        if snapped.is_empty():
            for point in edge_points:
                snapped.append(point)
            continue
        if edge_points.size() > 0:
            var start_point: Vector2 = edge_points[0]
            if snapped[snapped.size() - 1].distance_to(start_point) > EPS:
                snapped[snapped.size() - 1] = start_point
            for j in range(1, edge_points.size()):
                var pt: Vector2 = edge_points[j]
                if snapped[snapped.size() - 1].distance_to(pt) > EPS:
                    snapped.append(pt)
    if snapped.size() > 1 and snapped[0].distance_to(snapped[snapped.size() - 1]) <= EPS:
        snapped.remove_at(snapped.size() - 1)
    return snapped

static func _edge_with_river(
    a: Vector2,
    b: Vector2,
    rivers: Array,
    tolerance: float
) -> PackedVector2Array:
    var best_path: PackedVector2Array = _find_best_river_path(a, b, rivers, tolerance)
    if best_path.size() < 2:
        var fallback := PackedVector2Array()
        fallback.append(a)
        fallback.append(b)
        return fallback
    if best_path[0].distance_to(a) > best_path[best_path.size() - 1].distance_to(a):
        best_path = _reverse_points(best_path)
    var result := PackedVector2Array()
    result.append(best_path[0])
    for i in range(1, best_path.size() - 1):
        var mid_point: Vector2 = best_path[i]
        if result[result.size() - 1].distance_to(mid_point) > EPS:
            result.append(mid_point)
    var last_point: Vector2 = best_path[best_path.size() - 1]
    if result[result.size() - 1].distance_to(last_point) > EPS:
        result.append(last_point)
    return result

static func _find_best_river_path(
    a: Vector2,
    b: Vector2,
    rivers: Array,
    tolerance: float
) -> PackedVector2Array:
    var best := PackedVector2Array()
    var best_score: float = INF
    for river_variant in rivers:
        var river_points: PackedVector2Array = _to_vector2_array(river_variant)
        if river_points.size() < 2:
            continue
        var candidate: PackedVector2Array = _extract_river_path(river_points, a, b, tolerance)
        if candidate.size() < 2:
            continue
        var score: float = candidate[0].distance_to(a) + candidate[candidate.size() - 1].distance_to(b)
        if score < best_score:
            best_score = score
            best = candidate
    return best

static func _to_vector2_array(data: Variant) -> PackedVector2Array:
    if data is PackedVector2Array:
        return data
    var result := PackedVector2Array()
    if data is Array:
        for item in data:
            if item is Vector2:
                result.append(item)
    return result

static func _extract_river_path(
    river_points: PackedVector2Array,
    a: Vector2,
    b: Vector2,
    tolerance: float
) -> PackedVector2Array:
    var point_count: int = river_points.size()
    if point_count < 2:
        return PackedVector2Array()
    var start_idx: int = -1
    var end_idx: int = -1
    var start_dist: float = INF
    var end_dist: float = INF
    for idx in range(point_count):
        var point: Vector2 = river_points[idx]
        var dist_start: float = point.distance_to(a)
        if dist_start < start_dist:
            start_dist = dist_start
            start_idx = idx
        var dist_end: float = point.distance_to(b)
        if dist_end < end_dist:
            end_dist = dist_end
            end_idx = idx
    if start_idx == -1 or end_idx == -1:
        return PackedVector2Array()
    if start_dist > tolerance or end_dist > tolerance:
        return PackedVector2Array()
    if start_idx == end_idx:
        return PackedVector2Array()
    var path := PackedVector2Array()
    var step: int = 1 if end_idx >= start_idx else -1
    var idx: int = start_idx
    while true:
        var rp: Vector2 = river_points[idx]
        path.append(rp)
        if idx == end_idx:
            break
        idx += step
    for rp in path:
        var closest: Vector2 = Geometry2D.get_closest_point_to_segment(rp, a, b)
        if rp.distance_to(closest) > tolerance:
            return PackedVector2Array()
    return path

static func _reverse_points(points: PackedVector2Array) -> PackedVector2Array:
    var reversed := PackedVector2Array()
    for idx in range(points.size() - 1, -1, -1):
        reversed.append(points[idx])
    return reversed
