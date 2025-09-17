extends RefCounted
class_name MapKingdomStage

static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var size: int = state["map_size"]
    var total: int = size * size
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var temperature: PackedFloat32Array = state["temperature_map"]
    var rainfall: PackedFloat32Array = state["rainfall_map"]
    var river_distance: PackedFloat32Array = state["rivers"]["distance_map"]
    var biome_map: Array[String] = state["biome_map"]
    var rng: RandomNumberGenerator = state["rng"]

    var sample_step: int = max(1, int(size / 96))
    var candidates: Array[Dictionary] = []
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index: int = y * size + x
            if sea_mask[index] == 1:
                continue
            if slope_map[index] > 0.85:
                continue
            var habitability: float = (1.0 - abs(temperature[index] - 0.6)) * 0.6 + rainfall[index] * 0.4
            habitability = clampf(habitability, 0.0, 1.5)
            var river_bonus: float = clampf(
                1.0 - min(river_distance[index] / float(MapGenerationConstants.RIVER_INFLUENCE_RADIUS * 1.8), 1.0),
                0.0,
                1.0
            )
            var score: float = habitability + river_bonus
            score += rng.randf() * 0.15
            candidates.append({
                "index": index,
                "score": score,
            })

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var capitals: Array[Dictionary] = []
    var min_distance: float = float(size) / max(1.0, float(params.kingdom_count) * 1.8)
    var fallback_distance: float = max(8.0, min_distance * 0.5)

    for candidate in candidates:
        if capitals.size() >= params.kingdom_count:
            break
        var index: int = candidate["index"]
        var cx: int = index % size
        var cy: int = int(index / size)
        var position: Vector2 = Vector2(cx, cy)
        var is_valid := true
        for capital in capitals:
            if position.distance_to(capital["position"]) < min_distance:
                is_valid = false
                break
        if not is_valid:
            continue
        capitals.append({
            "kingdom_id": capitals.size(),
            "index": index,
            "position": position,
            "score": candidate["score"],
            "biome": biome_map[index],
        })

    if capitals.size() < params.kingdom_count:
        for candidate in candidates:
            if capitals.size() >= params.kingdom_count:
                break
            var index: int = candidate["index"]
            var cx: int = index % size
            var cy: int = int(index / size)
            var position: Vector2 = Vector2(cx, cy)
            var too_close := false
            for capital in capitals:
                if position.distance_to(capital["position"]) < fallback_distance:
                    too_close = true
                    break
            if too_close:
                continue
            capitals.append({
                "kingdom_id": capitals.size(),
                "index": index,
                "position": position,
                "score": candidate["score"],
                "biome": biome_map[index],
            })

    if capitals.is_empty():
        var default_index: int = int(size * size / 2 + size / 2)
        capitals.append({
            "kingdom_id": 0,
            "index": default_index,
            "position": Vector2(float(size) / 2.0, float(size) / 2.0),
            "score": 0.0,
            "biome": "grassland",
        })

    var assignment := PackedInt32Array()
    assignment.resize(total)
    for i in range(assignment.size()):
        assignment[i] = -1

    for y in range(size):
        for x in range(size):
            var index: int = y * size + x
            if sea_mask[index] == 1:
                continue
            var best_cost: float = INF
            var best_kingdom: int = -1
            for capital in capitals:
                var capital_index: int = capital["index"]
                var cx: int = capital_index % size
                var cy: int = int(capital_index / size)
                var dx: float = float(x - cx)
                var dy: float = float(y - cy)
                var distance: float = sqrt(dx * dx + dy * dy)
                var slope_penalty: float = slope_map[index] * 35.0
                var biome_penalty: float = 0.0
                if biome_map[index] != capital["biome"]:
                    biome_penalty = 10.0
                var river_penalty: float = 0.0
                if state["rivers"].has("distance_map"):
                    var dist_to_river: float = river_distance[index]
                    if dist_to_river < 2.5:
                        river_penalty = 8.0
                var cost: float = distance + slope_penalty + biome_penalty + river_penalty
                if cost < best_cost:
                    best_cost = cost
                    best_kingdom = capital["kingdom_id"]
            assignment[index] = best_kingdom

    var polygons: Array[Dictionary] = []
    var sample_mod: int = max(1, int(size / 128))
    for capital in capitals:
        var kingdom_id: int = capital["kingdom_id"]
        var points: PackedVector2Array = PackedVector2Array()
        for y in range(0, size, sample_mod):
            for x in range(0, size, sample_mod):
                var index: int = y * size + x
                if assignment[index] == kingdom_id:
                    points.append(Vector2(x, y))
        if points.size() < 3:
            var fallback_polygon: PackedVector2Array = PackedVector2Array()
            fallback_polygon.append(capital["position"] + Vector2(-10, -10))
            fallback_polygon.append(capital["position"] + Vector2(10, -10))
            fallback_polygon.append(capital["position"] + Vector2(10, 10))
            fallback_polygon.append(capital["position"] + Vector2(-10, 10))
            polygons.append({
                "kingdom_id": kingdom_id,
                "capital_candidate": capital["position"],
                "polygon": fallback_polygon,
            })
            continue
        var hull: PackedVector2Array = Geometry2D.convex_hull(points)
        polygons.append({
            "kingdom_id": kingdom_id,
            "capital_candidate": capital["position"],
            "polygon": hull,
        })

    var border_lines: Array[Dictionary] = _build_border_lines(assignment, size)

    state["kingdom_assignment"] = assignment
    state["capitals"] = capitals

    return {
        "polygons": polygons,
        "borders": border_lines,
        "capitals": capitals,
    }

static func _build_border_lines(assignment: PackedInt32Array, size: int) -> Array[Dictionary]:
    var borders: Array[Dictionary] = []
    for y in range(size - 1):
        for x in range(size - 1):
            var index: int = y * size + x
            var current: int = assignment[index]
            if current < 0:
                continue
            var right: int = assignment[index + 1]
            if right >= 0 and right != current and current < right:
                var line: PackedVector2Array = PackedVector2Array()
                line.append(Vector2(x + 1, y))
                line.append(Vector2(x + 1, y + 1))
                borders.append({
                    "between": PackedInt32Array([current, right]),
                    "points": line,
                })
            var down: int = assignment[index + size]
            if down >= 0 and down != current and current < down:
                var line_down: PackedVector2Array = PackedVector2Array()
                line_down.append(Vector2(x, y + 1))
                line_down.append(Vector2(x + 1, y + 1))
                borders.append({
                    "between": PackedInt32Array([current, down]),
                    "points": line_down,
                })
    return borders
