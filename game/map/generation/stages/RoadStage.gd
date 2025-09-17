extends RefCounted
class_name MapRoadStage

class _DisjointSet:
    var parent: Array[int]
    var ranks: Array[int]

    func _init(size: int) -> void:
        parent = []
        ranks = []
        for i in range(size):
            parent.append(i)
            ranks.append(0)

    func find(value: int) -> int:
        if parent[value] != value:
            parent[value] = find(parent[value])
        return parent[value]

    func join(a: int, b: int) -> void:
        var root_a := find(a)
        var root_b := find(b)
        if root_a == root_b:
            return
        if ranks[root_a] < ranks[root_b]:
            parent[root_a] = root_b
        elif ranks[root_a] > ranks[root_b]:
            parent[root_b] = root_a
        else:
            parent[root_b] = root_a
            ranks[root_a] += 1

static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var cities: Array[Dictionary] = state["cities"]
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var size: int = state["map_size"]
    var rng: RandomNumberGenerator = state["rng"]
    var river_lookup: PackedByteArray = state.get("river_lookup", PackedByteArray())

    if cities.size() < 2:
        return {
            "polylines": [],
            "connectivity": {
                "components": 1,
                "isolated_cities": [],
            },
        }

    var edges: Array[Dictionary] = []
    for i in range(cities.size()):
        for j in range(i + 1, cities.size()):
            var pos_a: Vector2 = cities[i]["position"]
            var pos_b: Vector2 = cities[j]["position"]
            var distance := pos_a.distance_to(pos_b)
            edges.append({
                "a": i,
                "b": j,
                "distance": distance,
            })

    edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["distance"] < b["distance"]
    )

    var dsu := _DisjointSet.new(cities.size())
    var road_polylines: Array[Dictionary] = []
    var used_pairs: Dictionary = {}

    for edge in edges:
        var a: int = edge["a"]
        var b: int = edge["b"]
        if dsu.find(a) == dsu.find(b):
            continue
        var road := _create_road_between(
            cities[a],
            cities[b],
            "primary",
            assignment,
            sea_mask,
            slope_map,
            river_lookup,
            size
        )
        road_polylines.append(road)
        used_pairs[_road_pair_key(a, b)] = true
        dsu.join(a, b)

    for edge in edges:
        if rng.randf() > params.road_aggressiveness:
            continue
        var a: int = edge["a"]
        var b: int = edge["b"]
        var key := _road_pair_key(a, b)
        if used_pairs.has(key):
            continue
        var road := _create_road_between(
            cities[a],
            cities[b],
            "secondary",
            assignment,
            sea_mask,
            slope_map,
            river_lookup,
            size
        )
        road_polylines.append(road)
        used_pairs[key] = true

    var connectivity := _build_road_connectivity(cities, road_polylines)

    return {
        "polylines": road_polylines,
        "connectivity": connectivity,
    }

static func _road_pair_key(a: int, b: int) -> String:
    return "%s-%s" % [min(a, b), max(a, b)]

static func _create_road_between(
    city_a: Dictionary,
    city_b: Dictionary,
    road_type: String,
    assignment: PackedInt32Array,
    sea_mask: PackedByteArray,
    slope_map: PackedFloat32Array,
    river_lookup: PackedByteArray,
    size: int
) -> Dictionary:
    var start: Vector2 = city_a["position"]
    var end: Vector2 = city_b["position"]
    var path := _build_road_path(start, end, sea_mask, slope_map, size)
    var traversed := _sample_kingdoms_along_path(path, assignment, size)
    var crosses_river := _path_crosses_river(path, size, river_lookup)
    return {
        "type": road_type,
        "points": path,
        "length": _polyline_length(path),
        "traversed_kingdoms": traversed,
        "crosses_border": traversed.size() > 1,
        "crosses_river": crosses_river,
    }

static func _build_road_path(
    start: Vector2,
    end: Vector2,
    sea_mask: PackedByteArray,
    slope_map: PackedFloat32Array,
    size: int
) -> PackedVector2Array:
    var path := PackedVector2Array()
    path.append(start)
    var mid := Vector2((start.x + end.x) * 0.5, (start.y + end.y) * 0.5)
    var alt_mid := Vector2(start.x, end.y)
    var alt_mid_two := Vector2(end.x, start.y)

    var best_midpoints: Array[Vector2] = []
    best_midpoints.append(mid)
    best_midpoints.append(alt_mid)
    best_midpoints.append(alt_mid_two)

    var best_score: float = INF
    var best_path := PackedVector2Array()
    for candidate_midpoint in best_midpoints:
        var candidate_path := PackedVector2Array()
        candidate_path.append(start)
        candidate_path.append(candidate_midpoint)
        candidate_path.append(end)
        var score: float = _evaluate_path(candidate_path, sea_mask, slope_map, size)
        if score < best_score:
            best_score = score
            best_path = candidate_path
    path = best_path

    return _simplify_path(path)

