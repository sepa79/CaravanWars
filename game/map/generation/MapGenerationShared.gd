extends RefCounted
class_name MapGenerationShared

static func has_adjacent_sea(x: int, y: int, size: int, sea_mask: PackedByteArray) -> bool:
    for y_offset in range(-1, 2):
        for x_offset in range(-1, 2):
            if x_offset == 0 and y_offset == 0:
                continue
            var nx := x + x_offset
            var ny := y + y_offset
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            if sea_mask[ny * size + nx] == 1:
                return true
    return false

static func distance_to_border(position: Vector2, state: Dictionary, size: int) -> float:
    var borders: Array[Dictionary] = []
    if state.has("kingdoms"):
        var kingdoms_data: Variant = state["kingdoms"]
        if kingdoms_data is Dictionary:
            borders = kingdoms_data.get("borders", [])
    if borders.is_empty():
        return 9999.0
    var best := 9999.0
    for border in borders:
        var points: PackedVector2Array = border.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        var step: int = max(1, MapGenerationConstants.BORDER_SAMPLE_STEP)
        for i in range(0, points.size() - 1, step):
            var start: Vector2 = points[i]
            var end: Vector2 = points[min(i + 1, points.size() - 1)]
            var closest: Vector2 = Geometry2D.get_closest_point_to_segment(position, start, end)
            var distance: float = closest.distance_to(position)
            if distance < best:
                best = distance
    return best

static func index_from_position(position: Vector2, size: int) -> int:
    var x := int(clamp(int(round(position.x)), 0, size - 1))
    var y := int(clamp(int(round(position.y)), 0, size - 1))
    return y * size + x
