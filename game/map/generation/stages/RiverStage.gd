extends RefCounted
class_name MapRiverStage

static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var size: int = state["map_size"]
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]

    var source_candidates: Array[int] = []
    var sample_step: int = max(1, int(size / 128))
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index: int = y * size + x
            if sea_mask[index] == 1:
                continue
            var altitude: float = heightmap[index]
            if altitude < params.river_source_alt_thresh:
                continue
            var slope_value: float = slope_map[index]
            if slope_value < 0.05:
                continue
            source_candidates.append(index)

    source_candidates.sort_custom(func(a: int, b: int) -> bool:
        return heightmap[a] > heightmap[b]
    )

    var polylines: Array[Dictionary] = []
    var visited: Dictionary = {}
    var desired_count: int = clampi(int(params.map_size / 256) * 2, 3, 48)

    for candidate_index in source_candidates:
        if polylines.size() >= desired_count:
            break
        if visited.has(candidate_index):
            continue
        var river_path: PackedVector2Array = _trace_river(candidate_index, size, heightmap, sea_mask, params)
        if river_path.size() < 4:
            continue
        var discharge: float = float(river_path.size())
        var width: float = max(1.0, sqrt(discharge) * 0.15)
        var entry: Dictionary = {
            "points": river_path,
            "width": width,
            "discharge": discharge,
        }
        polylines.append(entry)
        for point in river_path:
            var px: int = int(point.x)
            var py: int = int(point.y)
            var visit_index: int = py * size + px
            visited[visit_index] = true

    var distance_map: PackedFloat32Array = _calculate_river_distance(polylines, size)
    var watersheds: Array[Dictionary] = _build_river_watersheds(polylines)
    var river_lookup: PackedByteArray = PackedByteArray()
    river_lookup.resize(size * size)
    for river in polylines:
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        for point in points:
            var rounded_x: int = int(round(point.x))
            var rounded_y: int = int(round(point.y))
            var px: int = clampi(rounded_x, 0, size - 1)
            var py: int = clampi(rounded_y, 0, size - 1)
            var index: int = py * size + px
            if index < 0 or index >= river_lookup.size():
                continue
            river_lookup[index] = 1
    state["river_lookup"] = river_lookup

    return {
        "polylines": polylines,
        "distance_map": distance_map,
        "watersheds": watersheds,
        "lookup": river_lookup,
    }

static func _trace_river(
    start_index: int,
    size: int,
    heightmap: PackedFloat32Array,
    sea_mask: PackedByteArray,
    params: MapGenerationParams
) -> PackedVector2Array:
    var path: PackedVector2Array = PackedVector2Array()
    var current: int = start_index
    var guard: int = 0
    var visited: Dictionary = {}
    while guard < size * 4:
        guard += 1
        var cx: int = current % size
        var cy: int = int(current / size)
        path.append(Vector2(cx, cy))
        if sea_mask[current] == 1 or heightmap[current] <= params.sea_level:
            break
        visited[current] = true
        var next_index: int = _find_downhill_neighbor(current, size, heightmap)
        if next_index == current:
            break
        if visited.has(next_index):
            break
        current = next_index
    return path

static func _find_downhill_neighbor(index: int, size: int, heightmap: PackedFloat32Array) -> int:
    var cx: int = index % size
    var cy: int = int(index / size)
    var best_index: int = index
    var best_height: float = heightmap[index]
    for y_offset in range(-1, 2):
        for x_offset in range(-1, 2):
            if x_offset == 0 and y_offset == 0:
                continue
            var nx: int = cx + x_offset
            var ny: int = cy + y_offset
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            var neighbor_index: int = ny * size + nx
            var neighbor_height: float = heightmap[neighbor_index]
            if neighbor_height < best_height:
                best_height = neighbor_height
                best_index = neighbor_index
    return best_index

static func _calculate_river_distance(polylines: Array[Dictionary], size: int) -> PackedFloat32Array:
    var distance: PackedFloat32Array = PackedFloat32Array()
    distance.resize(size * size)
    for i in range(distance.size()):
        distance[i] = 1e6

    var queue: Array[int] = []
    for river in polylines:
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        for point in points:
            var px: int = int(point.x)
            var py: int = int(point.y)
            var index: int = py * size + px
            if index < 0 or index >= distance.size():
                continue
            if distance[index] > 0.0:
                distance[index] = 0.0
                queue.append(index)

    var head: int = 0
    var neighbor_offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while head < queue.size():
        var current: int = queue[head]
        head += 1
        var cx: int = current % size
        var cy: int = int(current / size)
        for offset in neighbor_offsets:
            var nx: int = cx + offset.x
            var ny: int = cy + offset.y
            if nx < 0 or nx >= size or ny < 0 or ny >= size:
                continue
            var neighbor_index: int = ny * size + nx
            var new_distance: float = distance[current] + 1.0
            if new_distance < distance[neighbor_index]:
                distance[neighbor_index] = new_distance
                queue.append(neighbor_index)
    return distance

static func _build_river_watersheds(polylines: Array[Dictionary]) -> Array[Dictionary]:
    var watersheds: Array[Dictionary] = []
    for i in range(polylines.size()):
        var river: Dictionary = polylines[i]
        var points: PackedVector2Array = river.get("points", PackedVector2Array())
        if points.size() < 3:
            continue
        var hull: PackedVector2Array = Geometry2D.convex_hull(points)
        if hull.is_empty():
            continue
        watersheds.append({
            "river_index": i,
            "polygon": hull,
        })
    return watersheds
