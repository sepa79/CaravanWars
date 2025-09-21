extends RefCounted
class_name DebugBoard

const AssetCatalogScript: GDScript = preload("res://mapgen/data/AssetCatalog.gd")
const MapDataScript: GDScript = preload("res://mapgen/data/MapData.gd")
const TileScript: GDScript = preload("res://mapgen/data/Tile.gd")
const HexMapConfigScript: GDScript = preload("res://mapgen/HexMapConfig.gd")

var config: HexMapConfig
var data_builder: HexMapData

func _init(p_config: HexMapConfig, p_data_builder: HexMapData) -> void:
    config = p_config
    data_builder = p_data_builder

func build(seed: int) -> MapData:
    var catalog: AssetCatalog = data_builder.asset_catalog
    if catalog == null:
        catalog = AssetCatalogScript.new()
    var final_seed: int = seed if seed != 0 else config.map_seed
    var terrains: Array[StringName] = AssetCatalogScript.ALL_TERRAINS.duplicate()
    var variants: Array[StringName] = TileScript.ALL_VARIANTS.duplicate()
    var tree_states: Array[bool] = [false, true]
    var max_rotations: int = 1
    for terrain in terrains:
        max_rotations = max(max_rotations, catalog.get_rotation_steps_for_terrain(terrain))
    var combos_width: int = variants.size() * tree_states.size() * max_rotations
    var edge_samples: Array[int] = _collect_edge_width_samples()
    if edge_samples.is_empty():
        edge_samples = [0]
    var edges_width: int = edge_samples.size()
    var feature_modes: Array[String] = HexMapConfigScript.FEATURE_MODES.duplicate()
    var feature_intensities: Array[String] = HexMapConfigScript.FEATURE_INTENSITIES.duplicate()
    var feature_falloffs: Array[String] = HexMapConfigScript.FEATURE_FALLOFFS.duplicate()
    var feature_width: int = feature_modes.size()
    var combos_rows: int = terrains.size()
    var edge_rows: int = HexMapConfigScript.EDGE_NAMES.size()
    var feature_rows: int = feature_intensities.size() * feature_falloffs.size()
    var total_width: int = max(combos_width, max(edges_width, feature_width))
    var total_height: int = combos_rows + edge_rows + feature_rows + 2
    var map_data: MapData = MapDataScript.new(final_seed, total_width, total_height, catalog)
    map_data.set_dimensions(total_width, total_height)
    map_data.apply_meta({
        "seed": final_seed,
        "width": total_width,
        "height": total_height,
        "debug_board": true,
    })
    map_data.set_terrain_settings({})
    var combos_origin: Vector2i = Vector2i(0, 0)
    var edges_origin: Vector2i = Vector2i(0, combos_rows + 1)
    var features_origin: Vector2i = Vector2i(0, edges_origin.y + edge_rows + 1)
    var tree_keys: Array[String] = ["bare", "trees"]
    var combos_metadata: Dictionary = {}
    for terrain_index in range(terrains.size()):
        var terrain: StringName = terrains[terrain_index]
        var terrain_key: String = String(terrain)
        var variant_map: Dictionary = {}
        for variant_index in range(variants.size()):
            var variant: StringName = variants[variant_index]
            var variant_key: String = String(variant)
            var tree_map: Dictionary = {}
            for tree_index in range(tree_states.size()):
                var with_trees: bool = tree_states[tree_index]
                var tree_key: String = tree_keys[tree_index]
                var rotation_map: Dictionary = {}
                var rotation_steps: int = max(1, catalog.get_rotation_steps_for_terrain(terrain))
                for rotation in range(rotation_steps):
                    var column_base: int = variant_index * tree_states.size() * max_rotations
                    column_base += tree_index * max_rotations
                    var q: int = column_base + rotation
                    var r: int = combos_origin.y + terrain_index
                    var height_value: float = _sample_height_value(terrain_index, tree_index, rotation, max_rotations)
                    var tile: Tile = _create_tile(q, r, terrain, variant, rotation, with_trees, height_value)
                    map_data.set_tile(tile)
                    rotation_map[str(rotation)] = tile.axial()
                tree_map[tree_key] = rotation_map
            variant_map[variant_key] = tree_map
        combos_metadata[terrain_key] = variant_map
    var edge_metadata: Dictionary = {
        "origin": edges_origin,
        "size": Vector2i(edges_width, edge_rows),
        "edge_names": HexMapConfigScript.EDGE_NAMES.duplicate(),
        "width_samples": edge_samples.duplicate(),
        "tiles": {},
    }
    for edge_index in range(HexMapConfigScript.EDGE_NAMES.size()):
        var edge_name: String = HexMapConfigScript.EDGE_NAMES[edge_index]
        var row: int = edges_origin.y + edge_index
        var per_edge: Dictionary = {}
        for width_index in range(edge_samples.size()):
            var width_value: int = edge_samples[width_index]
            var q_edge: int = width_index
            var config_entry: Dictionary = config.get_edge_setting(edge_name)
            var terrain_type: StringName = _edge_type_to_terrain(String(config_entry.get("type", HexMapConfigScript.DEFAULT_EDGE_TYPE)))
            var rotation_value: int = width_index % max_rotations
            var tile_edge: Tile = _create_tile(
                q_edge,
                row,
                terrain_type,
                variants[edge_index % variants.size()],
                rotation_value,
                (width_value % 2) == 1,
                _edge_width_to_height(width_value)
            )
            map_data.set_tile(tile_edge)
            per_edge[str(width_value)] = tile_edge.axial()
        edge_metadata["tiles"][edge_name] = per_edge
    var feature_metadata: Dictionary = {
        "origin": features_origin,
        "size": Vector2i(feature_width, feature_rows),
        "modes": feature_modes.duplicate(),
        "intensities": feature_intensities.duplicate(),
        "falloffs": feature_falloffs.duplicate(),
        "tiles": {},
    }
    for falloff_index in range(feature_falloffs.size()):
        var falloff: String = feature_falloffs[falloff_index]
        var falloff_map: Dictionary = {}
        for intensity_index in range(feature_intensities.size()):
            var intensity: String = feature_intensities[intensity_index]
            var mode_map: Dictionary = {}
            for mode_index in range(feature_modes.size()):
                var mode: String = feature_modes[mode_index]
                var q_feature: int = mode_index
                var r_feature: int = features_origin.y + falloff_index * feature_intensities.size() + intensity_index
                var tile_feature: Tile = _create_tile(
                    q_feature,
                    r_feature,
                    AssetCatalogScript.TERRAIN_HILLS,
                    _mode_to_variant(mode),
                    _falloff_rotation(falloff_index, intensity_index, max_rotations),
                    intensity != HexMapConfigScript.DEFAULT_FEATURE_INTENSITY,
                    _intensity_height(intensity)
                )
                map_data.set_tile(tile_feature)
                mode_map[mode] = tile_feature.axial()
            falloff_map[intensity] = mode_map
        feature_metadata["tiles"][falloff] = falloff_map
    map_data.set_terrain_metadata({
        "debug_board": {
            "seed": final_seed,
            "dimensions": Vector2i(total_width, total_height),
            "sections": {
                "terrain_combinations": {
                    "origin": combos_origin,
                    "size": Vector2i(combos_width, combos_rows),
                    "max_rotations": max_rotations,
                    "tree_states": tree_keys,
                    "tiles": combos_metadata,
                },
                "edge_widths": edge_metadata,
                "feature_intensity_modes": feature_metadata,
            },
        }
    })
    return map_data

