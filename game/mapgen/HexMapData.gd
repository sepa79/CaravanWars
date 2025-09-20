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
    _populate_stub_tiles()

func attach_grid(p_grid: HexGrid) -> void:
    hex_grid = p_grid

func prepare_for_generation():
    map_data = MapDataScript.new(_map_seed, map_width, map_height, asset_catalog)
    _apply_meta_to_map_data()
    _populate_stub_tiles()
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

func _populate_stub_tiles() -> void:
    if map_data == null:
        return
    map_data.clear_tiles()
    var terrains: Array[StringName] = [
        AssetCatalogScript.TERRAIN_SEA,
        AssetCatalogScript.TERRAIN_PLAINS,
        AssetCatalogScript.TERRAIN_HILLS,
        AssetCatalogScript.TERRAIN_MOUNTAINS,
    ]
    for index in terrains.size():
        var terrain_type: StringName = terrains[index]
        var q: int = index
        var r: int = 0
        var tile: Tile = _build_tile(q, r, terrain_type)
        map_data.set_tile(tile)
    map_data.set_dimensions(map_width, map_height)
    map_data.set_phase_payload(PHASE_TERRAIN, {"tiles": map_data.tiles.size()})

func _build_tile(q: int, r: int, terrain_type: StringName) -> Tile:
    var tile: Tile = TileScript.new(q, r)
    tile.terrain_type = terrain_type
    tile.height_value = _deterministic_height(q, r, terrain_type)
    tile.visual_variant = _deterministic_variant(q, r, terrain_type)
    tile.tile_rotation = _deterministic_rotation(q, r, terrain_type)
    tile.with_trees = _deterministic_with_trees(q, r, terrain_type, tile.visual_variant)
    _build_draw_stack(tile)
    return tile

func _build_draw_stack(tile: Tile) -> void:
    tile.clear_layers()
    var base_layer: LayerInstance = LayerInstanceScript.new(
        asset_catalog.get_base_asset_id(),
        0,
        _calculate_base_scale(tile.height_value),
        Vector2.ZERO
    )
    tile.add_layer(base_layer)
    var base_asset: StringName = asset_catalog.get_terrain_base_asset(tile.terrain_type)
    if base_asset != StringName():
        tile.add_layer(LayerInstanceScript.new(base_asset, 0, 1.0, Vector2.ZERO))
    var overlay_asset: StringName = asset_catalog.get_terrain_overlay_asset(tile.terrain_type, tile.visual_variant)
    if overlay_asset != StringName():
        var overlay_rotation: int = tile.tile_rotation
        var steps: int = asset_catalog.get_rotation_steps(overlay_asset)
        if steps <= 1:
            overlay_rotation = 0
        tile.add_layer(LayerInstanceScript.new(overlay_asset, overlay_rotation, 1.0, Vector2.ZERO))
    if tile.with_trees:
        var decor_asset: StringName = asset_catalog.get_terrain_decor_asset(tile.terrain_type, tile.visual_variant)
        if decor_asset != StringName():
            var decor_rotation: int = tile.tile_rotation
            var decor_steps: int = asset_catalog.get_rotation_steps(decor_asset)
            if decor_steps <= 1:
                decor_rotation = 0
            tile.add_layer(LayerInstanceScript.new(decor_asset, decor_rotation, 1.0, Vector2.ZERO))

func _calculate_base_scale(height_value: float) -> float:
    return 1.0 + BASE_SCALE_FACTOR * clampf(height_value, 0.0, 1.0)

func _deterministic_variant(q: int, r: int, terrain_type: StringName) -> StringName:
    var variants: Array[StringName] = asset_catalog.get_variants_for_terrain(terrain_type)
    if variants.is_empty():
        return TileScript.VARIANT_A
    var index: int = posmod(_hash_seed(q, r, terrain_type, "variant"), variants.size())
    return variants[index]

func _deterministic_rotation(q: int, r: int, terrain_type: StringName) -> int:
    var steps: int = asset_catalog.get_rotation_steps_for_terrain(terrain_type)
    if steps <= 1:
        return 0
    return posmod(_hash_seed(q, r, terrain_type, "rotation"), steps)

func _deterministic_with_trees(q: int, r: int, terrain_type: StringName, variant: StringName) -> bool:
    var decor_asset: StringName = asset_catalog.get_terrain_decor_asset(terrain_type, variant)
    if decor_asset == StringName():
        return false
    var value: int = posmod(_hash_seed(q, r, terrain_type, "trees"), 100)
    return value % 2 == 0

func _deterministic_height(q: int, r: int, terrain_type: StringName) -> float:
    var value: int = posmod(_hash_seed(q, r, terrain_type, "height"), 1000)
    var normalized: float = float(value) / 999.0
    return clampf(0.2 + normalized * 0.6, 0.0, 1.0)

func _hash_seed(q: int, r: int, terrain_type: StringName, label: String) -> int:
    var raw: int = int(hash([_map_seed, q, r, String(terrain_type), label]))
    if raw < 0:
        raw = -raw
    return raw
