extends RefCounted
class_name Phase1TerrainPipelineTestSuite

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const AssetCatalogScript := preload("res://mapgen/data/AssetCatalog.gd")
const TileScript := preload("res://mapgen/data/Tile.gd")
const HexMapDataScript := preload("res://mapgen/HexMapData.gd")

var _failures: Array[String] = []

func run() -> int:
    _failures.clear()
    _test_draw_stack_layers_are_ordered()
    _test_rotations_variants_and_trees_consistency()
    return _failures.size()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func _record_failure(message: String) -> void:
    _failures.append(message)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _record_failure(message)

func _test_draw_stack_layers_are_ordered() -> void:
    var config := HexMapConfigScript.new(9090, 12, 8) as HexMapConfig
    config.set_edge_setting("north", "sea", 2)
    config.set_edge_setting("south", "plains", 2)
    config.set_edge_setting("west", "mountains", 2)
    config.update_random_feature_setting("intensity", "medium")
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var data: MapData = generator.generate()
    var catalog: AssetCatalog = data.asset_catalog
    var sea_tile: Tile = null
    var tree_tile: Tile = null
    for tile in data.get_tiles():
        _check(tile.draw_stack.size() >= 2, "Every tile should include base and terrain layers.")
        if sea_tile == null and tile.terrain_type == AssetCatalogScript.TERRAIN_SEA:
            sea_tile = tile
        if tree_tile == null and tile.with_trees:
            tree_tile = tile
    if sea_tile != null:
        _assert_base_layer(sea_tile, catalog)
    else:
        _record_failure("Expected at least one sea tile for edge shaping test.")
    if tree_tile != null:
        _assert_tree_layer(tree_tile, catalog)
    else:
        _record_failure("Expected at least one tile with trees for decor validation.")

func _test_rotations_variants_and_trees_consistency() -> void:
    var config := HexMapConfigScript.new(2024, 10, 9) as HexMapConfig
    config.update_random_feature_setting("intensity", "high")
    config.update_random_feature_setting("mode", "auto")
    config.update_random_feature_setting("falloff", "smooth")
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var data: MapData = generator.generate()
    var catalog: AssetCatalog = data.asset_catalog
    var rotatable_tile: Tile = null
    for tile in data.get_tiles():
        var steps: int = catalog.get_rotation_steps_for_terrain(tile.terrain_type)
        if steps > 1:
            rotatable_tile = tile
            break
    if rotatable_tile == null:
        _record_failure("Expected to locate at least one rotatable terrain tile.")
        return
    _assert_base_layer(rotatable_tile, catalog)
    var variants: Array[StringName] = catalog.get_variants_for_terrain(rotatable_tile.terrain_type)
    _check(variants.has(rotatable_tile.visual_variant), "Tile variant should be selected from catalog-defined options.")
    var steps: int = catalog.get_rotation_steps_for_terrain(rotatable_tile.terrain_type)
    _check(rotatable_tile.tile_rotation >= 0 and rotatable_tile.tile_rotation < max(1, steps), "Tile rotation should respect terrain rotation steps.")
    if rotatable_tile.draw_stack.size() >= 3:
        var overlay_layer: LayerInstance = rotatable_tile.draw_stack[2]
        if steps > 1:
            _check(overlay_layer.rotation == rotatable_tile.tile_rotation, "Overlay layer rotation should match tile rotation for rotatable terrains.")
        _check(catalog.get_role(overlay_layer.asset_id) == AssetCatalogScript.AssetRole.TERRAIN, "Overlay layer should use a terrain asset role.")
    if rotatable_tile.with_trees:
        _assert_tree_layer(rotatable_tile, catalog)

func _assert_base_layer(tile: Tile, catalog: AssetCatalog) -> void:
    if tile.draw_stack.is_empty():
        _record_failure("Tile draw stack should not be empty.")
        return
    var base_layer: LayerInstance = tile.draw_stack[0]
    _check(base_layer.asset_id == catalog.get_base_asset_id(), "Base layer asset should match catalog base asset id.")
    var expected_scale: float = 1.0 + HexMapDataScript.BASE_SCALE_FACTOR * tile.height_value
    _check(is_equal_approx(base_layer.scale, expected_scale), "Base layer scale should reflect visual height value.")

func _assert_tree_layer(tile: Tile, catalog: AssetCatalog) -> void:
    if tile.draw_stack.is_empty():
        _record_failure("Tree tile should include draw layers.")
        return
    var last_layer: LayerInstance = tile.draw_stack[tile.draw_stack.size() - 1]
    _check(catalog.get_role(last_layer.asset_id) == AssetCatalogScript.AssetRole.DECOR, "Decor layer should use DECOR asset role.")
