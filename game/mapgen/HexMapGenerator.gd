extends RefCounted
class_name HexMapGenerator

const PHASE_TERRAIN := StringName("terrain")
const PHASE_RIVERS := StringName("rivers")
const PHASE_BIOMES := StringName("biomes")
const PHASE_BORDERS := StringName("borders")
const PHASE_SETTLEMENTS := StringName("settlements")
const PHASE_ROADS := StringName("roads")
const PHASE_FORTS := StringName("forts")

const PHASE_SEQUENCE: Array[StringName] = [
    PHASE_TERRAIN,
    PHASE_RIVERS,
    PHASE_BIOMES,
    PHASE_BORDERS,
    PHASE_SETTLEMENTS,
    PHASE_ROADS,
    PHASE_FORTS,
]

const RIVER_DIRECTION_BITS: Array[int] = [
    1 << 0,
    1 << 1,
    1 << 2,
    1 << 3,
    1 << 4,
    1 << 5,
]

const RIVER_MASK_BIT_COUNT := 6

var config: HexMapConfig
var rng := RandomNumberGenerator.new()
var grid: HexGrid
var map_data: HexMapData
var terrain_settings
var phase_handlers: Dictionary = {}

var terrain_state: Dictionary = {}
var rivers_state: Dictionary = {}
var biomes_state: Dictionary = {}
var borders_state: Dictionary = {}
var settlements_state: Dictionary = {}
var roads_state: Dictionary = {}
var forts_state: Dictionary = {}
var _river_mask_lookup: Dictionary = {}

func _init(p_config: HexMapConfig = HexMapConfig.new()) -> void:
    config = p_config.duplicate_config()
    rng.seed = config.map_seed
    grid = HexGrid.new(config.map_radius)
    map_data = HexMapData.new(config)
    map_data.attach_grid(grid)
    terrain_settings = config.terrain_settings.duplicate_settings()
    _river_mask_lookup = _create_river_mask_lookup()
    _register_default_handlers()
    _reset_phase_state()

func generate() -> HexMapData:
    rng.seed = config.map_seed
    map_data.clear_stage_results()
    _reset_phase_state()
    print("[HexMapGenerator] Starting map generation with seed %d (radius=%d, kingdoms=%d)" % [
        config.map_seed,
        config.map_radius,
        config.kingdom_count,
    ])
    for phase in PHASE_SEQUENCE:
        var handler: Callable = phase_handlers.get(phase, Callable())
        var phase_name := String(phase)
        if handler.is_valid():
            print("[HexMapGenerator] -> %s phase" % phase_name)
            handler.call()
            print("[HexMapGenerator] <- %s phase complete" % phase_name)
        else:
            print("[HexMapGenerator] Skipping %s phase (no handler registered)" % phase_name)
    print("[HexMapGenerator] Map generation complete")
    return map_data

func set_phase_handler(phase: StringName, handler: Callable) -> void:
    if not PHASE_SEQUENCE.has(phase):
        push_warning("[HexMapGenerator] Unknown phase '%s'" % String(phase))
        return
    phase_handlers[phase] = handler

func get_phase_handler(phase: StringName) -> Callable:
    return phase_handlers.get(phase, Callable())

func get_rng() -> RandomNumberGenerator:
    return rng

func get_grid() -> HexGrid:
    return grid

func get_map_data() -> HexMapData:
    return map_data

func _register_default_handlers() -> void:
    phase_handlers = {
        PHASE_TERRAIN: Callable(self, "_default_terrain_phase"),
        PHASE_RIVERS: Callable(self, "_default_rivers_phase"),
        PHASE_BIOMES: Callable(self, "_default_biomes_phase"),
        PHASE_BORDERS: Callable(self, "_default_borders_phase"),
        PHASE_SETTLEMENTS: Callable(self, "_default_settlements_phase"),
        PHASE_ROADS: Callable(self, "_default_roads_phase"),
        PHASE_FORTS: Callable(self, "_default_forts_phase"),
    }

func _reset_phase_state() -> void:
    terrain_state = {}
    rivers_state = {}
    biomes_state = {}
    borders_state = {}
    settlements_state = {}
    roads_state = {}
    forts_state = {}

func _default_terrain_phase() -> void:
    terrain_state = _generate_terrain()
    map_data.set_stage_result(PHASE_TERRAIN, terrain_state)

func _default_rivers_phase() -> void:
    rivers_state = _generate_rivers()
    map_data.set_stage_result(PHASE_RIVERS, rivers_state)
    if not terrain_state.is_empty():
        map_data.set_stage_result(PHASE_TERRAIN, terrain_state)

func _default_biomes_phase() -> void:
    biomes_state = {
        "biomes": {},
    }
    map_data.set_stage_result(PHASE_BIOMES, biomes_state)

