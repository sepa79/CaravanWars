extends RefCounted
class_name MapFortStage

static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var roads: Dictionary = state["roads"]
    var road_polylines: Array[Dictionary] = roads.get("polylines", [])
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var heightmap: PackedFloat32Array = state["terrain"]["heightmap"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var size: int = state["map_size"]
    var rng: RandomNumberGenerator = state["rng"]
    var city_counts: Dictionary = state["city_counts"]

    var candidates: Array[Dictionary] = []
    for road_index in range(road_polylines.size()):
        var road := road_polylines[road_index]
        var points: PackedVector2Array = road.get("points", PackedVector2Array())
        if points.size() < 2:
            continue
        for i in range(points.size() - 1):
            var mid := points[i].lerp(points[i + 1], 0.5)
            var index := MapGenerationShared.index_from_position(mid, size)
            var kingdom_id := assignment[index]
            if kingdom_id < 0:
                continue
            var elevation := heightmap[index]
            var slope_value := slope_map[index]
            if slope_value > 0.9:
                continue
            var border_distance := MapGenerationShared.distance_to_border(mid, state, size)
            var score := (1.0 - slope_value) + clamp(1.0 - border_distance / 12.0, 0.0, 1.0)
            if road.get("crosses_river", false):
                score += 0.4
            score += rng.randf() * 0.1
            candidates.append({
                "position": mid,
                "kingdom_id": kingdom_id,
                "score": score,
                "elevation": elevation,
                "road_index": road_index,
                "border_distance": border_distance,
            })

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var forts: Array[Dictionary] = []
    var per_kingdom_cap: Dictionary = {}
    var base_cap := params.fort_global_cap
    for kingdom_id in range(params.kingdom_count):
        var kingdom_city_count := city_counts.get(kingdom_id, 0)
        var dynamic_cap := 0
        if kingdom_city_count > 0:
            dynamic_cap = max(1, kingdom_city_count / 4)
        var allowed := dynamic_cap
        if kingdom_city_count > 0 and allowed < 1:
            allowed = 1
        if base_cap > 0:
            var base_limit := max(1, base_cap / max(1, params.kingdom_count))
            if kingdom_city_count > 0 and allowed < 1:
                allowed = 1
            if allowed > 0:
                allowed = min(allowed, base_limit)
            else:
                allowed = min(1, base_limit)
        per_kingdom_cap[kingdom_id] = allowed
    var face_off_distance_sq := MapGenerationConstants.FACE_OFF_DISTANCE * MapGenerationConstants.FACE_OFF_DISTANCE

    for candidate in candidates:
        var kingdom_id: int = candidate["kingdom_id"]
        if per_kingdom_cap.get(kingdom_id, 0) <= 0:
            continue
        var position: Vector2 = candidate["position"]
        var valid := true
        for fort in forts:
            if position.distance_squared_to(fort["position"]) < float(params.fort_spacing * params.fort_spacing):
                valid = false
                break
        if not valid:
            continue
        for fort in forts:
            if fort["kingdom_id"] == kingdom_id:
                continue
            if position.distance_squared_to(fort["position"]) < face_off_distance_sq:
                if candidate["border_distance"] < 4.0 and fort.get("border_distance", 0.0) < 4.0:
                    valid = false
                    break
        if not valid:
            continue
        var fort_type := "frontier"
        if candidate["border_distance"] < 4.0:
            fort_type = "border"
        elif candidate["score"] > 1.6:
            fort_type = "road_guard"
        forts.append({
            "kingdom_id": kingdom_id,
            "position": position,
            "priority_score": candidate["score"],
            "type": fort_type,
            "elevation": candidate["elevation"],
            "nearby_road": candidate["road_index"],
            "border_distance": candidate["border_distance"],
        })
        per_kingdom_cap[kingdom_id] = per_kingdom_cap[kingdom_id] - 1
        if base_cap > 0 and forts.size() >= base_cap:
            break

    return {
        "points": forts,
    }
