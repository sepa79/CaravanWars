extends RefCounted
class_name HexMapGenerator

const HexMapConfig := preload("res://mapgen/HexMapConfig.gd")
const HexGrid := preload("res://mapgen/HexGrid.gd")
const HexMapData := preload("res://mapgen/HexMapData.gd")
const HexCoord := preload("res://mapgen/HexCoord.gd")

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
    rng.seed = config.seed
    grid = HexGrid.new(config.map_radius)
    map_data = HexMapData.new(config)
    map_data.attach_grid(grid)
    _register_default_handlers()
    _reset_phase_state()

func generate() -> HexMapData:
    rng.seed = config.seed
    map_data.clear_stage_results()
    _reset_phase_state()
    print("[HexMapGenerator] Starting map generation with seed %d (radius=%d, kingdoms=%d)" % [
        config.seed,
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
    var coords: Array[HexCoord] = []
    var radius: int = grid.radius
    for q in range(-radius, radius + 1):
        var r1: int = max(-radius, -q - radius)
        var r2: int = min(radius, -q + radius)
        for r in range(r1, r2 + 1):
            coords.append(HexCoord.new(q, r))
    if coords.is_empty():
        return result

    var total_hexes: int = coords.size()
    var coastline_scores: Dictionary = {}
    var scored_coords: Array[Dictionary] = []
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        var score: float = _coastline_score(coord)
        coastline_scores[key] = score
        scored_coords.append({
            "coord": coord,
            "value": score,
        })
    scored_coords.sort_custom(Callable(self, "_compare_dict_value_desc"))

    var target_sea: int = int(round(config.sea_pct * float(total_hexes)))
    target_sea = clampi(target_sea, 0, total_hexes)
    var sea_lookup: Dictionary = {}
    var sea_coords := PackedVector2Array()
    var land_coords: Array[HexCoord] = []
    for index in range(scored_coords.size()):
        var entry: Dictionary = scored_coords[index]
        var coord: HexCoord = entry["coord"]
        var key: Vector2i = coord.to_vector2i()
        if index < target_sea:
            sea_lookup[key] = true
            sea_coords.append(key)
        else:
            land_coords.append(coord)

    var land_lookup: Dictionary = {}
    for coord in land_coords:
        land_lookup[coord.to_vector2i()] = true

    var land_count: int = land_coords.size()
    var hex_entries: Dictionary = {}
    var region_targets: Dictionary = _compute_region_targets(land_count)
    var seed_data: Dictionary = _plan_region_seeds(land_coords, land_lookup, region_targets)
    var assignments: Dictionary = _grow_region_assignments(land_coords, land_lookup, sea_lookup, region_targets, seed_data)
    var region_counts: Dictionary = _count_region_assignments(assignments)

    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        var region_type: String = String(assignments.get(key, "plains"))
        var elevation: float = _elevation_for(region_type, coord)
        hex_entries[key] = {
            "coord": key,
            "region": region_type,
            "is_sea": region_type == "sea",
            "is_water": region_type == "sea" or region_type == "lake",
            "elev": elevation,
        }

    var validation: Dictionary = _build_validation(assignments, land_lookup, seed_data.get("height_map", {}))

    result["hexes"] = hex_entries
    result["regions"] = {
        "targets": region_targets,
        "counts": region_counts,
        "seeds": seed_data.get("seeds", {}),
        "land_count": land_count,
        "sea_count": sea_lookup.size(),
    }
    result["coastline"] = {
        "scores": coastline_scores,
        "sea_threshold_index": target_sea,
        "sea_coords": sea_coords,
    }
    result["validation"] = validation
    return result

func _compute_region_targets(land_count: int) -> Dictionary:
    var targets: Dictionary = {
        "mountains": 0,
        "hills": 0,
        "plains": 0,
        "valley": 0,
        "lake": 0,
    }
    if land_count <= 0:
        return targets

    var mountains_target: int = int(round(config.mountains_pct * float(land_count)))
    if config.mountains_pct > 0.0 and mountains_target == 0:
        mountains_target = 1
    mountains_target = clampi(mountains_target, 0, land_count)
    targets["mountains"] = mountains_target

    var remaining: int = land_count - mountains_target
    if remaining <= 0:
        return targets

    var hills_target: int = int(round(0.25 * float(remaining)))
    hills_target = clampi(hills_target, 0, remaining)
    targets["hills"] = hills_target
    remaining -= hills_target
    if remaining <= 0:
        return targets

    var valley_target: int = int(round(0.2 * float(remaining)))
    valley_target = clampi(valley_target, 0, remaining)
    targets["valley"] = valley_target
    remaining -= valley_target

    if remaining > 0:
        targets["plains"] = remaining

    var lakes_target: int = int(round(config.lakes_pct * float(land_count)))
    if config.lakes_pct > 0.0 and lakes_target == 0 and int(targets["valley"]) > 0:
        lakes_target = 1
    var current_valley: int = int(targets["valley"])
    lakes_target = clampi(lakes_target, 0, current_valley)
    targets["lake"] = lakes_target
    targets["valley"] = current_valley - lakes_target

    var mountains_assigned: int = int(targets["mountains"])
    var hills_assigned: int = int(targets["hills"])
    if mountains_assigned == 0 and hills_assigned == 0:
        targets["valley"] = 0
        targets["lake"] = 0
        targets["plains"] = land_count
    else:
        var assigned_total: int = mountains_assigned + hills_assigned + int(targets["valley"]) + int(targets["lake"]) + int(targets["plains"])
        if assigned_total < land_count:
            targets["plains"] = int(targets["plains"]) + (land_count - assigned_total)
        elif assigned_total > land_count:
            var overflow: int = assigned_total - land_count
            var plains_available: int = int(targets["plains"])
            var trimmed: int = min(overflow, plains_available)
            targets["plains"] = plains_available - trimmed
    return targets

func _plan_region_seeds(land_coords: Array[HexCoord], land_lookup: Dictionary, targets: Dictionary) -> Dictionary:
    var seed_data: Dictionary = {
        "seeds": {
            "mountains": PackedVector2Array(),
            "hills": PackedVector2Array(),
            "plains": PackedVector2Array(),
            "valley": PackedVector2Array(),
            "lake": PackedVector2Array(),
        },
        "height_map": {},
    }
    if land_coords.is_empty():
        return seed_data

    var height_values: Dictionary = _build_height_map(land_coords)
    seed_data["height_map"] = height_values

    var sorted_high: Array[HexCoord] = _sort_coords_by_value(land_coords, height_values, true)
    var sorted_low: Array[HexCoord] = _sort_coords_by_value(land_coords, height_values, false)
    var sorted_mid: Array[HexCoord] = _sort_coords_by_midpoint(land_coords, height_values)

    var used: Dictionary = {}

    var mountain_seed_count: int = _estimate_seed_count(targets.get("mountains", 0), 10)
    var mountain_seeds: Array[HexCoord] = []
    for coord in sorted_high:
        if mountain_seeds.size() >= mountain_seed_count:
            break
        var key: Vector2i = coord.to_vector2i()
        if used.has(key):
            continue
        mountain_seeds.append(coord)
        used[key] = true
    seed_data["seeds"]["mountains"] = _coords_to_packed(mountain_seeds)

    var hill_seed_count: int = _estimate_seed_count(targets.get("hills", 0), 16)
    var hill_seeds: Array[HexCoord] = []
    for mountain in mountain_seeds:
        if hill_seeds.size() >= hill_seed_count:
            break
        var neighbors: Array[HexCoord] = grid.get_neighbor_coords(mountain)
        neighbors = _filter_land_coords(neighbors, land_lookup, used)
        neighbors = _sort_coords_by_value(neighbors, height_values, true)
        if neighbors.is_empty():
            continue
        var neighbor: HexCoord = neighbors[0]
        hill_seeds.append(neighbor)
        used[neighbor.to_vector2i()] = true
    if hill_seeds.size() < hill_seed_count:
        for coord in sorted_high:
            if hill_seeds.size() >= hill_seed_count:
                break
            var key: Vector2i = coord.to_vector2i()
            if used.has(key):
                continue
            hill_seeds.append(coord)
            used[key] = true
    seed_data["seeds"]["hills"] = _coords_to_packed(hill_seeds)

    var plains_seed_count: int = _estimate_seed_count(targets.get("plains", 0), 28)
    var plains_seeds: Array[HexCoord] = []
    for coord in sorted_mid:
        if plains_seeds.size() >= plains_seed_count:
            break
        var key: Vector2i = coord.to_vector2i()
        if used.has(key):
            continue
        plains_seeds.append(coord)
        used[key] = true
    if plains_seeds.is_empty() and int(targets.get("plains", 0)) > 0 and not sorted_mid.is_empty():
        var fallback: HexCoord = sorted_mid[0]
        plains_seeds.append(fallback)
        used[fallback.to_vector2i()] = true
    seed_data["seeds"]["plains"] = _coords_to_packed(plains_seeds)

    var high_seed_lookup: Dictionary = {}
    for coord in mountain_seeds:
        high_seed_lookup[coord.to_vector2i()] = true
    for coord in hill_seeds:
        high_seed_lookup[coord.to_vector2i()] = true

    var valley_seed_count: int = _estimate_seed_count(targets.get("valley", 0), 18)
    var valley_seeds: Array[HexCoord] = []
    for coord in sorted_low:
        if valley_seeds.size() >= valley_seed_count:
            break
        var key: Vector2i = coord.to_vector2i()
        if used.has(key):
            continue
        if not _has_adjacent_seed(coord, high_seed_lookup):
            continue
        valley_seeds.append(coord)
        used[key] = true
    if valley_seeds.size() < valley_seed_count:
        for coord in sorted_low:
            if valley_seeds.size() >= valley_seed_count:
                break
            var key: Vector2i = coord.to_vector2i()
            if used.has(key):
                continue
            valley_seeds.append(coord)
            used[key] = true
    seed_data["seeds"]["valley"] = _coords_to_packed(valley_seeds)

    var valley_lookup: Dictionary = {}
    for coord in valley_seeds:
        valley_lookup[coord.to_vector2i()] = true

    var lake_seed_count: int = _estimate_seed_count(targets.get("lake", 0), 8)
    var lake_seeds: Array[HexCoord] = []
    if lake_seed_count > 0:
        for coord in sorted_low:
            if lake_seeds.size() >= lake_seed_count:
                break
            var key: Vector2i = coord.to_vector2i()
            if used.has(key):
                continue
            if not _has_adjacent_seed(coord, valley_lookup):
                continue
            if not _is_depression(coord, height_values, land_lookup):
                continue
            lake_seeds.append(coord)
            used[key] = true
        if lake_seeds.size() < lake_seed_count:
            for coord in sorted_low:
                if lake_seeds.size() >= lake_seed_count:
                    break
                var key: Vector2i = coord.to_vector2i()
                if used.has(key):
                    continue
                lake_seeds.append(coord)
                used[key] = true
    seed_data["seeds"]["lake"] = _coords_to_packed(lake_seeds)

    return seed_data

func _grow_region_assignments(
    land_coords: Array[HexCoord],
    land_lookup: Dictionary,
    sea_lookup: Dictionary,
    targets: Dictionary,
    seed_data: Dictionary
) -> Dictionary:
    var assignments: Dictionary = {}
    for key in sea_lookup.keys():
        assignments[key] = "sea"

    var seeds_dict: Dictionary = seed_data.get("seeds", {})
    var height_values: Dictionary = seed_data.get("height_map", {})
    var land_types: Array[String] = ["mountains", "hills", "plains", "valley", "lake"]
    var region_counts: Dictionary = {}
    region_counts["sea"] = sea_lookup.size()
    for region_type in land_types:
        region_counts[region_type] = 0

    var valley_high_touch: Dictionary = {}
    var lake_touch: Dictionary = {}
    var queue: Array[Dictionary] = []

    for region_type in land_types:
        var packed: PackedVector2Array = seeds_dict.get(region_type, PackedVector2Array())
        for pos in packed:
            var coord: HexCoord = HexCoord.from_vector2i(pos)
            var key: Vector2i = coord.to_vector2i()
            if assignments.has(key):
                continue
            assignments[key] = region_type
            if region_type == "valley":
                valley_high_touch[key] = _valley_connected_to_high(coord, assignments, valley_high_touch)
            elif region_type == "lake":
                lake_touch[key] = _lake_has_valley_contact(coord, assignments, lake_touch, land_lookup)
            region_counts[region_type] = int(region_counts.get(region_type, 0)) + 1
            queue.append({
                "coord": coord,
                "type": region_type,
            })

    var land_lookup_keys: Array = land_lookup.keys()
    var land_total: int = land_lookup_keys.size()
    var assigned_land: int = 0
    for region_type in land_types:
        assigned_land += int(region_counts.get(region_type, 0))

    if assigned_land < land_total and int(targets.get("plains", 0)) <= 0:
        targets["plains"] = land_total - assigned_land

    var queue_index: int = 0
    while queue_index < queue.size():
        var current: Dictionary = queue[queue_index]
        queue_index += 1
        var region_type: String = current["type"]
        if _target_reached(region_type, region_counts, targets):
            continue
        var coord: HexCoord = current["coord"]
        var neighbors: Array[HexCoord] = grid.get_neighbor_coords(coord)
        for neighbor in neighbors:
            var key: Vector2i = neighbor.to_vector2i()
            if not land_lookup.has(key):
                continue
            if assignments.has(key):
                continue
            if _target_reached(region_type, region_counts, targets):
                break
            if not _region_can_claim(region_type, neighbor, assignments, valley_high_touch, lake_touch, height_values, land_lookup):
                continue
            assignments[key] = region_type
            if region_type == "valley":
                valley_high_touch[key] = _valley_connected_to_high(neighbor, assignments, valley_high_touch)
            elif region_type == "lake":
                lake_touch[key] = _lake_has_valley_contact(neighbor, assignments, lake_touch, land_lookup)
            region_counts[region_type] = int(region_counts.get(region_type, 0)) + 1
            queue.append({
                "coord": neighbor,
                "type": region_type,
            })

    for coord in land_coords:
        var key: Vector2i = coord.to_vector2i()
        if assignments.has(key):
            continue
        assignments[key] = "plains"

    return assignments

func _count_region_assignments(assignments: Dictionary) -> Dictionary:
    var counts: Dictionary = {}
    for key in assignments.keys():
        var region_type: String = String(assignments[key])
        counts[region_type] = int(counts.get(region_type, 0)) + 1
    return counts

func _build_validation(assignments: Dictionary, land_lookup: Dictionary, height_map: Dictionary) -> Dictionary:
    var stray_lakes := PackedVector2Array()
    var isolated_sea_tiles := PackedVector2Array()
    var valleys_without_high := PackedVector2Array()
    for key in assignments.keys():
        var cell: Vector2i = key
        var region_type: String = String(assignments[cell])
        var coord: HexCoord = HexCoord.from_vector2i(cell)
        if region_type == "lake":
            if _lake_is_on_ridge(coord, assignments, height_map, land_lookup):
                stray_lakes.append(cell)
        elif region_type == "sea":
            if _is_isolated_sea(coord, assignments):
                isolated_sea_tiles.append(cell)
        elif region_type == "valley":
            if not _valley_has_direct_high(coord, assignments):
                valleys_without_high.append(cell)
    return {
        "lakes_on_ridges": stray_lakes,
        "isolated_seas": isolated_sea_tiles,
        "valleys_without_high": valleys_without_high,
    }

func _compare_dict_value_desc(a: Dictionary, b: Dictionary) -> bool:
    return a.get("value", 0.0) > b.get("value", 0.0)

func _compare_dict_value_asc(a: Dictionary, b: Dictionary) -> bool:
    return a.get("value", 0.0) < b.get("value", 0.0)

func _coord_noise(coord: HexCoord, salt: int = 0) -> float:
    var value: int = hash([coord.q, coord.r, salt, config.seed])
    value = abs(value)
    return float(value % 1000003) / 1000003.0

func _coastline_score(coord: HexCoord) -> float:
    var distance := float(grid.axial_distance(coord, HexCoord.new(0, 0))) / float(max(1, grid.radius))
    var primary := (_coord_noise(coord, 17) - 0.5) * 0.7
    var secondary := (_coord_noise(coord, 53) - 0.5) * 0.3 * (1.0 - distance)
    return distance + primary + secondary

func _height_value(coord: HexCoord) -> float:
    var distance := float(grid.axial_distance(coord, HexCoord.new(0, 0))) / float(max(1, grid.radius))
    var ridge_noise := (_coord_noise(coord, 97) - 0.5) * 0.5
    var basin_noise := (_coord_noise(coord, 211) - 0.5) * 0.2 * (1.0 - distance)
    return clampf(1.0 - distance + ridge_noise + basin_noise, 0.0, 1.0)

func _build_height_map(coords: Array[HexCoord]) -> Dictionary:
    var values: Dictionary = {}
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        values[key] = _height_value(coord)
    return values

func _sort_coords_by_value(coords: Array[HexCoord], values: Dictionary, descending: bool) -> Array[HexCoord]:
    var scored: Array[Dictionary] = []
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        var score: float = float(values.get(key, 0.0))
        scored.append({
            "coord": coord,
            "value": score,
        })
    var comparator := Callable(self, "_compare_dict_value_desc") if descending else Callable(self, "_compare_dict_value_asc")
    scored.sort_custom(comparator)
    var result: Array[HexCoord] = []
    for entry in scored:
        var sorted_coord: HexCoord = entry["coord"]
        result.append(sorted_coord)
    return result

func _sort_coords_by_midpoint(coords: Array[HexCoord], values: Dictionary) -> Array[HexCoord]:
    var scored: Array[Dictionary] = []
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        var score: float = float(values.get(key, 0.0))
        scored.append({
            "coord": coord,
            "value": abs(score - 0.5),
        })
    scored.sort_custom(Callable(self, "_compare_dict_value_asc"))
    var result: Array[HexCoord] = []
    for entry in scored:
        var sorted_coord: HexCoord = entry["coord"]
        result.append(sorted_coord)
    return result

func _coords_to_packed(coords: Array[HexCoord]) -> PackedVector2Array:
    var packed := PackedVector2Array()
    for coord in coords:
        packed.append(coord.to_vector2i())
    return packed

func _estimate_seed_count(target: int, ideal_size: int) -> int:
    if target <= 0:
        return 0
    var size: int = max(1, ideal_size)
    var estimated: int = int(ceil(float(target) / float(size)))
    estimated = max(1, estimated)
    estimated = min(estimated, target)
    return estimated

func _filter_land_coords(neighbors: Array[HexCoord], land_lookup: Dictionary, used: Dictionary) -> Array[HexCoord]:
    var filtered: Array[HexCoord] = []
    for neighbor in neighbors:
        var key: Vector2i = neighbor.to_vector2i()
        if not land_lookup.has(key):
            continue
        if used.has(key):
            continue
        filtered.append(neighbor)
    return filtered

func _has_adjacent_seed(coord: HexCoord, lookup: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        if lookup.has(neighbor.to_vector2i()):
            return true
    return false

func _is_depression(coord: HexCoord, height_values: Dictionary, land_lookup: Dictionary) -> bool:
    var key := coord.to_vector2i()
    var base_height := float(height_values.get(key, 0.0))
    var higher_neighbors := 0
    for neighbor in grid.get_neighbor_coords(coord):
        var n_key := neighbor.to_vector2i()
        if not land_lookup.has(n_key):
            continue
        var neighbor_height := float(height_values.get(n_key, base_height + 0.1))
        if neighbor_height > base_height + 0.02:
            higher_neighbors += 1
    return higher_neighbors >= 2

func _target_reached(region_type: String, region_counts: Dictionary, targets: Dictionary) -> bool:
    if region_type == "plains":
        return false
    if not targets.has(region_type):
        return false
    var target: int = int(targets.get(region_type, 0))
    if target <= 0:
        return true
    return int(region_counts.get(region_type, 0)) >= target

func _region_can_claim(
    region_type: String,
    coord: HexCoord,
    assignments: Dictionary,
    valley_high_touch: Dictionary,
    lake_touch: Dictionary,
    height_values: Dictionary,
    land_lookup: Dictionary
) -> bool:
    if region_type == "valley":
        return _valley_connected_to_high(coord, assignments, valley_high_touch)
    if region_type == "lake":
        return _lake_can_claim(coord, assignments, lake_touch, height_values, land_lookup)
    return true

func _valley_connected_to_high(coord: HexCoord, assignments: Dictionary, valley_high_touch: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        var key: Vector2i = neighbor.to_vector2i()
        if not assignments.has(key):
            continue
        var neighbor_type: String = String(assignments[key])
        if neighbor_type == "mountains" or neighbor_type == "hills":
            return true
        if neighbor_type == "valley" and valley_high_touch.get(key, false):
            return true
    return false

func _lake_can_claim(
    coord: HexCoord,
    assignments: Dictionary,
    lake_touch: Dictionary,
    height_values: Dictionary,
    land_lookup: Dictionary
) -> bool:
    var key := coord.to_vector2i()
    var base_height := float(height_values.get(key, 0.0))
    var higher_neighbors := 0
    var has_contact := false
    for neighbor in grid.get_neighbor_coords(coord):
        var n_key := neighbor.to_vector2i()
        if not land_lookup.has(n_key):
            continue
        var neighbor_type: String = String(assignments.get(n_key, ""))
        if neighbor_type == "valley":
            has_contact = true
        elif neighbor_type == "lake" and lake_touch.get(n_key, false):
            has_contact = true
        if height_values.has(n_key):
            if float(height_values[n_key]) > base_height + 0.01:
                higher_neighbors += 1
        elif neighbor_type == "mountains" or neighbor_type == "hills":
            higher_neighbors += 1
    return has_contact and higher_neighbors >= 2

func _lake_has_valley_contact(coord: HexCoord, assignments: Dictionary, lake_touch: Dictionary, land_lookup: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        var key: Vector2i = neighbor.to_vector2i()
        if not land_lookup.has(key):
            continue
        var neighbor_type: String = String(assignments.get(key, ""))
        if neighbor_type == "valley":
            return true
        if neighbor_type == "lake" and lake_touch.get(key, false):
            return true
    return false

func _lake_is_on_ridge(
    coord: HexCoord,
    assignments: Dictionary,
    height_map: Dictionary,
    land_lookup: Dictionary
) -> bool:
    var key := coord.to_vector2i()
    var base_height := float(height_map.get(key, 0.0))
    var higher_neighbors := 0
    var valley_neighbors := 0
    for neighbor in grid.get_neighbor_coords(coord):
        var n_key := neighbor.to_vector2i()
        if not land_lookup.has(n_key):
            continue
        var neighbor_type: String = String(assignments.get(n_key, ""))
        if neighbor_type == "valley":
            valley_neighbors += 1
        if height_map.has(n_key):
            if float(height_map[n_key]) > base_height + 0.01:
                higher_neighbors += 1
        elif neighbor_type == "mountains" or neighbor_type == "hills":
            higher_neighbors += 1
    return higher_neighbors < 2 or valley_neighbors == 0

func _is_isolated_sea(coord: HexCoord, assignments: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        var key: Vector2i = neighbor.to_vector2i()
        if String(assignments.get(key, "")) == "sea":
            return false
    return true

func _valley_has_direct_high(coord: HexCoord, assignments: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        var key: Vector2i = neighbor.to_vector2i()
        var neighbor_type: String = String(assignments.get(key, ""))
        if neighbor_type == "mountains" or neighbor_type == "hills":
            return true
    return false

func _elevation_for(region_type: String, coord: HexCoord) -> float:
    var base_levels := {
        "sea": 0.0,
        "lake": 0.1,
        "valley": 0.3,
        "plains": 0.5,
        "hills": 0.7,
        "mountains": 0.9,
    }
    var jitter := {
        "sea": 0.02,
        "lake": 0.03,
        "valley": 0.04,
        "plains": 0.05,
        "hills": 0.04,
        "mountains": 0.03,
    }
    var base := float(base_levels.get(region_type, 0.5))
    var amplitude := float(jitter.get(region_type, 0.03))
    var salt_seed: int = hash([region_type, coord.q, coord.r])
    var salt: int = abs(salt_seed) % 8191
    var noise := (_coord_noise(coord, salt) - 0.5) * 2.0 * amplitude
    var elevation := clampf(base + noise, 0.0, 1.0)
    if region_type == "sea" and elevation > 0.05:
        elevation = min(elevation, 0.05)
    return elevation