func _default_borders_phase() -> void:
    borders_state = {
        "edges": [],
    }
    map_data.set_stage_result(PHASE_BORDERS, borders_state)

func _default_settlements_phase() -> void:
    settlements_state = {
        "cities": [],
        "villages": [],
    }
    map_data.set_stage_result(PHASE_SETTLEMENTS, settlements_state)

func _default_roads_phase() -> void:
    roads_state = {
        "routes": [],
    }
    map_data.set_stage_result(PHASE_ROADS, roads_state)

func _default_forts_phase() -> void:
    forts_state = {
        "sites": [],
    }
    map_data.set_stage_result(PHASE_FORTS, forts_state)

func _generate_terrain() -> Dictionary:
    var result: Dictionary = {
        "hexes": {},
        "regions": {},
        "coastline": {},
        "validation": {},
    }
    var coords: Array[HexCoord] = _collect_all_coords()
    if coords.is_empty():
        return result

    var hex_entries: Dictionary = {}
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        hex_entries[key] = _build_hex_entry(coord, "plains")

    _assign_edge_regions(hex_entries)
    _scatter_random_features(hex_entries)

    var region_counts: Dictionary = _compute_region_counts(hex_entries)
    var land_count: int = 0
    for region_type in region_counts.keys():
        var count_value := int(region_counts[region_type])
        if String(region_type) != "sea":
            land_count += count_value

    result["hexes"] = hex_entries
    result["regions"] = {
        "counts": region_counts,
        "targets": {},
        "seeds": {},
        "land_count": land_count,
        "sea_count": int(region_counts.get("sea", 0)),
    }
    result["coastline"] = {}
    result["validation"] = {}
    return result

func _generate_rivers() -> Dictionary:
    var result: Dictionary = {
        "networks": [],
        "hexes": {},
        "validation": {
            "errors": [],
            "warnings": [],
        },
    }
    if typeof(terrain_state) != TYPE_DICTIONARY:
        return result
    var hex_entries: Dictionary = terrain_state.get("hexes", {})
    if hex_entries.is_empty():
        return result
    var cap: int = max(0, config.rivers_cap)
    if cap == 0:
        return result
    var sources: Array[Vector2i] = _find_mountain_sources(hex_entries)
    if sources.is_empty():
        return result
    if sources.size() > cap:
        sources = sources.slice(0, cap)
    var river_hex_data: Dictionary = {}
    var networks: Array[Dictionary] = []
    for source_key in sources:
        var network: Dictionary = _trace_river_from(source_key, hex_entries, river_hex_data)
        networks.append(network)
    _compute_river_classes(river_hex_data)
    _finalize_river_hex_entries(river_hex_data, hex_entries)
    _refresh_region_counts(hex_entries)
    result["networks"] = networks
    result["hexes"] = river_hex_data
    result["validation"] = _validate_rivers(networks, river_hex_data)
    return result

func _find_mountain_sources(hex_entries: Dictionary) -> Array[Vector2i]:
    var peaks: Array[Dictionary] = []
    for key in hex_entries.keys():
        var entry: Dictionary = hex_entries.get(key, {})
        if String(entry.get("region", "")) != "mountains":
            continue
        var coord := HexCoord.from_vector2i(key)
        var elev := float(entry.get("elev", 0.0))
        var neighbors: Array[HexCoord] = grid.get_neighbor_coords(coord)
        var is_peak := true
        var has_lower_neighbor := false
        for neighbor in neighbors:
            var neighbor_entry: Dictionary = hex_entries.get(neighbor.to_vector2i(), {})
            if neighbor_entry.is_empty():
                continue
            var neighbor_elev := float(neighbor_entry.get("elev", elev))
            if neighbor_elev > elev + 0.0005:
                is_peak = false
                break
            if neighbor_elev < elev - 0.0005:
                has_lower_neighbor = true
        if not is_peak or not has_lower_neighbor:
            continue
        peaks.append({
            "coord": key,
            "elev": elev,
        })
    peaks.sort_custom(Callable(self, "_compare_peak_entry"))
    var ordered: Array[Vector2i] = []
    for peak in peaks:
        ordered.append(peak.get("coord", Vector2i.ZERO))
    return ordered

func _compare_peak_entry(a: Dictionary, b: Dictionary) -> bool:
    var elev_a := float(a.get("elev", 0.0))
    var elev_b := float(b.get("elev", 0.0))
    if abs(elev_a - elev_b) < 0.0001:
        var coord_a: Vector2i = a.get("coord", Vector2i.ZERO)
        var coord_b: Vector2i = b.get("coord", Vector2i.ZERO)
        if coord_a.x == coord_b.x:
            return coord_a.y < coord_b.y
        return coord_a.x < coord_b.x
    return elev_a > elev_b

