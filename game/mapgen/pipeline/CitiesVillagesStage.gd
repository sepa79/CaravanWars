extends RefCounted

const CityPlacerModule: Script = preload("res://mapgen/CityPlacer.gd")
const RegionGeneratorModule: Script = preload("res://mapgen/RegionGenerator.gd")

var params: Variant
var rng: RandomNumberGenerator

func run(context: RefCounted) -> void:
    params = context.params
    rng = context.get_stage_rng("cities_villages")
    var city_stage: RefCounted = CityPlacerModule.new(rng)
    var fertility_field: Array = context.get_raster_layer("fertility", [])
    var city_margin: float = 30.0
    var city_info: Dictionary = city_stage.select_city_sites(
        fertility_field,
        params.city_count,
        params.min_city_distance,
        city_margin
    )
    var cities: Array[Vector2] = city_info.get("cities", [])
    var city_peak_count: int = cities.size()
    if cities.size() < params.city_count:
        var extra_cities: Array[Vector2] = city_stage.place_cities(
            params.city_count - cities.size(),
            params.min_city_distance,
            params.max_city_distance,
            params.width,
            params.height,
            city_margin
        )
        cities.append_array(extra_cities)
    var capitals: Array[int] = []
    for i in city_info.get("capitals", []):
        var idx: int = int(i)
        if idx < cities.size():
            capitals.append(idx)
    print("[CitiesVillagesStage] cities: %s peaks, %s fallback" % [city_peak_count, cities.size() - city_peak_count])
    context.set_vector_layer("cities", cities)
    context.set_data("capitals", capitals)
    context.set_data("city_margin", city_margin)

    var region_stage = RegionGeneratorModule.new()
    var regions: Dictionary = region_stage.generate_regions(cities, params.kingdom_count, params.width, params.height)
    context.set_vector_layer("regions", regions)
    print("[CitiesVillagesStage] generated %s regions" % regions.size())

    var placeholder_roads: Dictionary = {
        "nodes": {},
        "edges": {},
        "next_node_id": 1,
        "next_edge_id": 1,
    }
    var village_result: Dictionary = _generate_village_positions(
        city_stage,
        placeholder_roads,
        cities,
        city_margin
    )
    var villages: Array[Vector2] = village_result.get("villages", [])
    context.set_vector_layer("villages", villages)
    var summary: String = village_result.get("summary", "")
    if summary != "":
        print(summary)
    for entry in village_result.get("logs", []):
        if typeof(entry) == TYPE_STRING and String(entry) != "":
            print(entry)
    for entry in village_result.get("fallback_logs", []):
        if typeof(entry) == TYPE_STRING and String(entry) != "":
            print(entry)

func _generate_village_positions(
    city_stage: RefCounted,
    roads: Dictionary,
    cities: Array[Vector2],
    border_margin: float
) -> Dictionary:
    var result: Dictionary = {
        "villages": [] as Array[Vector2],
        "logs": [] as Array[String],
        "fallback_logs": [] as Array[String],
        "summary": "",
    }
    if params.village_count <= 0:
        result["summary"] = "[CitiesVillagesStage] villages: requested count is zero, skipping generation"
        return result
    if params.village_per_city <= 0:
        result["summary"] = "[CitiesVillagesStage] villages: per-city target is zero, skipping generation"
        return result
    if cities.is_empty():
        result["summary"] = "[CitiesVillagesStage] villages: no cities available for placement"
        return result

    var total_target: int = params.village_count
    var per_city_target: int = params.village_per_city
    var road_segments: Array[PackedVector2Array] = _collect_road_segments(roads)
    var villages: Array[Vector2] = []
    var logs: Array[String] = []
    var min_spacing: float = params.min_city_distance / 3.0
    var per_city_shortfall: int = 0

    for city_idx in range(cities.size()):
        if villages.size() >= total_target:
            logs.append("[CitiesVillagesStage] city %d villages: skipped (global limit reached)" % [city_idx])
            continue
        var quota: int = min(per_city_target, total_target - villages.size())
        if quota <= 0:
            logs.append("[CitiesVillagesStage] city %d villages: no quota remaining" % [city_idx])
            continue
        var city_result: Dictionary = _sample_villages_for_city(
            city_idx,
            cities,
            villages,
            road_segments,
            quota,
            border_margin,
            min_spacing
        )
        var placed: Array[Vector2] = city_result.get("placed", [])
        for pos in placed:
            villages.append(pos)
        logs.append(city_result.get("log", ""))
        per_city_shortfall += city_result.get("shortfall", 0)

    var fallback_logs: Array[String] = []
    var fallback_added: int = 0
    if villages.size() < total_target:
        var needed: int = total_target - villages.size()
        var fallback_result: Dictionary = _fallback_villages(
            city_stage,
            cities,
            villages,
            border_margin,
            min_spacing,
            needed
        )
        var fallback_positions: Array[Vector2] = fallback_result.get("positions", [])
        for pos in fallback_positions:
            if villages.size() >= total_target:
                break
            villages.append(pos)
            fallback_added += 1
        var fallback_log: String = fallback_result.get("log", "")
        if fallback_log != "":
            fallback_logs.append(fallback_log)

    var remaining_shortfall: int = max(0, total_target - villages.size())
    var summary_parts: Array[String] = []
    summary_parts.append("placed=%d/%d" % [villages.size(), total_target])
    summary_parts.append("per_city=%d" % per_city_target)
    if per_city_shortfall > 0:
        summary_parts.append("per_city_shortfall=%d" % per_city_shortfall)
    if fallback_added > 0:
        summary_parts.append("fallback=%d" % fallback_added)
    if remaining_shortfall > 0:
        summary_parts.append("missing=%d" % remaining_shortfall)
    var summary_detail: String = _format_detail_list(summary_parts)
    result["villages"] = villages
    result["logs"] = logs
    result["fallback_logs"] = fallback_logs
    if summary_detail != "":
        result["summary"] = "[CitiesVillagesStage] villages summary (%s)" % summary_detail
    return result

