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
    var target_sea: int = int(round(config.sea_pct * float(total_hexes)))
    target_sea = clampi(target_sea, 0, total_hexes)
    var coastline_plan: Dictionary = _plan_coast_regions(coords, target_sea)
    var sea_lookup: Dictionary = coastline_plan.get("sea_lookup", {})
    var sea_coords: PackedVector2Array = coastline_plan.get("sea_coords", PackedVector2Array())
    var land_coords: Array[HexCoord] = []
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        if sea_lookup.has(key):
            continue
        land_coords.append(coord)

    var land_lookup: Dictionary = {}
    for coord in land_coords:
        land_lookup[coord.to_vector2i()] = true

    var land_count: int = land_coords.size()
    var hex_entries: Dictionary = {}
    var region_targets: Dictionary = _compute_region_targets(land_count)
    var ridge_plan: Dictionary = _plan_ridge_regions(land_coords, land_lookup, coastline_plan)
    var seed_data: Dictionary = _plan_region_seeds(land_coords, land_lookup, region_targets, ridge_plan)
    var assignments: Dictionary = _grow_region_assignments(
        land_coords,
        land_lookup,
        sea_lookup,
        region_targets,
        seed_data,
        ridge_plan
    )
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

    var validation: Dictionary = _build_validation(
        assignments,
        land_lookup,
        seed_data.get("height_map", {}),
        coastline_plan,
        ridge_plan
    )

    result["hexes"] = hex_entries
    result["regions"] = {
        "targets": region_targets,
        "counts": region_counts,
        "seeds": seed_data.get("seeds", {}),
        "land_count": land_count,
        "sea_count": sea_lookup.size(),
    }
    result["coastline"] = {
        "selected_sides": coastline_plan.get("sides", PackedInt32Array()),
        "side_counts": coastline_plan.get("side_counts", {}),
        "side_depths": coastline_plan.get("side_depths", {}),
        "fill_order": coastline_plan.get("fill_order", PackedVector2Array()),
        "sea_coords": sea_coords,
        "target_sea": target_sea,
        "depth_limit": coastline_plan.get("depth_limit", 0),
    }
    result["ridge"] = {
        "selected_sides": ridge_plan.get("sides", PackedInt32Array()),
        "side_widths": ridge_plan.get("side_widths", {}),
        "ridge_cells": ridge_plan.get("ridge_cells", PackedVector2Array()),
        "ridge_strength": ridge_plan.get("ridge_strength", {}),
        "pass_path": ridge_plan.get("pass_path", PackedVector2Array()),
        "pass_lookup": ridge_plan.get("pass_lookup", {}),
        "pass_width": ridge_plan.get("pass_width", 0),
    }
    result["validation"] = validation
    return result

