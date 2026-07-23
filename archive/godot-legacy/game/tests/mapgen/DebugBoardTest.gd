extends RefCounted
class_name DebugBoardTestSuite

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const AssetCatalogScript := preload("res://mapgen/data/AssetCatalog.gd")
const TileScript := preload("res://mapgen/data/Tile.gd")

var _failures: Array[String] = []

func run() -> int:
    _failures.clear()
    _test_debug_board_is_deterministic()
    _test_debug_board_tile_layers_and_rotations()
    return _failures.size()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func _record_failure(message: String) -> void:
    _failures.append(message)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _record_failure(message)

func _test_debug_board_is_deterministic() -> void:
    var config := HexMapConfigScript.new(5150, 6, 4) as HexMapConfig
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var first: MapData = generator.generate_debug_board(2468)
    _check(first is MapData, "Debug board should return MapData instance.")
    if not (first is MapData):
        return
    var second: MapData = generator.generate_debug_board(2468)
    var first_serialized: Dictionary = first.to_dictionary()
    var second_serialized: Dictionary = second.to_dictionary()
    _check(first_serialized.hash() == second_serialized.hash(), "Debug board output should be deterministic for identical seeds.")

func _test_debug_board_tile_layers_and_rotations() -> void:
    var config := HexMapConfigScript.new(7777, 8, 8) as HexMapConfig
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var dataset: MapData = generator.generate_debug_board(9876)
    if not (dataset is MapData):
        _record_failure("Debug board should produce a valid MapData instance.")
        return
    var metadata: Dictionary = dataset.terrain_metadata.get("debug_board", {})
    if typeof(metadata) != TYPE_DICTIONARY:
        _record_failure("Debug board metadata should include section descriptors.")
        return
    var sections: Dictionary = metadata.get("sections", {})
    var combos: Dictionary = sections.get("terrain_combinations", {})
    var tiles_map: Dictionary = combos.get("tiles", {})
    var terrain_key: String = String(AssetCatalogScript.TERRAIN_MOUNTAINS)
    var variant_key: String = String(TileScript.VARIANT_C)
    var tree_key: String = "trees"
    var rotation_key: String = "5"
    var terrain_entry: Dictionary = tiles_map.get(terrain_key, {})
    var variant_entry: Dictionary = terrain_entry.get(variant_key, {})
    var tree_entry: Dictionary = variant_entry.get(tree_key, {})
    var axial: Variant = tree_entry.get(rotation_key, null)
    if typeof(axial) != TYPE_VECTOR2I:
        _record_failure("Metadata should provide coordinates for mountain variant C with trees at rotation 5.")
        return
    var tile: Tile = dataset.get_tile(axial)
    if not (tile is Tile):
        _record_failure("Expected to locate tile using metadata-provided axial coordinate.")
        return
    var catalog: AssetCatalog = dataset.asset_catalog
    _check(tile.terrain_type == AssetCatalogScript.TERRAIN_MOUNTAINS, "Tile terrain type should match metadata selection.")
    _check(tile.visual_variant == TileScript.VARIANT_C, "Tile variant should match metadata selection.")
    _check(tile.with_trees, "Tile metadata should reference a tree-enabled combination.")
    _check(tile.tile_rotation == 5, "Tile rotation should match metadata lookup value.")
    _check(tile.draw_stack.size() >= 4, "Mountain tile with trees should include base, ground, overlay, and decor layers.")
    if tile.draw_stack.size() < 4:
        return
    var base_layer: LayerInstance = tile.draw_stack[0]
    var terrain_layer: LayerInstance = tile.draw_stack[1]
    var overlay_layer: LayerInstance = tile.draw_stack[2]
    var decor_layer: LayerInstance = tile.draw_stack[3]
    _check(base_layer.asset_id == catalog.get_base_asset_id(), "First layer should match the catalog base asset id.")
    _check(catalog.get_role(terrain_layer.asset_id) == AssetCatalogScript.AssetRole.TERRAIN, "Second layer should use a terrain asset role.")
    _check(terrain_layer.rotation == 0, "Terrain base layer should not be rotated.")
    _check(overlay_layer.rotation == tile.tile_rotation, "Overlay layer rotation should follow the tile rotation.")
    _check(catalog.get_role(overlay_layer.asset_id) == AssetCatalogScript.AssetRole.TERRAIN, "Overlay layer should belong to the terrain asset role.")
    _check(decor_layer.rotation == tile.tile_rotation, "Decor layer rotation should align with tile rotation for rotatable assets.")
    _check(catalog.get_role(decor_layer.asset_id) == AssetCatalogScript.AssetRole.DECOR, "Final layer should use the decor asset role.")