func _sample_villages_for_city(
    city_index: int,
    cities: Array[Vector2],
    existing_villages: Array[Vector2],
    road_segments: Array[PackedVector2Array],
    quota: int,
    border_margin: float,
    min_spacing: float
) -> Dictionary:
    var result: Dictionary = {
        "placed": [] as Array[Vector2],
        "log": "",
        "shortfall": quota,
    }
    var city_pos: Vector2 = cities[city_index]
    var clearance: float = _city_border_clearance(city_pos, border_margin)
    var max_radius: float = min(params.min_city_distance, clearance)
    if max_radius <= min_spacing:
        result["log"] = "[CitiesVillagesStage] city %d villages: skipped (no space: clearance=%.1f, min_spacing=%.1f)" % [
            city_index,
            max_radius,
            min_spacing,
        ]
        return result

    var attempts: int = 0
    var valid_candidates: Array[Vector2] = []
    var border_rejects: int = 0
    var parent_rejects: int = 0
    var other_city_rejects: int = 0
    var existing_village_rejects: int = 0
    var max_attempts: int = max(quota * 24, 48)
    var target_pool: int = max(quota * 3, quota)
    while attempts < max_attempts and valid_candidates.size() < target_pool:
        var radius: float = rng.randf_range(min_spacing, max_radius)
        var angle: float = rng.randf() * TAU
        var candidate: Vector2 = city_pos + Vector2(cos(angle), sin(angle)) * radius
        attempts += 1
        if candidate.x < border_margin or candidate.x > params.width - border_margin or candidate.y < border_margin or candidate.y > params.height - border_margin:
            border_rejects += 1
            continue
        if candidate.distance_to(city_pos) < min_spacing:
            parent_rejects += 1
            continue
        var near_other_city: bool = false
        for idx in range(cities.size()):
            if idx == city_index:
                continue
            if cities[idx].distance_to(candidate) < min_spacing:
                near_other_city = true
                other_city_rejects += 1
                break
        if near_other_city:
            continue
        var near_existing_village: bool = false
        for village in existing_villages:
            if village.distance_to(candidate) < min_spacing:
                near_existing_village = true
                existing_village_rejects += 1
                break
        if near_existing_village:
            continue
        valid_candidates.append(candidate)

    var has_roads: bool = road_segments.size() > 0
    var scored: Array = []
    for candidate in valid_candidates:
        var score: float = 1.0
        if has_roads:
            var best_dist: float = INF
            for segment in road_segments:
                var a: Vector2 = segment[0]
                var b: Vector2 = segment[1]
                var projected: Vector2 = Geometry2D.get_closest_point_to_segment(candidate, a, b)
                var dist: float = projected.distance_to(candidate)
                if dist < best_dist:
                    best_dist = dist
            if best_dist == INF:
                score = 0.0
            else:
                var denom: float = max(best_dist * best_dist, 0.01)
                score = 1.0 / denom
        scored.append({"pos": candidate, "score": score})
    scored.sort_custom(func(a, b): return a["score"] > b["score"])

    var placed: Array[Vector2] = []
    var local_overlap_rejects: int = 0
    var post_existing_rejects: int = 0
    for entry in scored:
        if placed.size() >= quota:
            break
        var pos: Vector2 = entry["pos"]
        var blocked: bool = false
        for other in placed:
            if other.distance_to(pos) < min_spacing:
                blocked = true
                local_overlap_rejects += 1
                break
        if blocked:
            continue
        for village in existing_villages:
            if village.distance_to(pos) < min_spacing:
                blocked = true
                post_existing_rejects += 1
                break
        if blocked:
            continue
        placed.append(pos)

    var shortfall: int = max(0, quota - placed.size())
    result["placed"] = placed
    result["shortfall"] = shortfall

    var detail_parts: Array[String] = []
    detail_parts.append("attempts=%d" % attempts)
    detail_parts.append("candidates=%d" % valid_candidates.size())
    if border_rejects > 0:
        detail_parts.append("border=%d" % border_rejects)
    if parent_rejects > 0:
        detail_parts.append("parent=%d" % parent_rejects)
    if other_city_rejects > 0:
        detail_parts.append("near_cities=%d" % other_city_rejects)
    if existing_village_rejects > 0:
        detail_parts.append("near_villages=%d" % existing_village_rejects)
    if local_overlap_rejects > 0:
        detail_parts.append("local_overlap=%d" % local_overlap_rejects)
    if post_existing_rejects > 0:
        detail_parts.append("late_village_rejects=%d" % post_existing_rejects)
    if max_radius < params.min_city_distance:
        detail_parts.append("radius_cap=%.1f" % max_radius)
    detail_parts.append("scoring=%s" % ("road" if has_roads else "uniform"))
    if shortfall > 0:
        detail_parts.append("shortfall=%d" % shortfall)
    var detail_text: String = _format_detail_list(detail_parts)
    var log: String = "[CitiesVillagesStage] city %d villages: placed %d/%d" % [city_index, placed.size(), quota]
    if detail_text != "":
        log += " (%s)" % detail_text
    result["log"] = log
    return result