func _plan_coast_regions(coords: Array[HexCoord], target_sea: int) -> Dictionary:
    var plan: Dictionary = {
        "sea_lookup": {},
        "sea_coords": PackedVector2Array(),
        "fill_order": PackedVector2Array(),
        "sides": PackedInt32Array(),
        "side_counts": {},
        "membership": {},
        "depth_limit": 0,
    }
    if coords.is_empty():
        return plan

    var direction_count: int = HexGrid.AXIAL_DIRECTIONS.size()
    var boundary_sets: Array = []
    for _i in range(direction_count):
        boundary_sets.append({})
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        for dir_index in range(direction_count):
            var dir: Vector2i = HexGrid.AXIAL_DIRECTIONS[dir_index]
            var neighbor := HexCoord.new(coord.q + dir.x, coord.r + dir.y)
            if not grid.is_within_bounds(neighbor):
                boundary_sets[dir_index][key] = coord

    var boundary_arrays: Array = []
    for dir_index in range(direction_count):
        var arr: Array[HexCoord] = []
        var boundary_dict: Dictionary = boundary_sets[dir_index]
        for boundary_key in boundary_dict.keys():
            var boundary_coord: HexCoord = boundary_dict[boundary_key]
            arr.append(boundary_coord)
        boundary_arrays.append(arr)

    var available_sides: Array[int] = []
    for i in range(direction_count):
        if boundary_arrays[i].is_empty():
            continue
        available_sides.append(i)
    if available_sides.is_empty():
        return plan
    _shuffle_array_with_rng(available_sides)

    var configured_sea_sides: Array[int] = []
    var forbidden_sides: Dictionary = {}
    if config.side_modes.size() == direction_count:
        for side_index in available_sides:
            var side_mode: String = config.side_modes[side_index]
            if side_mode == HexMapConfig.SIDE_TYPE_SEA:
                configured_sea_sides.append(side_index)
            elif side_mode == HexMapConfig.SIDE_TYPE_MOUNTAINS:
                forbidden_sides[side_index] = true

    var side_min: int = max(1, config.coastline_sides_min)
    var side_max: int = max(side_min, config.coastline_sides_max)
    side_min = clampi(side_min, 1, available_sides.size())
    side_max = clampi(side_max, side_min, available_sides.size())

    var chosen: Array[int] = []
    if not configured_sea_sides.is_empty():
        chosen = configured_sea_sides.duplicate()
    else:
        var fallback_pool: Array[int] = []
        for side_index in available_sides:
            if forbidden_sides.has(side_index):
                continue
            fallback_pool.append(side_index)
        var fallback_source: Array[int] = fallback_pool.duplicate()
        if fallback_source.is_empty():
            fallback_source = available_sides.duplicate()
        _shuffle_array_with_rng(fallback_source)
        var side_count: int = side_min
        if side_max > side_min:
            side_count = rng.randi_range(side_min, side_max)
        side_count = clampi(side_count, 1, available_sides.size())
        for i in range(side_count):
            if i >= fallback_source.size():
                break
            chosen.append(fallback_source[i])

    var seeding_order: Array[int] = chosen.duplicate()
    var selected: Array[int] = chosen.duplicate()
    selected.sort()

    var sea_target_limit: int = target_sea
    if not configured_sea_sides.is_empty():
        sea_target_limit = coords.size()

    var packed_sides := PackedInt32Array()
    for side_index in selected:
        packed_sides.append(side_index)

    if selected.is_empty():
        var fallback_candidates := coords.duplicate()
        _shuffle_array_with_rng(fallback_candidates)
        var fallback_lookup: Dictionary = {}
        var fallback_coords := PackedVector2Array()
        for idx in range(min(target_sea, fallback_candidates.size())):
            var fallback_coord: HexCoord = fallback_candidates[idx]
            var fallback_key: Vector2i = fallback_coord.to_vector2i()
            fallback_lookup[fallback_key] = true
            fallback_coords.append(fallback_key)
        plan["sea_lookup"] = fallback_lookup
        plan["sea_coords"] = fallback_coords
        plan["fill_order"] = fallback_coords
        plan["sides"] = packed_sides
        plan["side_counts"] = {}
        plan["membership"] = {}
        plan["depth_limit"] = 0
        return plan

    var depth_min: int = max(0, config.coastline_depth_min)
    var depth_max: int = max(depth_min, config.coastline_depth_max)
    var depth_limit: int = depth_min
    if depth_max > depth_min:
        depth_limit = rng.randi_range(depth_min, depth_max)
    var side_depth_limits: Dictionary = {}
    var max_side_limit: int = depth_limit
    if config.side_widths.size() == direction_count:
        for side_index in selected:
            var configured_width: int = max(0, int(config.side_widths[side_index]))
            side_depth_limits[side_index] = configured_width
            if configured_width > max_side_limit:
                max_side_limit = configured_width
    depth_limit = max_side_limit

    var queue: Array = []
    var enqueued: Dictionary = {}
    var sea_lookup: Dictionary = {}
    var membership: Dictionary = {}
    var side_counts: Dictionary = {}
    var fill_order := PackedVector2Array()

    for side_index in selected:
        side_counts[side_index] = 0

    var jitter_strength: float = clampf(config.side_jitter, 0.0, 1.0)

    for side_index in seeding_order:
        var front: Array = boundary_arrays[side_index].duplicate()
        if front.is_empty():
            continue
        _shuffle_array_with_rng(front)
        for coord in front:
            if sea_lookup.size() >= sea_target_limit:
                break
            var key: Vector2i = coord.to_vector2i()
            if sea_lookup.has(key):
                continue
            sea_lookup[key] = true
            membership[key] = side_index
            fill_order.append(key)
            side_counts[side_index] = int(side_counts.get(side_index, 0)) + 1
            var side_limit: int = int(side_depth_limits.get(side_index, depth_limit))
            if side_limit <= 0:
                continue
            for neighbor in grid.get_neighbor_coords(coord):
                var nkey: Vector2i = neighbor.to_vector2i()
                if sea_lookup.has(nkey):
                    continue
                if enqueued.has(nkey):
                    continue
                var support_neighbors: int = 0
                for support in grid.get_neighbor_coords(neighbor):
                    var support_key: Vector2i = support.to_vector2i()
                    if not sea_lookup.has(support_key):
                        continue
                    if int(membership.get(support_key, side_index)) != side_index:
                        continue
                    support_neighbors += 1
                if support_neighbors <= 0:
                    continue
                var priority := 1.0 + ((_coord_noise(neighbor, 911 + side_index) - 0.5) * jitter_strength)
                queue.append({
                    "coord": neighbor,
                    "depth": 1,
                    "side": side_index,
                    "value": priority,
                })
                enqueued[nkey] = true
        if sea_lookup.size() >= sea_target_limit:
            break

    while not queue.is_empty() and sea_lookup.size() < sea_target_limit:
        queue.sort_custom(Callable(self, "_compare_dict_value_asc"))
        var current: Dictionary = queue.pop_front()
        var coord: HexCoord = current["coord"]
        var key: Vector2i = coord.to_vector2i()
        if sea_lookup.has(key):
            continue
        var side_index: int = int(current.get("side", -1))
        if side_index < 0:
            continue
        var current_depth: int = int(current.get("depth", 0))
        var side_limit: int = int(side_depth_limits.get(side_index, depth_limit))
        if current_depth > side_limit:
            continue
        var matching_neighbors: int = 0
        for neighbor in grid.get_neighbor_coords(coord):
            var neighbor_key: Vector2i = neighbor.to_vector2i()
            if not sea_lookup.has(neighbor_key):
                continue
            if int(membership.get(neighbor_key, side_index)) != side_index:
                continue
            matching_neighbors += 1
        if matching_neighbors <= 0:
            continue
        sea_lookup[key] = true
        membership[key] = side_index
        fill_order.append(key)
        side_counts[side_index] = int(side_counts.get(side_index, 0)) + 1
        if current_depth >= side_limit:
            continue
        var next_depth: int = current_depth + 1
        if next_depth > side_limit:
            continue
        for neighbor in grid.get_neighbor_coords(coord):
            var nkey: Vector2i = neighbor.to_vector2i()
            if sea_lookup.has(nkey):
                continue
            if enqueued.has(nkey):
                continue
            var support_neighbors: int = 0
            for support in grid.get_neighbor_coords(neighbor):
                var support_key: Vector2i = support.to_vector2i()
                if not sea_lookup.has(support_key):
                    continue
                if int(membership.get(support_key, side_index)) != side_index:
                    continue
                support_neighbors += 1
            if support_neighbors <= 0:
                continue
            var noise := (_coord_noise(neighbor, 643 + side_index) - 0.5) * jitter_strength
            var priority := float(next_depth) + noise
            queue.append({
                "coord": neighbor,
                "depth": next_depth,
                "side": side_index,
                "value": priority,
            })
            enqueued[nkey] = true

    plan["sea_lookup"] = sea_lookup
    plan["sea_coords"] = fill_order
    plan["fill_order"] = fill_order
    plan["sides"] = packed_sides
    plan["side_counts"] = side_counts
    plan["membership"] = membership
    plan["depth_limit"] = depth_limit
    plan["side_depths"] = side_depth_limits
    return plan