func _trace_river_from(source_key: Vector2i, hex_entries: Dictionary, river_hex_data: Dictionary) -> Dictionary:
    var source_entry: Dictionary = hex_entries.get(source_key, {})
    var path: Array[Vector2i] = []
    var visited: Dictionary = {}
    var current_key := source_key
    var sink_type := ""
    var sink_coord := source_key
    if source_entry.is_empty():
        sink_type = "missing"
        return {
            "source": source_key,
            "path": [source_key],
            "sink": {
                "type": sink_type,
                "coord": sink_coord,
            },
        }
    while true:
        path.append(current_key)
        visited[current_key] = true
        var terrain_entry: Dictionary = hex_entries.get(current_key, {})
        if path.size() == 1:
            _mark_river_source(river_hex_data, current_key)
        _carve_terrain_for_river(hex_entries, current_key)
        var step: Dictionary = _choose_downhill_step(current_key, hex_entries, visited)
        if step.is_empty():
            sink_type = _sink_type_for_hex(current_key, terrain_entry)
            sink_coord = current_key
            break
        var next_key: Vector2i = step.get("coord", current_key)
        var next_entry: Dictionary = hex_entries.get(next_key, {})
        var already_traced: bool = river_hex_data.has(next_key)
        _register_flow_link(river_hex_data, current_key, next_key)
        if visited.has(next_key):
            sink_type = "loop"
            sink_coord = next_key
            path.append(next_key)
            break
        if next_entry.is_empty():
            sink_type = "void"
            sink_coord = next_key
            path.append(next_key)
            break
        if next_entry.get("is_sea", false):
            sink_type = "sea"
            sink_coord = next_key
            path.append(next_key)
            _ensure_river_hex_entry(river_hex_data, next_key)
            break
        if next_entry.get("is_water", false) and String(next_entry.get("region", "")) == "lake":
            _ensure_river_hex_entry(river_hex_data, next_key)
        elif already_traced:
            sink_type = "confluence"
            sink_coord = next_key
            path.append(next_key)
            break
        current_key = next_key
    if sink_type == "":
        sink_type = _sink_type_for_hex(sink_coord, hex_entries.get(sink_coord, {}))
    if sink_type != "confluence" and sink_type != "missing":
        var sink_entry := _ensure_river_hex_entry(river_hex_data, sink_coord)
        sink_entry["sink_type"] = sink_type
        river_hex_data[sink_coord] = sink_entry
    return {
        "source": source_key,
        "path": path,
        "sink": {
            "type": sink_type,
            "coord": sink_coord,
        },
    }

func _mark_river_source(river_hex_data: Dictionary, key: Vector2i) -> void:
    var entry := _ensure_river_hex_entry(river_hex_data, key)
    entry["is_source"] = true
    river_hex_data[key] = entry

func _carve_terrain_for_river(hex_entries: Dictionary, key: Vector2i) -> void:
    var entry: Dictionary = hex_entries.get(key, {})
    if entry.is_empty():
        return
    if entry.get("is_water", false):
        return
    var region := String(entry.get("region", "plains"))
    if region != "plains":
        return
    var coord := HexCoord.from_vector2i(key)
    var target_elev := _elevation_for("valley", coord)
    var current_elev := float(entry.get("elev", target_elev))
    entry["region"] = "valley"
    entry["is_water"] = false
    entry["is_sea"] = false
    entry["coord"] = key
    entry["elev"] = min(current_elev, target_elev)
    entry = _populate_visual_metadata(entry, coord)
    hex_entries[key] = entry

func _choose_downhill_step(current_key: Vector2i, hex_entries: Dictionary, visited: Dictionary) -> Dictionary:
    var coord := HexCoord.from_vector2i(current_key)
    var current_entry: Dictionary = hex_entries.get(current_key, {})
    var current_elev := float(current_entry.get("elev", 0.0))
    var downhill: Array[Dictionary] = []
    var fallback: Array[Dictionary] = []
    for neighbor in grid.get_neighbor_coords(coord):
        var neighbor_key := neighbor.to_vector2i()
        var neighbor_entry: Dictionary = hex_entries.get(neighbor_key, {})
        if neighbor_entry.is_empty():
            continue
        if visited.has(neighbor_key):
            continue
        var neighbor_elev := float(neighbor_entry.get("elev", current_elev))
        var bias := _terrain_preference_bias(String(neighbor_entry.get("region", "plains")), bool(neighbor_entry.get("is_water", false)))
        var candidate := {
            "coord": neighbor_key,
            "elev": neighbor_elev,
            "score": neighbor_elev + bias,
        }
        if neighbor_elev <= current_elev + 0.0005:
            downhill.append(candidate)
        else:
            fallback.append(candidate)
    if downhill.size() > 0:
        downhill.sort_custom(Callable(self, "_compare_candidate_score"))
        return downhill[0]
    fallback.sort_custom(Callable(self, "_compare_candidate_score"))
    if fallback.size() > 0:
        return fallback[0]
    return {}

