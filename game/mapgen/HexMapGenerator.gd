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

const SUPPORTED_REGIONS: Array[String] = [
    "plains",
    "hills",
    "mountains",
    "sea",
    "lake",
]

var config: HexMapConfig
var rng := RandomNumberGenerator.new()
var grid: HexGrid
var map_data: HexMapData
var phase_handlers: Dictionary = {}

var terrain_state: Dictionary = {}
var rivers_state: Dictionary = {}
var biomes_state: Dictionary = {}
var borders_state: Dictionary = {}
var settlements_state: Dictionary = {}
var roads_state: Dictionary = {}
var forts_state: Dictionary = {}

func _init(p_config: HexMapConfig = HexMapConfig.new()) -> void:
    config = p_config.duplicate_config()
    rng.seed = config.map_seed
    grid = HexGrid.new(config.map_radius)
    map_data = HexMapData.new(config)
    map_data.attach_grid(grid)
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
    rivers_state = {
        "networks": [],
    }
    map_data.set_stage_result(PHASE_RIVERS, rivers_state)

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
            if SUPPORTED_REGIONS.has(terrain_type):
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
    var feature_types: Array[String] = ["mountains", "hills", "lake"]
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
    entry["region"] = sanitized_type
    entry["is_sea"] = sanitized_type == "sea"
    entry["is_water"] = sanitized_type == "sea" or sanitized_type == "lake"
    entry["elev"] = _elevation_for(sanitized_type, coord)
    hex_entries[key] = entry

func _build_hex_entry(coord: HexCoord, region_type: String) -> Dictionary:
    var sanitized_type := _sanitize_region_type(region_type)
    var key := coord.to_vector2i()
    return {
        "coord": key,
        "region": sanitized_type,
        "is_sea": sanitized_type == "sea",
        "is_water": sanitized_type == "sea" or sanitized_type == "lake",
        "elev": _elevation_for(sanitized_type, coord),
    }

func _sanitize_region_type(region_type: String) -> String:
    if SUPPORTED_REGIONS.has(region_type):
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
    var base_levels := {
        "sea": 0.0,
        "lake": 0.12,
        "plains": 0.5,
        "hills": 0.68,
        "mountains": 0.9,
    }
    var jitter := {
        "sea": 0.02,
        "lake": 0.04,
        "plains": 0.05,
        "hills": 0.04,
        "mountains": 0.03,
    }
    var base := float(base_levels.get(region_type, 0.5))
    var amplitude := float(jitter.get(region_type, 0.03))
    var salt_seed: int = hash([region_type, coord.q, coord.r, config.map_seed])
    salt_seed = abs(salt_seed)
    var noise := (float(salt_seed % 1000003) / 1000003.0) * 2.0 - 1.0
    var elevation := clampf(base + noise * amplitude, 0.0, 1.0)
    if region_type == "sea" and elevation > 0.05:
        elevation = 0.05
    return elevation