func _plan_ridge_regions(
    land_coords: Array[HexCoord],
    land_lookup: Dictionary,
    _coast_plan: Dictionary
) -> Dictionary:
    var plan: Dictionary = {
        "sides": PackedInt32Array(),
        "side_widths": {},
        "ridge_lookup": {},
        "ridge_strength": {},
        "ridge_cells": PackedVector2Array(),
        "pass_lookup": {},
        "pass_path": PackedVector2Array(),
        "pass_width": max(1, config.ridge_pass_width),
    }
    if land_coords.is_empty():
        return plan

    var direction_count: int = HexGrid.AXIAL_DIRECTIONS.size()
    var desired_sides: Array[int] = []
    if config.side_modes.size() == direction_count:
        for side_index in range(direction_count):
            var side_mode: String = config.side_modes[side_index]
            if side_mode == HexMapConfig.SIDE_TYPE_MOUNTAINS:
                desired_sides.append(side_index)
    var selected: Array[int] = []
    if not desired_sides.is_empty():
        desired_sides.sort()
        for side_index in desired_sides:
            selected.append(side_index)
    else:
        var fallback: Array[int] = []
        if config.side_modes.size() == direction_count:
            for side_index in range(direction_count):
                if config.side_modes[side_index] == HexMapConfig.SIDE_TYPE_SEA:
                    continue
                fallback.append(side_index)
        else:
            for side_index in range(direction_count):
                fallback.append(side_index)
        if fallback.is_empty():
            for side_index in range(direction_count):
                fallback.append(side_index)
        _shuffle_array_with_rng(fallback)
        if not fallback.is_empty():
            selected.append(fallback[0])
            if fallback.size() > 1:
                selected.append(fallback[1])
    selected.sort()

    var packed_sides := PackedInt32Array()
    for side_index in selected:
        packed_sides.append(side_index)
    plan["sides"] = packed_sides

    var side_widths: Dictionary = {}
    var default_width: int = HexMapConfig.DEFAULT_SIDE_BORDER_WIDTH
    if config.side_widths.size() == direction_count:
        for side_index in selected:
            var configured_width: int = max(1, int(config.side_widths[side_index]))
            side_widths[side_index] = configured_width
    if side_widths.is_empty():
        for side_index in selected:
            side_widths[side_index] = default_width
    plan["side_widths"] = side_widths

    var ridge_lookup: Dictionary = {}
    var ridge_strength: Dictionary = {}
    var jitter_strength: float = clampf(config.side_jitter, 0.0, 1.0)
    for coord in land_coords:
        var key: Vector2i = coord.to_vector2i()
        var best_strength: float = 0.0
        for side_index in selected:
            var band_width: int = int(side_widths.get(side_index, default_width))
            if band_width <= 0:
                continue
            var depth: int = _distance_to_side(coord, side_index)
            var normalized: float = 1.0 - (float(depth) / float(max(1, band_width)))
            if normalized <= 0.0:
                continue
            var noise := (_coord_noise(coord, 1223 + side_index) - 0.5) * (0.15 + (jitter_strength * 0.1))
            var strength := clampf(normalized + noise, 0.0, 1.0)
            if strength > best_strength:
                best_strength = strength
        ridge_strength[key] = best_strength
        if best_strength > 0.05:
            ridge_lookup[key] = true

    var ridge_cells := PackedVector2Array()
    for key in ridge_lookup.keys():
        ridge_cells.append(Vector2(key))

    var boundary_per_side: Dictionary = {}
    for side_index in selected:
        boundary_per_side[side_index] = []
    for coord in land_coords:
        var key: Vector2i = coord.to_vector2i()
        for side_index in selected:
            if _distance_to_side(coord, side_index) != 0:
                continue
            var arr: Array = boundary_per_side.get(side_index, [])
            arr.append(coord)
            boundary_per_side[side_index] = arr

    var pass_entries: Array[HexCoord] = []
    var center := HexCoord.new(0, 0)
    for side_index in selected:
        var front: Array = boundary_per_side.get(side_index, [])
        if front.is_empty():
            continue
        var best_coord: HexCoord = front[0]
        var best_score: float = INF
        for candidate in front:
            var score := float(grid.axial_distance(candidate, center))
            var noise := (_coord_noise(candidate, 1931 + side_index) - 0.5) * (0.6 * jitter_strength)
            score += noise
            if score < best_score:
                best_score = score
                best_coord = candidate
        pass_entries.append(best_coord)

    if pass_entries.is_empty() and ridge_cells.size() > 0:
        var fallback_coord := HexCoord.from_vector2i(Vector2i(ridge_cells[0]))
        var fallback_score: float = float(grid.axial_distance(fallback_coord, center))
        for cell_key in ridge_lookup.keys():
            var coord := HexCoord.from_vector2i(cell_key)
            var score := float(grid.axial_distance(coord, center))
            if score < fallback_score:
                fallback_score = score
                fallback_coord = coord
        pass_entries.append(fallback_coord)

    var pass_lookup: Dictionary = {}
    var max_band: int = 0
    for side_index in selected:
        max_band = max(max_band, int(side_widths.get(side_index, default_width)))
    if max_band <= 0:
        max_band = default_width
    var pass_width: int = max(1, int(plan["pass_width"]))
    var depth_limit: int = max_band + pass_width
    var queue: Array[Dictionary] = []
    for entry in pass_entries:
        var key: Vector2i = entry.to_vector2i()
        if pass_lookup.has(key):
            continue
        pass_lookup[key] = 0
        queue.append({
            "coord": entry,
            "depth": 0,
        })

    var queue_index: int = 0
    while queue_index < queue.size():
        var current: Dictionary = queue[queue_index]
        queue_index += 1
        var coord: HexCoord = current["coord"]
        var depth: int = int(current.get("depth", 0))
        for neighbor in grid.get_neighbor_coords(coord):
            var nkey: Vector2i = neighbor.to_vector2i()
            if pass_lookup.has(nkey):
                continue
            if not land_lookup.has(nkey):
                continue
            var next_depth: int = depth + 1
            if next_depth > depth_limit:
                continue
            var ridge_strength_value: float = float(ridge_strength.get(nkey, 0.0))
            if ridge_strength_value <= 0.0 and next_depth > pass_width:
                continue
            pass_lookup[nkey] = next_depth
            queue.append({
                "coord": neighbor,
                "depth": next_depth,
            })

    var pass_path := PackedVector2Array()
    for key in pass_lookup.keys():
        pass_path.append(Vector2(key))

    plan["ridge_lookup"] = ridge_lookup
    plan["ridge_strength"] = ridge_strength
    plan["ridge_cells"] = ridge_cells
    plan["pass_lookup"] = pass_lookup
    plan["pass_path"] = pass_path
    plan["pass_width"] = pass_width
    return plan