func _terrain_preference_bias(region: String, is_water: bool) -> float:
    var bias: Dictionary = terrain_settings.river_preference_bias
    if is_water:
        var water_bias: Variant = bias.get("water", {})
        if typeof(water_bias) == TYPE_DICTIONARY:
            var typed: Dictionary = water_bias
            return float(typed.get(region, 0.0))
        return 0.0
    var terrain_bias: Variant = bias.get("terrain", {})
    if typeof(terrain_bias) == TYPE_DICTIONARY:
        var typed_terrain: Dictionary = terrain_bias
        return float(typed_terrain.get(region, 0.0))
    return 0.0

func _compare_candidate_score(a: Dictionary, b: Dictionary) -> bool:
    var score_a := float(a.get("score", 0.0))
    var score_b := float(b.get("score", 0.0))
    if abs(score_a - score_b) < 0.0001:
        var elev_a := float(a.get("elev", 0.0))
        var elev_b := float(b.get("elev", 0.0))
        return elev_a < elev_b
    return score_a < score_b

func _register_flow_link(river_hex_data: Dictionary, from_key: Vector2i, to_key: Vector2i) -> void:
    var from_entry := _ensure_river_hex_entry(river_hex_data, from_key)
    var to_entry := _ensure_river_hex_entry(river_hex_data, to_key)
    var from_coord := HexCoord.from_vector2i(from_key)
    var to_coord := HexCoord.from_vector2i(to_key)
    var direction_index := _direction_index(from_coord, to_coord)
    if direction_index == -1:
        return
    var opposite_index := (direction_index + 3) % 6
    from_entry["river_mask"] = int(from_entry.get("river_mask", 0)) | RIVER_DIRECTION_BITS[direction_index]
    to_entry["river_mask"] = int(to_entry.get("river_mask", 0)) | RIVER_DIRECTION_BITS[opposite_index]
    if not from_entry.has("downstream") or from_entry.get("downstream") == null:
        from_entry["downstream"] = to_key
    var upstreams_variant: Variant = to_entry.get("upstreams", [])
    var upstreams: Array = []
    if upstreams_variant is Array:
        upstreams = upstreams_variant
    if not upstreams.has(from_key):
        upstreams.append(from_key)
    to_entry["upstreams"] = upstreams
    river_hex_data[from_key] = from_entry
    river_hex_data[to_key] = to_entry

func _ensure_river_hex_entry(river_hex_data: Dictionary, key: Vector2i) -> Dictionary:
    var entry: Dictionary = river_hex_data.get(key, {})
    if entry.is_empty():
        entry = {
            "coord": key,
            "river_mask": 0,
            "river_class": 0,
            "is_mouth": false,
            "upstreams": [],
            "downstream": null,
            "sink_type": "",
            "is_source": false,
            "river_variant": "",
            "river_rotation": 0,
        }
        river_hex_data[key] = entry
    return entry

func _direction_index(from_coord: HexCoord, to_coord: HexCoord) -> int:
    var diff := Vector2i(to_coord.q - from_coord.q, to_coord.r - from_coord.r)
    for i in range(HexCoord.DIRECTIONS.size()):
        if HexCoord.DIRECTIONS[i] == diff:
            return i
    return -1

func _sink_type_for_hex(key: Vector2i, entry: Dictionary) -> String:
    if entry.get("is_sea", false):
        return "sea"
    if entry.get("is_water", false) and String(entry.get("region", "")) == "lake":
        return "lake"
    if _is_edge_hex(key):
        return "edge"
    return "stalled"

func _is_edge_hex(key: Vector2i) -> bool:
    var coord := HexCoord.from_vector2i(key)
    var q := coord.q
    var r := coord.r
    var s := -q - r
    return abs(q) == grid.radius or abs(r) == grid.radius or abs(s) == grid.radius

func _compute_river_classes(river_hex_data: Dictionary) -> void:
    var cache: Dictionary = {}
    for key in river_hex_data.keys():
        _resolve_river_class(key, river_hex_data, cache, 0)
    for key in cache.keys():
        var entry: Dictionary = river_hex_data.get(key, {})
        entry["river_class"] = cache.get(key, 1)
        river_hex_data[key] = entry