static func _evaluate_path(path: PackedVector2Array, sea_mask: PackedByteArray, slope_map: PackedFloat32Array, size: int) -> float:
    var penalty: float = 0.0
    for i in range(path.size() - 1):
        var segment_start: Vector2 = path[i]
        var segment_end: Vector2 = path[i + 1]
        var length: float = segment_start.distance_to(segment_end)
        var samples: int = max(1, int(length / 4.0))
        for sample in range(samples + 1):
            var t: float = float(sample) / float(samples)
            var position: Vector2 = segment_start.lerp(segment_end, t)
            var index: int = MapGenerationShared.index_from_position(position, size)
            var slope_value: float = slope_map[index]
            penalty += slope_value * 2.0
            if _is_water(position, sea_mask, size):
                penalty += 25.0
    return penalty

static func _simplify_path(path: PackedVector2Array) -> PackedVector2Array:
    var simplified := PackedVector2Array()
    if path.is_empty():
        return simplified
    simplified.append(path[0])
    for i in range(1, path.size() - 1):
        var prev: Vector2 = simplified[simplified.size() - 1]
        var current: Vector2 = path[i]
        if current.distance_squared_to(prev) < 1.0:
            continue
        simplified.append(current)
    simplified.append(path[path.size() - 1])
    return simplified

static func _is_water(position: Vector2, sea_mask: PackedByteArray, size: int) -> bool:
    var index: int = MapGenerationShared.index_from_position(position, size)
    return sea_mask[index] == 1

static func _sample_kingdoms_along_path(path: PackedVector2Array, assignment: PackedInt32Array, size: int) -> PackedInt32Array:
    var kingdoms: Array[int] = []
    for i in range(path.size() - 1):
        var segment_start: Vector2 = path[i]
        var segment_end: Vector2 = path[i + 1]
        var length: float = segment_start.distance_to(segment_end)
        var samples: int = max(1, int(length / 6.0))
        for sample in range(samples + 1):
            var t: float = float(sample) / float(samples)
            var position: Vector2 = segment_start.lerp(segment_end, t)
            var kingdom_id: int = assignment[MapGenerationShared.index_from_position(position, size)]
            if kingdom_id < 0:
                continue
            if kingdom_id not in kingdoms:
                kingdoms.append(kingdom_id)
    return PackedInt32Array(kingdoms)

static func _path_crosses_river(path: PackedVector2Array, size: int, river_lookup: PackedByteArray) -> bool:
    for i in range(path.size() - 1):
        var segment_start: Vector2 = path[i]
        var segment_end: Vector2 = path[i + 1]
        var length: float = segment_start.distance_to(segment_end)
        var samples: int = max(1, int(length / 4.0))
        for sample in range(samples + 1):
            var t: float = float(sample) / float(samples)
            var position: Vector2 = segment_start.lerp(segment_end, t)
            if _is_river(position, size, river_lookup):
                return true
    return false

static func _is_river(position: Vector2, size: int, river_lookup: PackedByteArray) -> bool:
    if river_lookup.is_empty():
        return false
    var px: int = int(clamp(int(round(position.x)), 0, size - 1))
    var py: int = int(clamp(int(round(position.y)), 0, size - 1))
    var index: int = py * size + px
    if index < 0 or index >= river_lookup.size():
        return false
    return river_lookup[index] == 1

static func _polyline_length(path: PackedVector2Array) -> float:
    var length: float = 0.0
    for i in range(path.size() - 1):
        length += path[i].distance_to(path[i + 1])
    return length

static func _build_road_connectivity(cities: Array[Dictionary], roads: Array[Dictionary]) -> Dictionary:
    var adjacency: Dictionary = {}
    for i in range(cities.size()):
        adjacency[i] = []
    for road in roads:
        var points: PackedVector2Array = road.get("points", PackedVector2Array())
        if points.is_empty():
            continue
        var start: Vector2 = points[0]
        var end: Vector2 = points[points.size() - 1]
        var start_city: int = _find_city_index(start, cities)
        var end_city: int = _find_city_index(end, cities)
        if start_city == -1 or end_city == -1:
            continue
        adjacency[start_city].append(end_city)
        adjacency[end_city].append(start_city)
    var visited: Dictionary = {}
    var components: int = 0
    for i in range(cities.size()):
        if visited.has(i):
            continue
        components += 1
        var stack: Array[int] = [i]
        while not stack.is_empty():
            var current: int = stack.pop_back()
            if visited.has(current):
                continue
            visited[current] = true
            for neighbor in adjacency[current]:
                if not visited.has(neighbor):
                    stack.append(neighbor)
    var isolated: Array[int] = []
    for i in range(cities.size()):
        if adjacency[i].is_empty():
            isolated.append(i)
    return {
        "components": components,
        "isolated_cities": isolated,
    }

static func _find_city_index(position: Vector2, cities: Array[Dictionary]) -> int:
    for i in range(cities.size()):
        var city_position: Vector2 = cities[i]["position"]
        if city_position.distance_to(position) < 1.5:
            return i
    return -1
