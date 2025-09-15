extends RefCounted
class_name MapGenGenerator

## Parameter container for map generation.
class MapGenParams:
    var rng_seed: int
    var city_count: int
    var max_river_count: int
    var min_connections: int
    var max_connections: int
    var min_city_distance: float
    var max_city_distance: float
    var crossroad_detour_margin: float
    var width: float
    var height: float
    var kingdom_count: int
    var max_forts_per_kingdom: int
    var village_count: int
    var village_per_city: int

    func _init(
        p_rng_seed: int = 0,
        p_city_count: int = 6,
        p_max_river_count: int = 1,
        p_min_connections: int = 1,
        p_max_connections: int = 3,
        p_min_city_distance: float = 20.0,
        p_max_city_distance: float = 40.0,
        p_crossroad_detour_margin: float = 5.0,
        p_width: float = 150.0,
        p_height: float = 150.0,
        p_kingdom_count: int = 3,
        p_max_forts_per_kingdom: int = 1,
        p_village_count: int = 10,
        p_village_per_city: int = 2
    ) -> void:
        rng_seed = p_rng_seed if p_rng_seed != 0 else Time.get_ticks_msec()
        city_count = p_city_count
        max_river_count = p_max_river_count
        var max_possible: int = min(7, max(1, p_city_count - 1))
        min_connections = clamp(p_min_connections, 1, max_possible)
        max_connections = clamp(p_max_connections, min_connections, max_possible)
        min_city_distance = min(p_min_city_distance, p_max_city_distance)
        max_city_distance = max(p_min_city_distance, p_max_city_distance)
        crossroad_detour_margin = p_crossroad_detour_margin
        width = clamp(p_width, 20.0, 500.0)
        height = clamp(p_height, 20.0, 500.0)
        kingdom_count = max(1, p_kingdom_count)
        max_forts_per_kingdom = max(0, p_max_forts_per_kingdom)
        village_count = max(0, p_village_count)
        village_per_city = max(0, p_village_per_city)

var params: MapGenParams
var rng: RandomNumberGenerator

const CityPlacerModule = preload("res://mapgen/CityPlacer.gd")
const RoadNetworkModule = preload("res://mapview/RoadNetwork.gd")
const RiverGeneratorModule: Script = preload("res://mapgen/RiverGenerator.gd")
const RegionGeneratorModule: Script = preload("res://mapgen/RegionGenerator.gd")
const MapNodeModule = preload("res://mapview/MapNode.gd")
const NoiseUtilModule = preload("res://mapgen/NoiseUtil.gd")

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params
    rng = RandomNumberGenerator.new()
    rng.seed = params.rng_seed