func _resolve_river_class(key: Vector2i, river_hex_data: Dictionary, cache: Dictionary, depth: int) -> int:
    if cache.has(key):
        return int(cache[key])
    if depth > 128:
        cache[key] = 1
        return 1
    var entry: Dictionary = river_hex_data.get(key, {})
    var upstreams_variant: Variant = entry.get("upstreams", [])
    var upstreams: Array = []
    if upstreams_variant is Array:
        upstreams = upstreams_variant
    if upstreams.is_empty():
        cache[key] = 1
        return 1
    var values: Array[int] = []
    for upstream_key in upstreams:
        values.append(_resolve_river_class(upstream_key, river_hex_data, cache, depth + 1))
    var max_value := 0
    var max_count := 0
    for value in values:
        if value > max_value:
            max_value = value
            max_count = 1
        elif value == max_value:
            max_count += 1
    var class_value := max_value
    if max_count >= 2:
        class_value += 1
    class_value = clampi(class_value, 1, 3)
    cache[key] = class_value
    return class_value

func _finalize_river_hex_entries(river_hex_data: Dictionary, hex_entries: Dictionary) -> void:
    for key in river_hex_data.keys():
        var entry: Dictionary = river_hex_data.get(key, {})
        var downstream: Variant = entry.get("downstream")
        var is_mouth := false
        if downstream == null:
            var sink_type := String(entry.get("sink_type", ""))
            if sink_type == "sea" or sink_type == "lake" or sink_type == "edge":
                is_mouth = true
        else:
            var downstream_entry: Dictionary = hex_entries.get(downstream, {})
            if downstream_entry.get("is_water", false):
                is_mouth = true
        entry["is_mouth"] = is_mouth
        var river_mask := int(entry.get("river_mask", 0))
        var variant_info := _resolve_river_variant(river_mask, is_mouth)
        entry["river_variant"] = variant_info.get("variant", "")
        entry["river_rotation"] = variant_info.get("rotation", 0)
        river_hex_data[key] = entry
        var terrain_entry: Dictionary = hex_entries.get(key, {})
        if terrain_entry.is_empty():
            continue
        terrain_entry["river_mask"] = river_mask
        terrain_entry["river_class"] = int(entry.get("river_class", 0))
        terrain_entry["is_mouth"] = bool(entry.get("is_mouth", false))
        terrain_entry["river_variant"] = entry.get("river_variant", "")
        terrain_entry["river_rotation"] = entry.get("river_rotation", 0)
        terrain_entry = _apply_river_layer_rules(terrain_entry)
        hex_entries[key] = terrain_entry

func _refresh_region_counts(hex_entries: Dictionary) -> void:
    var region_info: Dictionary = terrain_state.get("regions", {})
    if typeof(region_info) != TYPE_DICTIONARY:
        return
    var counts := _compute_region_counts(hex_entries)
    var land_count := 0
    for region_type in counts.keys():
        if String(region_type) != "sea":
            land_count += int(counts[region_type])
    region_info["counts"] = counts
    region_info["land_count"] = land_count
    region_info["sea_count"] = int(counts.get("sea", 0))
    terrain_state["regions"] = region_info

func _validate_rivers(networks: Array[Dictionary], river_hex_data: Dictionary) -> Dictionary:
    var errors: Array[String] = []
    var warnings: Array[String] = []
    for network in networks:
        var sink: Dictionary = network.get("sink", {})
        var sink_type := String(sink.get("type", ""))
        if sink_type == "" or sink_type == "stalled" or sink_type == "void" or sink_type == "loop" or sink_type == "missing":
            var source: Vector2i = network.get("source", Vector2i.ZERO)
            var coords := "%d,%d" % [source.x, source.y]
            var message := "River from %s does not reach a valid sink (type=%s)." % [coords, sink_type]
            if not errors.has(message):
                errors.append(message)
    for key in river_hex_data.keys():
        var entry: Dictionary = river_hex_data.get(key, {})
        var upstreams_variant: Variant = entry.get("upstreams", [])
        var upstreams: Array = []
        if upstreams_variant is Array:
            upstreams = upstreams_variant
        if upstreams.is_empty():
            continue
        if not entry.has("downstream") or entry.get("downstream") == null:
            var sink_type := String(entry.get("sink_type", ""))
            if sink_type != "sea" and sink_type != "lake" and sink_type != "edge":
                var coords := "%d,%d" % [key.x, key.y]
                var message := "River hex %s terminates without a sink." % coords
                if not errors.has(message):
                    errors.append(message)
    return {
        "errors": errors,
        "warnings": warnings,
    }

func _collect_all_coords() -> Array[HexCoord]:
    var coords: Array[HexCoord] = []
    var radius: int = grid.radius
    for q in range(-radius, radius + 1):
        var r1: int = max(-radius, -q - radius)
        var r2: int = min(radius, -q + radius)
        for r in range(r1, r2 + 1):
            coords.append(HexCoord.new(q, r))
    return coords

