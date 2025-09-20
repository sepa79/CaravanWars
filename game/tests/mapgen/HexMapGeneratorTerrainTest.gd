extends RefCounted
class_name HexMapGeneratorTerrainTestSuite

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const AssetCatalogScript := preload("res://mapgen/data/AssetCatalog.gd")
const HexMapDataScript := preload("res://mapgen/HexMapData.gd")

var _failures: Array[String] = []

func run() -> int:
    _failures.clear()
    _test_generator_builds_tiles()
    _test_generator_is_deterministic()
    _test_phase_handlers_receive_map_data()
    return _failures.size()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func _record_failure(message: String) -> void:
    _failures.append(message)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _record_failure(message)

func _test_generator_builds_tiles() -> void:
    var config := HexMapConfigScript.new(4242, 8, 6) as HexMapConfig
    config.set_edge_setting("north", "sea", 2)
    config.set_edge_setting("west", "sea", 2)
    config.update_random_feature_setting("intensity", "medium")
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var data: MapData = generator.generate()
    _check(data is MapData, "Generator should return MapData instance.")
    if not (data is MapData):
        return
    var width: int = config.map_width
    var height: int = config.map_height
    var expected_tiles: int = width * height
    _check(data.tiles.size() == expected_tiles, "Generator should populate every tile in the rectangle.")
    var sample_tile: Tile = data.get_tile_at(0, 0)
    _check(sample_tile is Tile, "Corner tile should exist in generated data.")
    if sample_tile is Tile:
        var typed_tile := sample_tile as Tile
        _check(typed_tile.draw_stack.size() >= 2, "Tile draw stack should contain base and terrain layers.")
        if typed_tile.draw_stack.size() >= 2:
            var base_layer: LayerInstance = typed_tile.draw_stack[0]
            var catalog: AssetCatalog = data.asset_catalog
            _check(base_layer.asset_id == catalog.get_base_asset_id(), "First layer should use the catalog base asset.")
            var expected_scale: float = 1.0 + HexMapDataScript.BASE_SCALE_FACTOR * typed_tile.height_value
            _check(is_equal_approx(base_layer.scale, expected_scale), "Base layer scale should match visual height bias.")
            var terrain_layer: LayerInstance = typed_tile.draw_stack[1]
            _check(catalog.get_role(terrain_layer.asset_id) == AssetCatalogScript.AssetRole.TERRAIN, "Second layer should use a terrain asset.")

func _test_generator_is_deterministic() -> void:
    var config_a := HexMapConfigScript.new(1111, 7, 5) as HexMapConfig
    config_a.set_edge_setting("south", "plains", 1)
    config_a.update_random_feature_setting("intensity", "high")
    var generator_a: HexMapGenerator = HexMapGeneratorScript.new(config_a)
    var first: Dictionary = generator_a.generate().to_dictionary()
    var generator_b: HexMapGenerator = HexMapGeneratorScript.new(config_a.duplicate_config())
    var second: Dictionary = generator_b.generate().to_dictionary()
    _check(first.hash() == second.hash(), "Serialised maps should match for identical seeds and config.")

func _test_phase_handlers_receive_map_data() -> void:
    var config := HexMapConfigScript.new(3333, 6, 4) as HexMapConfig
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var invoked := [false]
    var handler := func(map_data: MapData, phase: StringName) -> void:
        invoked[0] = true
        map_data.set_phase_payload(phase, {"custom": true})
    _check(handler.is_valid(), "Custom handler should produce a valid callable.")
    generator.set_phase_handler(HexMapGeneratorScript.PHASE_TERRAIN, handler)
    var data: MapData = generator.generate()
    _check(invoked[0], "Custom terrain phase handler should be invoked after the built-in pipeline.")
    var stored: Variant = data.get_phase_payload(HexMapGeneratorScript.PHASE_TERRAIN)
    if typeof(stored) == TYPE_DICTIONARY:
        _check(bool(stored.get("custom", false)), "Phase payload should include custom marker from handler.")
    else:
        _record_failure("Phase handler did not update the expected payload dictionary.")
