extends RefCounted
class_name HexMapData

const AssetCatalogScript: GDScript = preload("res://mapgen/data/AssetCatalog.gd")
const LayerInstanceScript: GDScript = preload("res://mapgen/data/LayerInstance.gd")
const MapDataScript: GDScript = preload("res://mapgen/data/MapData.gd")
const TileScript: GDScript = preload("res://mapgen/data/Tile.gd")

const PHASE_TERRAIN := StringName("terrain")
const BASE_SCALE_FACTOR := 0.3

var map_seed: int:
    set(value):
        _map_seed = value
        if map_data != null:
            map_data.map_seed = value
    get:
        return _map_seed
var map_width: int
var map_height: int
var kingdom_count: int
var rivers_cap: int
var road_aggressiveness: float
var fort_global_cap: int
var fort_spacing: int
var edge_settings: Dictionary = {}
var edge_jitter: int
var random_feature_settings: Dictionary = {}
var terrain_settings
var hex_grid: HexGrid
var asset_catalog: AssetCatalog
var map_data: MapData

var _map_seed: int = 0

func _init(p_config: HexMapConfig) -> void:
    _map_seed = p_config.map_seed
    map_width = max(1, p_config.map_width)
    map_height = max(1, p_config.map_height)
    kingdom_count = p_config.kingdom_count
    rivers_cap = p_config.rivers_cap
    road_aggressiveness = p_config.road_aggressiveness
    fort_global_cap = p_config.fort_global_cap
    fort_spacing = p_config.fort_spacing
    edge_settings = p_config.get_all_edge_settings().duplicate(true)
    edge_jitter = p_config.edge_jitter
    random_feature_settings = p_config.get_random_feature_settings()
    terrain_settings = p_config.terrain_settings.duplicate_settings()
    asset_catalog = AssetCatalogScript.new()
    map_data = MapDataScript.new(_map_seed, map_width, map_height, asset_catalog)
    _apply_meta_to_map_data()

func attach_grid(p_grid: HexGrid) -> void:
    hex_grid = p_grid

func prepare_for_generation():
    map_data = MapDataScript.new(_map_seed, map_width, map_height, asset_catalog)
    _apply_meta_to_map_data()
    clear_tiles()
    return map_data

func set_stage_result(phase: StringName, data: Variant) -> void:
    if map_data == null:
        return
    map_data.set_phase_payload(phase, data)

func get_stage_result(phase: StringName) -> Variant:
    if map_data == null:
        return null
    return map_data.get_phase_payload(phase)

func clear_stage_results() -> void:
    if map_data == null:
        return
    map_data.clear_phase_payloads()

func set_phase_payload(phase: StringName, data: Variant) -> void:
    set_stage_result(phase, data)

func get_phase_payload(phase: StringName) -> Variant:
    return get_stage_result(phase)

func get_map_data() -> MapData:
    return map_data

func to_dictionary() -> Dictionary:
    if map_data == null:
        return {}
    return map_data.to_dictionary()

func _apply_meta_to_map_data() -> void:
    if map_data == null:
        return
    map_data.map_seed = _map_seed
    map_data.set_catalog(asset_catalog)
    map_data.set_dimensions(map_width, map_height)
    map_data.apply_meta(_build_meta_dictionary())
    if terrain_settings != null and terrain_settings.has_method("to_dictionary"):
        map_data.set_terrain_settings(terrain_settings.to_dictionary())
    else:
        map_data.set_terrain_settings({})
    map_data.set_terrain_metadata({})
    map_data.clear_phase_payloads()

func _build_meta_dictionary() -> Dictionary:
    return {
        "seed": _map_seed,
        "width": map_width,
        "height": map_height,
        "kingdom_count": kingdom_count,
        "params": {
            "rivers_cap": rivers_cap,
            "road_aggressiveness": road_aggressiveness,
            "fort_global_cap": fort_global_cap,
            "fort_spacing": fort_spacing,
            "edge_settings": edge_settings.duplicate(true),
            "edge_jitter": edge_jitter,
            "random_features": random_feature_settings.duplicate(true),
        },
    }

func clear_tiles() -> void:
    if map_data == null:
        return
    map_data.clear_tiles()

func create_tile(
    q: int,
    r: int,
    terrain_type: StringName,
    height_value: float,
    rotation: int,
    variant: StringName,
    with_trees: bool
) -> Tile:
    var tile: Tile = TileScript.new(q, r)
    tile.terrain_type = terrain_type
    tile.height_value = clampf(height_value, 0.0, 1.0)
    tile.tile_rotation = rotation
    tile.visual_variant = variant
    tile.with_trees = with_trees
    build_draw_stack(tile)
    return tile

func build_draw_stack(tile: Tile) -> void:
    if tile == null:
        return
    tile.clear_layers()
    var base_asset_id: StringName = asset_catalog.get_base_asset_id()
    tile.add_layer(
        LayerInstanceScript.new(
            base_asset_id,
            0,
            _calculate_base_scale(tile.height_value),
            Vector2.ZERO
        )
    )
    var base_asset: StringName = asset_catalog.get_terrain_base_asset(tile.terrain_type)
    if base_asset != StringName():
        tile.add_layer(LayerInstanceScript.new(base_asset, 0, 1.0, Vector2.ZERO))
    var overlay_asset: StringName = asset_catalog.get_terrain_overlay_asset(tile.terrain_type, tile.visual_variant)
    var decor_asset: StringName = StringName()
    if tile.with_trees:
        decor_asset = asset_catalog.get_terrain_decor_asset(tile.terrain_type, tile.visual_variant)
    # For hills and mountains, use a single combined mesh when trees are enabled.
    if tile.terrain_type == AssetCatalogScript.TERRAIN_HILLS or tile.terrain_type == AssetCatalogScript.TERRAIN_MOUNTAINS:
        if tile.with_trees and decor_asset != StringName():
            overlay_asset = decor_asset
            decor_asset = StringName()
    if overlay_asset != StringName():
        var overlay_rotation: int = tile.tile_rotation
        var steps: int = asset_catalog.get_rotation_steps(overlay_asset)
        if steps <= 1:
            overlay_rotation = 0
        tile.add_layer(LayerInstanceScript.new(overlay_asset, overlay_rotation, 1.0, Vector2.ZERO))
    if decor_asset != StringName():
        var decor_rotation: int = tile.tile_rotation
        var decor_steps: int = asset_catalog.get_rotation_steps(decor_asset)
        if decor_steps <= 1:
            decor_rotation = 0
        tile.add_layer(LayerInstanceScript.new(decor_asset, decor_rotation, 1.0, Vector2.ZERO))

func store_tile(tile: Tile) -> void:
    if map_data == null or tile == null:
        return
    map_data.set_tile(tile)

func _calculate_base_scale(height_value: float) -> float:
    return 1.0 + BASE_SCALE_FACTOR * clampf(height_value, 0.0, 1.0)