func _assign_edge_regions(hex_entries: Dictionary) -> void:
    var settings: Dictionary = config.get_all_edge_settings()
    for key in hex_entries.keys():
        var coord := HexCoord.from_vector2i(key)
        var region_type := _region_for_coord(coord, settings)
        _apply_region_to_entry(hex_entries, key, region_type, coord)

func _region_for_coord(coord: HexCoord, settings: Dictionary) -> String:
    var chosen_type := "plains"
    var best_distance := INF
    for edge_name in HexMapConfig.EDGE_NAMES:
        var entry: Dictionary = settings.get(edge_name, {})
        var width: int = int(entry.get("width", 0))
        if width <= 0:
            continue
        var distance := _distance_to_edge(coord, edge_name)
        if distance < 0:
            continue
        var effective_width := _effective_edge_width(edge_name, width, coord)
        if effective_width <= 0:
            continue
        if distance < effective_width and float(distance) < best_distance:
            var terrain_type := String(entry.get("type", "plains"))
            if terrain_settings.supported_regions.has(terrain_type):
                chosen_type = terrain_type
            else:
                chosen_type = "plains"
            best_distance = float(distance)
    return chosen_type

func _distance_to_edge(coord: HexCoord, edge_name: String) -> int:
    var radius := grid.radius
    var q := coord.q
    var r := coord.r
    var s := -q - r
    match edge_name:
        "east":
            return max(0, radius - q)
        "north_east":
            return max(0, radius + r)
        "north_west":
            return max(0, radius - s)
        "west":
            return max(0, radius + q)
        "south_west":
            return max(0, radius - r)
        "south_east":
            return max(0, radius + s)
        _:
            return radius

func _effective_edge_width(edge_name: String, base_width: int, coord: HexCoord) -> int:
    var sanitized_width: int = max(0, base_width)
    if sanitized_width <= 0:
        return 0
    var jitter_range: int = max(0, config.edge_jitter)
    if jitter_range <= 0:
        return sanitized_width
    var noise := _edge_noise(edge_name, coord)
    var offset := int(round((noise * 2.0 - 1.0) * float(jitter_range)))
    var final_width: int = sanitized_width + offset
    return clampi(final_width, 0, grid.radius)

func _edge_noise(edge_name: String, coord: HexCoord) -> float:
    var value: int = hash([edge_name, coord.q, coord.r, config.map_seed])
    value = abs(value)
    return float(value % 1000003) / 1000003.0

func _scatter_random_features(hex_entries: Dictionary) -> void:
    var density := clampf(config.random_feature_density, 0.0, 1.0)
    if density <= 0.0:
        return
    var candidates: Array[Vector2i] = []
    for key in hex_entries.keys():
        var entry: Dictionary = hex_entries.get(key, {})
        var region := String(entry.get("region", "plains"))
        if region == "plains":
            candidates.append(key)
    if candidates.is_empty():
        return
    var target_count: int = int(round(density * float(candidates.size())))
    target_count = clampi(target_count, 0, candidates.size())
    if target_count <= 0:
        return
    var feature_types: Array[String] = terrain_settings.random_feature_types.duplicate()
    if feature_types.is_empty():
        return
    for i in range(target_count):
        if candidates.is_empty():
            break
        var index := rng.randi_range(0, candidates.size() - 1)
        var key: Vector2i = candidates[index]
        candidates.remove_at(index)
        var feature := feature_types[rng.randi_range(0, feature_types.size() - 1)]
        var coord := HexCoord.from_vector2i(key)
        _apply_region_to_entry(hex_entries, key, feature, coord)

func _apply_region_to_entry(hex_entries: Dictionary, key: Vector2i, region_type: String, coord: HexCoord) -> void:
    var sanitized_type := _sanitize_region_type(region_type)
    var entry: Dictionary = hex_entries.get(key, {})
    entry["coord"] = key
    entry["region"] = sanitized_type
    entry["is_sea"] = sanitized_type == "sea"
    entry["is_water"] = sanitized_type == "sea" or sanitized_type == "lake"
    entry["elev"] = _elevation_for(sanitized_type, coord)
    entry = _populate_visual_metadata(entry, coord)
    hex_entries[key] = entry

func _build_hex_entry(coord: HexCoord, region_type: String) -> Dictionary:
    var sanitized_type := _sanitize_region_type(region_type)
    var key := coord.to_vector2i()
    var entry := {
        "coord": key,
        "region": sanitized_type,
        "is_sea": sanitized_type == "sea",
        "is_water": sanitized_type == "sea" or sanitized_type == "lake",
        "elev": _elevation_for(sanitized_type, coord),
    }
    return _populate_visual_metadata(entry, coord)