func generate() -> Dictionary:
    var map_data: Dictionary = {
        "width": params.width,
        "height": params.height,
    }
    var width_i: int = int(params.width)
    var height_i: int = int(params.height)
    var noise_seed: int = rng.randi()
    var nutil := NoiseUtilModule.new()
    var fertility_field: Array = nutil.generate_field(
        nutil.create_simplex(noise_seed, 3),
        width_i,
        height_i,
        0.1
    )
    var roughness_field: Array = nutil.compute_roughness(fertility_field)
    map_data["fertility"] = fertility_field
    map_data["roughness"] = roughness_field
    var city_stage := CityPlacerModule.new(rng)
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
    var city_fallback_count: int = cities.size() - city_peak_count
    var capitals: Array[int] = []
    for i in city_info.get("capitals", []):
        var idx: int = int(i)
        if idx < cities.size():
            capitals.append(idx)
    map_data["cities"] = cities
    map_data["capitals"] = capitals
    print("[MapGenerator] cities: %s peaks, %s fallback" % [city_peak_count, city_fallback_count])

    var region_stage = RegionGeneratorModule.new()
    var regions: Dictionary = region_stage.generate_regions(cities, params.kingdom_count, params.width, params.height)
    map_data["regions"] = regions
    print("[MapGenerator] generated %s regions" % regions.size())

    var road_stage := RoadNetworkModule.new(rng)
    var roads := road_stage.build_roads(
        cities,
        params.min_connections,
        params.max_connections,
        params.crossroad_detour_margin,
        "roman"
    )
    var village_result: Dictionary = _generate_village_positions(
        city_stage,
        roads,
        cities,
        city_margin
    )
    var villages: Array[Vector2] = village_result.get("villages", [])
    map_data["villages"] = villages
    var village_logs: Array = village_result.get("logs", [])
    for entry in village_logs:
        if typeof(entry) == TYPE_STRING and String(entry) != "":
            print(entry)
    var fallback_logs: Array = village_result.get("fallback_logs", [])
    for entry in fallback_logs:
        if typeof(entry) == TYPE_STRING and String(entry) != "":
            print(entry)
    var summary_log: String = village_result.get("summary", "")
    if summary_log != "":
        print(summary_log)
    if villages.size() > 0:
        road_stage.insert_villages(roads, villages)
    var nodes: Dictionary = roads.get("nodes", {})
    for idx in map_data.get("capitals", []):
        var nid: int = idx + 1
        var node = nodes.get(nid)
        if node != null:
            node.attrs["is_capital"] = true
    road_stage.insert_border_forts(roads, regions, 10.0, params.max_forts_per_kingdom, params.width, params.height)
    map_data["roads"] = roads

    var river_stage = RiverGeneratorModule.new(rng)
    var rivers: Array = river_stage.generate_rivers(roads, params.max_river_count, params.width, params.height)
    map_data["rivers"] = rivers

    var grouped: Dictionary = {
        MapNodeModule.TYPE_CITY: [],
        MapNodeModule.TYPE_VILLAGE: [],
        MapNodeModule.TYPE_FORT: [],
        MapNodeModule.TYPE_BRIDGE: [],
        MapNodeModule.TYPE_FORD: [],
        MapNodeModule.TYPE_CROSSROAD: [],
    }
    for node in nodes.values():
        if grouped.has(node.type):
            grouped[node.type].append(node.pos2d)
    var labels: Dictionary = {
        MapNodeModule.TYPE_CITY: "cities",
        MapNodeModule.TYPE_VILLAGE: "villages",
        MapNodeModule.TYPE_FORT: "forts",
        MapNodeModule.TYPE_BRIDGE: "bridges",
        MapNodeModule.TYPE_FORD: "fords",
        MapNodeModule.TYPE_CROSSROAD: "crossroads",
    }
    for key in grouped.keys():
        var pts: PackedStringArray = []
        for p: Vector2 in grouped[key]:
            pts.append("(%0.1f,%0.1f)" % [p.x, p.y])
        if pts.size() > 0:
            var joined: String = ", ".join(pts)
            print("[MapGenerator] %s: %s" % [labels[key], joined])

    return map_data