func _shuffle_array_with_rng(items: Array) -> void:
    var count: int = items.size()
    if count <= 1:
        return
    for index in range(count - 1, 0, -1):
        var swap_index: int = rng.randi_range(0, index)
        if swap_index == index:
            continue
        var temp = items[index]
        items[index] = items[swap_index]
        items[swap_index] = temp

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

func _plan_region_seeds(
    land_coords: Array[HexCoord],
    land_lookup: Dictionary,
    targets: Dictionary,
    ridge_plan: Dictionary
) -> Dictionary:
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

    var height_values: Dictionary = _build_height_map(land_coords, ridge_plan)
    seed_data["height_map"] = height_values

    var ridge_lookup: Dictionary = ridge_plan.get("ridge_lookup", {})
    var ridge_cells_packed: PackedVector2Array = ridge_plan.get("ridge_cells", PackedVector2Array())
    var ridge_coords: Array[HexCoord] = []
    for pos in ridge_cells_packed:
        ridge_coords.append(HexCoord.from_vector2i(Vector2i(pos)))

    var pass_lookup: Dictionary = ridge_plan.get("pass_lookup", {})
    var pass_width: int = max(1, int(ridge_plan.get("pass_width", config.ridge_pass_width)))
    var extra_spacing: int = max(1, config.extra_mountain_spacing)

    var sorted_high: Array[HexCoord] = _sort_coords_by_value(land_coords, height_values, true)
    var sorted_low: Array[HexCoord] = _sort_coords_by_value(land_coords, height_values, false)
    var sorted_mid: Array[HexCoord] = _sort_coords_by_midpoint(land_coords, height_values)

    var used: Dictionary = {}

    var plains_seeds: Array[HexCoord] = []
    var hill_seeds: Array[HexCoord] = []
    var mountain_seeds: Array[HexCoord] = []
    var pass_neighbors: Array[HexCoord] = []

    for pass_key in pass_lookup.keys():
        var key: Vector2i = pass_key
        var coord := HexCoord.from_vector2i(key)
        if used.has(key):
            continue
        var depth: int = int(pass_lookup[key])
        if depth <= pass_width:
            plains_seeds.append(coord)
        else:
            hill_seeds.append(coord)
        used[key] = true
        for neighbor in grid.get_neighbor_coords(coord):
            var nkey := neighbor.to_vector2i()
            if used.has(nkey):
                continue
            if not land_lookup.has(nkey):
                continue
            if pass_lookup.has(nkey):
                continue
            if ridge_lookup.get(nkey, false):
                pass_neighbors.append(neighbor)

    pass_neighbors = _sort_coords_by_value(pass_neighbors, height_values, true)

    var mountain_seed_count: int = _estimate_seed_count(targets.get("mountains", 0), 10)
    var ridge_sorted: Array[HexCoord] = _sort_coords_by_value(ridge_coords, height_values, true)
    for coord in ridge_sorted:
        if mountain_seeds.size() >= mountain_seed_count:
            break
        var key: Vector2i = coord.to_vector2i()
        if used.has(key):
            continue
        if pass_lookup.has(key):
            continue
        mountain_seeds.append(coord)
        used[key] = true
    if mountain_seeds.size() < mountain_seed_count:
        for coord in sorted_high:
            if mountain_seeds.size() >= mountain_seed_count:
                break
            var key: Vector2i = coord.to_vector2i()
            if used.has(key):
                continue
            if pass_lookup.has(key):
                continue
            mountain_seeds.append(coord)
            used[key] = true

    var extra_seed_cap: int = min(3, max(0, mountain_seed_count >> 1))
    var extra_added: int = 0
    if extra_seed_cap > 0:
        for coord in sorted_high:
            if extra_added >= extra_seed_cap:
                break
            var key: Vector2i = coord.to_vector2i()
            if used.has(key):
                continue
            if pass_lookup.has(key):
                continue
            if ridge_lookup.get(key, false):
                continue
            if not _is_spacing_satisfied(coord, mountain_seeds, extra_spacing):
                continue
            mountain_seeds.append(coord)
            used[key] = true
            extra_added += 1
    seed_data["seeds"]["mountains"] = _coords_to_packed(mountain_seeds)

    var hill_seed_count: int = _estimate_seed_count(targets.get("hills", 0), 16)
    for neighbor in pass_neighbors:
        if hill_seed_count > 0 and hill_seeds.size() >= hill_seed_count:
            break
        var nkey: Vector2i = neighbor.to_vector2i()
        if used.has(nkey):
            continue
        hill_seeds.append(neighbor)
        used[nkey] = true
    for mountain in mountain_seeds:
        if hill_seed_count > 0 and hill_seeds.size() >= hill_seed_count:
            break
        var neighbors: Array[HexCoord] = grid.get_neighbor_coords(mountain)
        neighbors = _filter_land_coords(neighbors, land_lookup, used)
        neighbors = _sort_coords_by_value(neighbors, height_values, true)
        if neighbors.is_empty():
            continue
        var neighbor: HexCoord = neighbors[0]
        hill_seeds.append(neighbor)
        used[neighbor.to_vector2i()] = true
    if hill_seed_count == 0 and hill_seeds.is_empty() and not mountain_seeds.is_empty():
        var fallback_neighbors: Array[HexCoord] = grid.get_neighbor_coords(mountain_seeds[0])
        fallback_neighbors = _filter_land_coords(fallback_neighbors, land_lookup, used)
        if not fallback_neighbors.is_empty():
            var fallback_neighbor: HexCoord = fallback_neighbors[0]
            hill_seeds.append(fallback_neighbor)
            used[fallback_neighbor.to_vector2i()] = true
    if hill_seed_count > 0 and hill_seeds.size() < hill_seed_count:
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
    seed_data: Dictionary,
    ridge_plan: Dictionary
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
    var pass_lookup: Dictionary = ridge_plan.get("pass_lookup", {})
    var ridge_lookup: Dictionary = ridge_plan.get("ridge_lookup", {})

    for region_type in land_types:
        var packed: PackedVector2Array = seeds_dict.get(region_type, PackedVector2Array())
        for pos in packed:
            var key: Vector2i = Vector2i(pos)
            var coord: HexCoord = HexCoord.from_vector2i(key)
            if assignments.has(key):
                continue
            if region_type == "mountains" and pass_lookup.has(key):
                continue
            assignments[key] = region_type
            var final_type: String = region_type
            if region_type == "mountains":
                final_type = _ensure_mountain_buffer(coord, assignments, land_lookup, queue, region_counts)
            if final_type == "valley":
                valley_high_touch[key] = _valley_connected_to_high(coord, assignments, valley_high_touch)
            elif final_type == "lake":
                lake_touch[key] = _lake_has_valley_contact(coord, assignments, lake_touch, land_lookup)
            region_counts[final_type] = int(region_counts.get(final_type, 0)) + 1
            queue.append({
                "coord": coord,
                "type": final_type,
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
        if bool(current.get("forced", false)):
            continue
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
            if region_type == "mountains" and pass_lookup.has(key):
                continue
            if not _region_can_claim(region_type, neighbor, assignments, valley_high_touch, lake_touch, height_values, land_lookup):
                continue
            assignments[key] = region_type
            var final_type: String = region_type
            if region_type == "mountains":
                final_type = _ensure_mountain_buffer(neighbor, assignments, land_lookup, queue, region_counts)
            if final_type == "valley":
                valley_high_touch[key] = _valley_connected_to_high(neighbor, assignments, valley_high_touch)
            elif final_type == "lake":
                lake_touch[key] = _lake_has_valley_contact(neighbor, assignments, lake_touch, land_lookup)
            region_counts[final_type] = int(region_counts.get(final_type, 0)) + 1
            var entry := {
                "coord": neighbor,
                "type": final_type,
            }
            if final_type == "mountains" and ridge_lookup.get(key, false):
                queue.insert(queue_index, entry)
            else:
                queue.append(entry)

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

func _build_validation(
    assignments: Dictionary,
    land_lookup: Dictionary,
    height_map: Dictionary,
    coast_plan: Dictionary,
    ridge_plan: Dictionary
) -> Dictionary:
    var stray_lakes := PackedVector2Array()
    var isolated_sea_tiles := PackedVector2Array()
    var valleys_without_high := PackedVector2Array()
    var mountains_without_hills := PackedVector2Array()
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
        elif region_type == "mountains":
            if not _mountain_has_hill_neighbor(coord, assignments):
                mountains_without_hills.append(cell)
        elif region_type == "valley":
            if not _valley_has_direct_high(coord, assignments):
                valleys_without_high.append(cell)
    var sea_components: Array = _collect_sea_components(assignments)
    var component_sizes := PackedInt32Array()
    for component in sea_components:
        component_sizes.append(component.size())

    var selected_sides: PackedInt32Array = coast_plan.get("sides", PackedInt32Array())
    var membership: Dictionary = coast_plan.get("membership", {})
    var side_counts: Dictionary = coast_plan.get("side_counts", {})
    var valid_sides_lookup: Dictionary = {}
    for side_index in selected_sides:
        valid_sides_lookup[side_index] = true
    for key in membership.keys():
        var recorded_side: int = int(membership[key])
        assert(valid_sides_lookup.has(recorded_side))
    for side_index in selected_sides:
        assert(side_counts.has(side_index))
        var expected_size: int = int(side_counts.get(side_index, 0))
        var members: Array[Vector2i] = []
        for key in membership.keys():
            var recorded_side: int = int(membership[key])
            if recorded_side == side_index:
                members.append(key)
        assert(members.size() == expected_size)
        if expected_size > 0:
            assert(_side_members_connected(members))

    var pass_lookup: Dictionary = ridge_plan.get("pass_lookup", {})
    var pass_block_report: Dictionary = _collect_blocked_pass(pass_lookup, assignments)
    var blocked_pass_cells: PackedVector2Array = pass_block_report.get("blocked", PackedVector2Array())
    var pass_open: bool = bool(pass_block_report.get("pass_open", true))
    if not pass_open:
        assert(false, "blocked pass corridor")
    assert(mountains_without_hills.is_empty(), "mountain ridge missing hill buffer")
    return {
        "lakes_on_ridges": stray_lakes,
        "isolated_seas": isolated_sea_tiles,
        "valleys_without_high": valleys_without_high,
        "sea_component_sizes": component_sizes,
        "mountains_without_hills": mountains_without_hills,
        "blocked_pass": blocked_pass_cells,
    }

func _collect_sea_components(assignments: Dictionary) -> Array:
    var components: Array = []
    var visited: Dictionary = {}
    for key in assignments.keys():
        var region_type: String = String(assignments[key])
        if region_type != "sea":
            continue
        if visited.has(key):
            continue
        var component: Array[Vector2i] = []
        var stack: Array[Vector2i] = []
        stack.append(key)
        visited[key] = true
        while not stack.is_empty():
            var cell: Vector2i = stack.pop_back()
            component.append(cell)
            var coord: HexCoord = HexCoord.from_vector2i(cell)
            for neighbor in grid.get_neighbor_coords(coord):
                var nkey: Vector2i = neighbor.to_vector2i()
                if visited.has(nkey):
                    continue
                if String(assignments.get(nkey, "")) != "sea":
                    continue
                visited[nkey] = true
                stack.append(nkey)
        components.append(component)
    return components

func _side_members_connected(members: Array[Vector2i]) -> bool:
    if members.is_empty():
        return true
    var allowed: Dictionary = {}
    for cell in members:
        allowed[cell] = true
    var stack: Array[Vector2i] = []
    var start: Vector2i = members[0]
    stack.append(start)
    var visited: Dictionary = {}
    visited[start] = true
    while not stack.is_empty():
        var cell: Vector2i = stack.pop_back()
        var coord: HexCoord = HexCoord.from_vector2i(cell)
        for neighbor in grid.get_neighbor_coords(coord):
            var nkey: Vector2i = neighbor.to_vector2i()
            if not allowed.has(nkey):
                continue
            if visited.has(nkey):
                continue
            visited[nkey] = true
            stack.append(nkey)
    return visited.size() == allowed.size()

func _distance_to_side(coord: HexCoord, side_index: int) -> int:
    var wrapped_index: int = wrapi(side_index, 0, HexGrid.AXIAL_DIRECTIONS.size())
    var radius: int = grid.radius
    var q: int = coord.q
    var r: int = coord.r
    var s: int = -q - r
    match wrapped_index:
        0:
            return radius - q
        1:
            return r + radius
        2:
            return radius - s
        3:
            return q + radius
        4:
            return radius - r
        5:
            return s + radius
    return radius

func _is_spacing_satisfied(candidate: HexCoord, seeds: Array[HexCoord], spacing: int) -> bool:
    var minimum_spacing: int = max(1, spacing)
    for existing in seeds:
        if grid.axial_distance(candidate, existing) < minimum_spacing:
            return false
    return true

func _mountain_has_hill_neighbor(coord: HexCoord, assignments: Dictionary) -> bool:
    for neighbor in grid.get_neighbor_coords(coord):
        var key: Vector2i = neighbor.to_vector2i()
        if String(assignments.get(key, "")) == "hills":
            return true
    return false

func _ensure_mountain_buffer(
    coord: HexCoord,
    assignments: Dictionary,
    land_lookup: Dictionary,
    queue: Array[Dictionary],
    region_counts: Dictionary
) -> String:
    if _mountain_has_hill_neighbor(coord, assignments):
        return "mountains"
    for neighbor in grid.get_neighbor_coords(coord):
        var nkey: Vector2i = neighbor.to_vector2i()
        if not land_lookup.has(nkey):
            continue
        var neighbor_type: String = String(assignments.get(nkey, ""))
        if neighbor_type == "hills":
            return "mountains"
        if neighbor_type == "" or neighbor_type == "plains":
            assignments[nkey] = "hills"
            region_counts["hills"] = int(region_counts.get("hills", 0)) + 1
            queue.append({
                "coord": neighbor,
                "type": "hills",
                "forced": true,
            })
            return "mountains"
    var current_key: Vector2i = coord.to_vector2i()
    assignments[current_key] = "hills"
    region_counts["hills"] = int(region_counts.get("hills", 0)) + 1
    queue.append({
        "coord": coord,
        "type": "hills",
    })
    return "hills"

func _collect_blocked_pass(pass_lookup: Dictionary, assignments: Dictionary) -> Dictionary:
    var report: Dictionary = {
        "blocked": PackedVector2Array(),
        "pass_open": true,
    }
    if pass_lookup.size() == 0:
        return report
    var blocked := PackedVector2Array()
    var traversable_cells: int = 0
    for raw_key in pass_lookup.keys():
        var key: Vector2i = raw_key
        var region_type: String = String(assignments.get(key, ""))
        if region_type == "mountains":
            blocked.append(Vector2(key))
        elif region_type.is_empty():
            blocked.append(Vector2(key))
        else:
            traversable_cells += 1
    if traversable_cells <= 0:
        for raw_key in pass_lookup.keys():
            blocked.append(Vector2(raw_key))
        report["pass_open"] = false
    report["blocked"] = blocked
    return report

func _compare_dict_value_desc(a: Dictionary, b: Dictionary) -> bool:
    return a.get("value", 0.0) > b.get("value", 0.0)

func _compare_dict_value_asc(a: Dictionary, b: Dictionary) -> bool:
    return a.get("value", 0.0) < b.get("value", 0.0)

func _coord_noise(coord: HexCoord, salt: int = 0) -> float:
    var value: int = hash([coord.q, coord.r, salt, config.map_seed])
    value = abs(value)
    return float(value % 1000003) / 1000003.0

func _height_value(coord: HexCoord, ridge_plan: Dictionary) -> float:
    var key: Vector2i = coord.to_vector2i()
    var radius: int = max(1, grid.radius)
    var distance_to_center: float = float(grid.axial_distance(coord, HexCoord.new(0, 0))) / float(radius)
    var ridge_strength_lookup: Dictionary = ridge_plan.get("ridge_strength", {})
    var ridge_strength: float = float(ridge_strength_lookup.get(key, 0.0))
    var jitter_strength: float = clampf(config.side_jitter, 0.0, 1.0)
    var base_height: float = 0.25 + (0.65 * ridge_strength) - (distance_to_center * 0.2)
    var pass_lookup: Dictionary = ridge_plan.get("pass_lookup", {})
    if pass_lookup.has(key):
        var pass_width: float = float(max(1, int(ridge_plan.get("pass_width", config.ridge_pass_width))))
        var depth: float = float(pass_lookup.get(key, 0))
        var pass_factor: float = (1.0 - clampf(depth / (pass_width + 0.5), 0.0, 1.0)) * 0.6
        base_height -= pass_factor
    var ridge_noise := (_coord_noise(coord, 1307) - 0.5) * (0.35 + (jitter_strength * 0.35))
    var slope_noise := (_coord_noise(coord, 1871) - 0.5) * 0.2
    var height := base_height + ridge_noise + slope_noise
    return clampf(height, 0.0, 1.0)

func _build_height_map(coords: Array[HexCoord], ridge_plan: Dictionary) -> Dictionary:
    var values: Dictionary = {}
    for coord in coords:
        var key: Vector2i = coord.to_vector2i()
        values[key] = _height_value(coord, ridge_plan)
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