func _sanitize_region_type(region_type: String) -> String:
    if terrain_settings.supported_regions.has(region_type):
        return region_type
    return "plains"

func _compute_region_counts(hex_entries: Dictionary) -> Dictionary:
    var counts: Dictionary = {}
    for entry in hex_entries.values():
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var region := String(entry.get("region", "plains"))
        counts[region] = int(counts.get(region, 0)) + 1
    return counts

func _elevation_for(region_type: String, coord: HexCoord) -> float:
    var base_levels: Dictionary = terrain_settings.reference_levels
    var jitter_levels: Dictionary = terrain_settings.elevation_jitter
    var base := float(base_levels.get(region_type, terrain_settings.default_land_elevation))
    var amplitude := float(jitter_levels.get(region_type, 0.03))
    var salt_seed: int = hash([region_type, coord.q, coord.r, config.map_seed])
    salt_seed = abs(salt_seed)
    var noise := (float(salt_seed % 1000003) / 1000003.0) * 2.0 - 1.0
    var elevation := clampf(base + noise * amplitude, 0.0, 1.0)
    if region_type == "sea" and elevation > 0.05:
        elevation = 0.05
    return elevation

func _world_height_from_elevation(elevation: float) -> float:
    if elevation < 0.0:
        return 0.0
    return elevation

func _populate_visual_metadata(entry: Dictionary, coord: HexCoord) -> Dictionary:
    var region := String(entry.get("region", "plains"))
    var axial := coord.to_vector2i()
    var elevation := float(entry.get("elev", 0.0))
    entry["world_height"] = _world_height_from_elevation(elevation)
    if entry.get("is_water", false):
        entry["layers"] = []
        entry["layer_region_map"] = {}
        entry["surface_variant"] = ""
        return entry
    var metadata := _generate_layer_metadata(region, axial)
    entry["layers"] = metadata.get("layers", [])
    entry["layer_region_map"] = metadata.get("layer_region_map", {})
    entry["surface_variant"] = metadata.get("surface_variant", "")
    return entry

func _generate_layer_metadata(region_type: String, axial: Vector2i) -> Dictionary:
    var layers: Array = []
    var layer_region_map: Dictionary = {}
    var primary_variant := ""
    var stack_variant: Variant = terrain_settings.land_layer_stack.get(region_type, [])
    if stack_variant is Array:
        for definition_variant in stack_variant:
            if typeof(definition_variant) != TYPE_DICTIONARY:
                continue
            var definition: Dictionary = definition_variant
            var layer_id := String(definition.get("id", ""))
            if layer_id.is_empty():
                continue
            var mesh_region := String(definition.get("mesh_region", region_type))
            var variant_key := _select_surface_variant(mesh_region, axial)
            layers.append({
                "id": layer_id,
                "mesh_region": mesh_region,
                "variant": variant_key,
            })
            if primary_variant.is_empty():
                if mesh_region == region_type and not variant_key.is_empty():
                    primary_variant = variant_key
                elif variant_key.is_empty() == false:
                    primary_variant = variant_key
            var region_layers: Array = []
            if layer_region_map.has(mesh_region):
                var stored_variant: Variant = layer_region_map[mesh_region]
                if stored_variant is Array:
                    region_layers = stored_variant
            if not region_layers.has(layer_id):
                region_layers.append(layer_id)
            layer_region_map[mesh_region] = region_layers
    if primary_variant.is_empty() and layers.size() > 0:
        var first_layer_variant: Variant = ""
        var first_layer_value: Variant = layers[0]
        if typeof(first_layer_value) == TYPE_DICTIONARY:
            first_layer_variant = (first_layer_value as Dictionary).get("variant", "")
        if typeof(first_layer_variant) == TYPE_STRING:
            primary_variant = String(first_layer_variant)
    return {
        "layers": layers,
        "layer_region_map": layer_region_map,
        "surface_variant": primary_variant,
    }

func _select_surface_variant(mesh_region_id: String, axial: Vector2i) -> String:
    var variant_list: Array[String] = []
    var defined_variants: Variant = terrain_settings.land_surface_variant_order.get(mesh_region_id, [])
    if defined_variants is Array:
        for variant in defined_variants:
            variant_list.append(String(variant))
    if variant_list.is_empty():
        var surface_paths: Variant = terrain_settings.land_surface_paths.get(mesh_region_id, {})
        if typeof(surface_paths) == TYPE_DICTIONARY:
            for key in (surface_paths as Dictionary).keys():
                variant_list.append(String(key))
        variant_list.sort()
    if variant_list.is_empty():
        return ""
    if variant_list.size() == 1:
        return variant_list[0]
    var hashed := _hash_axial_coord(axial)
    if hashed < 0:
        hashed = -hashed
    var index := hashed % variant_list.size()
    return variant_list[index]

