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
    var sequences: Array[Dictionary] = _collect_river_sequences(a, b, rivers, tolerance)
    if sequences.is_empty():
        var fallback := PackedVector2Array()
        fallback.append(a)
        fallback.append(b)
        return fallback
    sequences.sort_custom(func(lhs: Dictionary, rhs: Dictionary) -> bool:
        return float(lhs.get("start_t", 0.0)) < float(rhs.get("start_t", 0.0))
    )
    var result := PackedVector2Array()
    result.append(a)
    for seq in sequences:
        var start_point: Vector2 = seq.get("start_closest", a)
        _append_point(result, start_point)
        var path: PackedVector2Array = seq.get("path", PackedVector2Array())
        for point in path:
            _append_point(result, point)
        var end_point: Vector2 = seq.get("end_closest", b)
        _append_point(result, end_point)
    _append_point(result, b)
    return result

static func _collect_river_sequences(
    a: Vector2,
    b: Vector2,
    rivers: Array,
    tolerance: float
) -> Array[Dictionary]:
    var sequences: Array[Dictionary] = []
    var edge_vec: Vector2 = b - a
    var length: float = edge_vec.length()
    if length <= EPS:
        return sequences
    var edge_dir: Vector2 = edge_vec / length
    for river_variant in rivers:
        var river_points: PackedVector2Array = _to_vector2_array(river_variant)
        if river_points.size() < 2:
            continue
        var flags: Array[bool] = []
        var closest_points: Array[Vector2] = []
        var t_values: Array[float] = []
        flags.resize(river_points.size())
        closest_points.resize(river_points.size())
        t_values.resize(river_points.size())
        for idx in range(river_points.size()):
            var rp: Vector2 = river_points[idx]
            var closest: Vector2 = Geometry2D.get_closest_point_to_segment(rp, a, b)
            var dist: float = rp.distance_to(closest)
            var along: float = edge_dir.dot(closest - a)
            if dist <= tolerance and along >= -tolerance and along <= length + tolerance:
                flags[idx] = true
                closest_points[idx] = closest
                t_values[idx] = clamp(along / length, 0.0, 1.0)
            else:
                flags[idx] = false
                closest_points[idx] = Vector2.ZERO
                t_values[idx] = 0.0
        var start_idx: int = -1
        for idx in range(river_points.size()):
            if flags[idx]:
                if start_idx == -1:
                    start_idx = idx
            elif start_idx != -1:
                var end_idx: int = idx - 1
                var seq: Dictionary = _build_sequence(
                    river_points,
                    start_idx,
                    end_idx,
                    closest_points,
                    t_values
                )
                if not seq.is_empty():
                    sequences.append(seq)
                start_idx = -1
        if start_idx != -1:
            var seq_end: int = river_points.size() - 1
            var seq_final: Dictionary = _build_sequence(
                river_points,
                start_idx,
                seq_end,
                closest_points,
                t_values
            )
            if not seq_final.is_empty():
                sequences.append(seq_final)
    return sequences

static func _build_sequence(
    river_points: PackedVector2Array,
    start_idx: int,
    end_idx: int,
    closest_points: Array[Vector2],
    t_values: Array[float]
) -> Dictionary:
    if end_idx - start_idx < 1:
        return {}
    var path := PackedVector2Array()
    for idx in range(start_idx, end_idx + 1):
        path.append(river_points[idx])
    var start_t: float = t_values[start_idx]
    var end_t: float = t_values[end_idx]
    var start_closest: Vector2 = closest_points[start_idx]
    var end_closest: Vector2 = closest_points[end_idx]
    if start_t > end_t:
        path = _reverse_points(path)
        var temp_t: float = start_t
        start_t = end_t
        end_t = temp_t
        var temp_pt: Vector2 = start_closest
        start_closest = end_closest
        end_closest = temp_pt
    return {
        "path": path,
        "start_t": start_t,
        "end_t": end_t,
        "start_closest": start_closest,
        "end_closest": end_closest,
    }

static func _append_point(points: PackedVector2Array, point: Vector2) -> void:
    if points.is_empty() or points[points.size() - 1].distance_to(point) > EPS:
        points.append(point)

static func _to_vector2_array(data: Variant) -> PackedVector2Array:
    if data is PackedVector2Array:
        return data
    var result := PackedVector2Array()
    if data is Array:
        for item in data:
            if item is Vector2:
                result.append(item)
    return result

static func _reverse_points(points: PackedVector2Array) -> PackedVector2Array:
    var reversed := PackedVector2Array()
    for idx in range(points.size() - 1, -1, -1):
        reversed.append(points[idx])
    return reversed