func _fallback_villages(
    city_stage: RefCounted,
    cities: Array[Vector2],
    existing_villages: Array[Vector2],
    border_margin: float,
    min_spacing: float,
    count: int
) -> Dictionary:
    var result: Dictionary = {
        "positions": [] as Array[Vector2],
        "log": "",
    }
    if count <= 0:
        return result

    var fallback_min: float = max(min_spacing, 1.0)
    var fallback_max: float = max(fallback_min, params.min_city_distance)
    var raw: Array[Vector2] = city_stage.place_cities(
        count,
        fallback_min,
        fallback_max,
        params.width,
        params.height,
        border_margin
    )
    var accepted: Array[Vector2] = []
    var near_city_rejects: int = 0
    var near_village_rejects: int = 0
    for pos in raw:
        if accepted.size() >= count:
            break
        var blocked: bool = false
        for city in cities:
            if city.distance_to(pos) < min_spacing:
                blocked = true
                near_city_rejects += 1
                break
        if blocked:
            continue
        for village in existing_villages:
            if village.distance_to(pos) < min_spacing:
                blocked = true
                near_village_rejects += 1
                break
        if blocked:
            continue
        for village in accepted:
            if village.distance_to(pos) < min_spacing:
                blocked = true
                near_village_rejects += 1
                break
        if blocked:
            continue
        accepted.append(pos)
    result["positions"] = accepted
    var detail_parts: Array[String] = []
    detail_parts.append("requested=%d" % count)
    detail_parts.append("generated=%d" % raw.size())
    if near_city_rejects > 0:
        detail_parts.append("near_cities=%d" % near_city_rejects)
    if near_village_rejects > 0:
        detail_parts.append("near_villages=%d" % near_village_rejects)
    if accepted.size() < count:
        detail_parts.append("shortfall=%d" % (count - accepted.size()))
    var detail_text: String = _format_detail_list(detail_parts)
    var log: String = "[CitiesVillagesStage] village fallback: placed %d/%d" % [accepted.size(), count]
    if detail_text != "":
        log += " (%s)" % detail_text
    result["log"] = log
    return result

func _collect_road_segments(roads: Dictionary) -> Array[PackedVector2Array]:
    var segments: Array[PackedVector2Array] = []
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        var polyline: Array[Vector2] = edge.polyline
        if polyline.size() < 2:
            continue
        for idx in range(polyline.size() - 1):
            var pair := PackedVector2Array()
            pair.append(polyline[idx])
            pair.append(polyline[idx + 1])
            segments.append(pair)
    return segments

func _city_border_clearance(city_pos: Vector2, border_margin: float) -> float:
    var clearance_x: float = min(city_pos.x - border_margin, params.width - border_margin - city_pos.x)
    var clearance_y: float = min(city_pos.y - border_margin, params.height - border_margin - city_pos.y)
    return max(0.0, min(clearance_x, clearance_y))

func _format_detail_list(parts: Array[String]) -> String:
    if parts.is_empty():
        return ""
    var text: String = parts[0]
    for i in range(1, parts.size()):
        text += ", " + parts[i]
    return text