func _hash_axial_coord(coord: Vector2i) -> int:
    var hash_value := int(coord.x) * 92837111
    hash_value ^= int(coord.y) * 689287499
    hash_value ^= hash_value >> 13
    hash_value &= 0x7fffffff
    return hash_value

func _apply_river_layer_rules(entry: Dictionary) -> Dictionary:
    var has_river := int(entry.get("river_mask", 0)) != 0 or bool(entry.get("is_mouth", false))
    if not has_river:
        return entry
    var layers_variant: Variant = entry.get("layers", [])
    var filtered_layers: Array = []
    if layers_variant is Array:
        for layer_variant in layers_variant:
            if typeof(layer_variant) != TYPE_DICTIONARY:
                continue
            var layer_dict: Dictionary = layer_variant
            var layer_id := String(layer_dict.get("id", ""))
            if layer_id == "plain" or layer_id == "valley":
                continue
            filtered_layers.append(layer_dict.duplicate())
    entry["layers"] = filtered_layers
    var region_map_variant: Variant = entry.get("layer_region_map", {})
    var sanitized_map: Dictionary = {}
    if typeof(region_map_variant) == TYPE_DICTIONARY:
        for mesh_region in (region_map_variant as Dictionary).keys():
            var list_variant: Variant = (region_map_variant as Dictionary)[mesh_region]
            var sanitized_layers: Array = []
            if list_variant is Array:
                for id_variant in list_variant:
                    var layer_id := String(id_variant)
                    if layer_id == "plain" or layer_id == "valley":
                        continue
                    sanitized_layers.append(layer_id)
            if sanitized_layers.is_empty():
                continue
            sanitized_map[String(mesh_region)] = sanitized_layers
    entry["layer_region_map"] = sanitized_map
    return entry

func _resolve_river_variant(mask: int, is_mouth: bool) -> Dictionary:
    if is_mouth:
        return {
            "variant": "mouth",
            "rotation": 0,
        }
    var sanitized_mask := mask & ((1 << RIVER_MASK_BIT_COUNT) - 1)
    if sanitized_mask == 0:
        return {}
    var lookup_value: Variant = _river_mask_lookup.get(sanitized_mask)
    if typeof(lookup_value) == TYPE_DICTIONARY:
        return (lookup_value as Dictionary).duplicate()
    return _find_best_river_variant(sanitized_mask)

func _create_river_mask_lookup() -> Dictionary:
    var lookup: Dictionary = {}
    var definitions: Array = terrain_settings.river_variant_definitions
    for definition_variant in definitions:
        if typeof(definition_variant) != TYPE_DICTIONARY:
            continue
        var definition: Dictionary = definition_variant
        var key := String(definition.get("key", ""))
        if key.is_empty():
            continue
        var canonical := int(definition.get("mask", 0))
        if canonical <= 0:
            continue
        for rotation in range(RIVER_MASK_BIT_COUNT):
            var rotated := _rotate_mask(canonical, rotation)
            if rotated == 0:
                continue
            if lookup.has(rotated):
                continue
            lookup[rotated] = {
                "variant": key,
                "rotation": rotation,
            }
    return lookup

func _rotate_mask(mask: int, steps: int) -> int:
    var rotated := 0
    for i in range(RIVER_MASK_BIT_COUNT):
        if (mask & (1 << i)) == 0:
            continue
        var new_index := (i + steps) % RIVER_MASK_BIT_COUNT
        rotated |= 1 << new_index
    return rotated

func _find_best_river_variant(mask: int) -> Dictionary:
    var best_variant := ""
    var best_rotation := 0
    var best_overlap := -1
    var definitions: Array = terrain_settings.river_variant_definitions
    for definition_variant in definitions:
        if typeof(definition_variant) != TYPE_DICTIONARY:
            continue
        var definition: Dictionary = definition_variant
        var key := String(definition.get("key", ""))
        if key.is_empty():
            continue
        var canonical := int(definition.get("mask", 0))
        if canonical <= 0:
            continue
        for rotation in range(RIVER_MASK_BIT_COUNT):
            var rotated := _rotate_mask(canonical, rotation)
            if rotated == mask:
                return {
                    "variant": key,
                    "rotation": rotation,
                }
            var overlap := _count_bits(mask & rotated)
            if overlap > best_overlap:
                best_overlap = overlap
                best_variant = key
                best_rotation = rotation
    if best_variant.is_empty():
        return {}
    return {
        "variant": best_variant,
        "rotation": best_rotation,
    }

func _count_bits(value: int) -> int:
    var count := 0
    var working := value
    while working != 0:
        working &= working - 1
        count += 1
    return count