func _generate_village_positions(
    city_stage: MapGenCityPlacer,
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
        result["summary"] = "[MapGenerator] villages: requested count is zero, skipping generation"
        return result
    if params.village_per_city <= 0:
        result["summary"] = "[MapGenerator] villages: per-city target is zero, skipping generation"
        return result
    if cities.is_empty():
        result["summary"] = "[MapGenerator] villages: no cities available for placement"
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
            logs.append("[MapGenerator] city %d villages: skipped (global limit reached)" % [city_idx])
            continue
        var quota: int = min(per_city_target, total_target - villages.size())
        if quota <= 0:
            logs.append("[MapGenerator] city %d villages: no quota remaining" % [city_idx])
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
        result["summary"] = "[MapGenerator] villages summary (%s)" % summary_detail
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
        result["log"] = "[MapGenerator] city %d villages: skipped (no space: clearance=%.1f, min_spacing=%.1f)" % [
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
    var log: String = "[MapGenerator] city %d villages: placed %d/%d" % [city_index, placed.size(), quota]
    if detail_text != "":
        log += " (%s)" % detail_text
    result["log"] = log
    return result

func _fallback_villages(
    city_stage: MapGenCityPlacer,
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
    var log: String = "[MapGenerator] village fallback: placed %d/%d" % [accepted.size(), count]
    if detail_text != "":
        log += " (%s)" % detail_text
    result["positions"] = accepted
    result["log"] = log
    return result

func _collect_road_segments(roads: Dictionary) -> Array[PackedVector2Array]:
    var segments: Array[PackedVector2Array] = []
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        var polyline: PackedVector2Array = edge.polyline
        if polyline.size() < 2:
            continue
        var pair := PackedVector2Array()
        pair.append(polyline[0])
        pair.append(polyline[polyline.size() - 1])
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

static func export_bundle(path: String, map_data: Dictionary, rng_seed: int, version: String, width: float, height: float, unit_scale: float = 1.0) -> void:
    var bundle: Dictionary = _bundle_from_map(map_data, rng_seed, version, width, height, unit_scale)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(bundle, "\t"))
        file.close()

static func _bundle_from_map(map_data: Dictionary, rng_seed: int, version: String, width: float, height: float, unit_scale: float) -> Dictionary:
    var bundle: Dictionary = {
        "meta": {
            "version": version,
            "seed": rng_seed,
            "map_size": int(max(width, height)),
            "unit_scale": unit_scale,
        },
        "fertility": map_data.get("fertility", []),
        "roughness": map_data.get("roughness", []),
        "nodes": [],
        "edges": [],
        "cities": [],
        "crossings": [],
        "forts": [],
        "kingdoms": [],
        "rivers": [],
        "climate_cells": [],
    }
    var roads: Dictionary = map_data.get("roads", {})
    var nodes: Dictionary = roads.get("nodes", {})
    var capital_by_kingdom: Dictionary = {}
    for node in nodes.values():
        bundle["nodes"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y})
        match node.type:
            MapNodeModule.TYPE_CITY:
                var kid: int = node.attrs.get("kingdom_id", 0)
                var is_cap: bool = node.attrs.get("is_capital", false)
                bundle["cities"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "kingdom_id": kid, "is_capital": is_cap})
                if is_cap:
                    capital_by_kingdom[kid] = node.id
            MapNodeModule.TYPE_FORT:
                bundle["forts"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "edge_id": node.attrs.get("edge_id", null), "crossing_id": node.attrs.get("crossing_id", null), "pair_id": node.attrs.get("pair_id", null)})
            MapNodeModule.TYPE_BRIDGE:
                bundle["crossings"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "type": "bridge", "river_id": node.attrs.get("river_id", null)})
            MapNodeModule.TYPE_FORD:
                bundle["crossings"].append({"id": node.id, "x": node.pos2d.x, "y": node.pos2d.y, "type": "ford", "river_id": node.attrs.get("river_id", null)})
            _:
                pass
    var edges: Dictionary = roads.get("edges", {})
    for edge in edges.values():
        var length: float = 0.0
        for i in range(edge.polyline.size() - 1):
            length += edge.polyline[i].distance_to(edge.polyline[i + 1])
        var edict: Dictionary = {
            "id": edge.id,
            "a": edge.endpoints[0],
            "b": edge.endpoints[1],
            "class": edge.road_class.capitalize(),
            "length": length,
        }
        if edge.attrs.has("crossing_id"):
            edict["crossing_id"] = edge.attrs["crossing_id"]
        bundle["edges"].append(edict)
    for river in map_data.get("rivers", []):
        var poly: Array = []
        for p in river:
            poly.append([p.x, p.y])
        bundle["rivers"].append({"id": bundle["rivers"].size() + 1, "polyline": poly})
    var regions: Dictionary = map_data.get("regions", {})
    var names: Dictionary = map_data.get("kingdom_names", {})
    for region in regions.values():
        var poly: Array = []
        for p in region.boundary_nodes:
            poly.append([p.x, p.y])
        var kname: String = String(names.get(region.kingdom_id, "Kingdom %d" % region.kingdom_id))
        var cap_id: int = capital_by_kingdom.get(region.kingdom_id, 0)
        bundle["kingdoms"].append({
            "id": region.id,
            "kingdom_id": region.kingdom_id,
            "name": kname,
            "capital_city_id": cap_id,
            "polygon": poly,
        })
    return bundle