func _create_tile(
    q: int,
    r: int,
    terrain: StringName,
    variant: StringName,
    rotation: int,
    with_trees: bool,
    height_value: float
) -> Tile:
    var tile: Tile = TileScript.new(q, r)
    tile.terrain_type = terrain
    tile.visual_variant = variant
    tile.tile_rotation = rotation
    tile.with_trees = with_trees
    tile.height_value = clampf(height_value, 0.0, 1.0)
    data_builder.build_draw_stack(tile)
    return tile

func _sample_height_value(terrain_index: int, tree_index: int, rotation: int, max_rotations: int) -> float:
    var base_value: float = 0.15 + 0.18 * float(terrain_index)
    var tree_bias: float = 0.05 * float(tree_index)
    var rotation_step: float = 0.6 / float(max(1, max_rotations))
    return base_value + tree_bias + rotation_step * float(rotation)

func _collect_edge_width_samples() -> Array[int]:
    var samples: Array[int] = [0, 1, 2, 3, 4]
    for edge_name in HexMapConfigScript.EDGE_NAMES:
        var entry: Dictionary = config.get_edge_setting(edge_name)
        var width_value: int = int(entry.get("width", HexMapConfigScript.DEFAULT_EDGE_WIDTH))
        if not samples.has(width_value):
            samples.append(width_value)
    samples.sort()
    return samples

func _edge_type_to_terrain(edge_type: String) -> StringName:
    var normalized: String = edge_type.strip_edges().to_upper()
    match normalized:
        "SEA":
            return AssetCatalogScript.TERRAIN_SEA
        "HILLS":
            return AssetCatalogScript.TERRAIN_HILLS
        "MOUNTAINS":
            return AssetCatalogScript.TERRAIN_MOUNTAINS
        "PLAINS":
            return AssetCatalogScript.TERRAIN_PLAINS
    return AssetCatalogScript.TERRAIN_PLAINS

func _edge_width_to_height(width_value: int) -> float:
    return clampf(float(width_value) * 0.2, 0.0, 1.0)

func _mode_to_variant(mode: String) -> StringName:
    match mode:
        "auto":
            return TileScript.VARIANT_A
        "peaks_only":
            return TileScript.VARIANT_B
        "hills_only":
            return TileScript.VARIANT_C
    return TileScript.VARIANT_A

func _intensity_height(intensity: String) -> float:
    match intensity:
        "none":
            return 0.05
        "low":
            return 0.35
        "medium":
            return 0.65
        "high":
            return 0.9
    return 0.35

func _falloff_rotation(
    falloff_index: int,
    intensity_index: int,
    max_rotations: int
) -> int:
    if max_rotations <= 1:
        return 0
    var combined_index: int = falloff_index * HexMapConfigScript.FEATURE_INTENSITIES.size() + intensity_index
    return combined_index % max_rotations
