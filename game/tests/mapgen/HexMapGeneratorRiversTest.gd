extends RefCounted
class_name HexMapGeneratorRiversTestSuite

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")

var _failures: Array[String] = []

func run() -> int:
    _failures.clear()
    _test_generator_uses_config_seed()
    _test_phase_handlers_receive_map_data()
    return _failures.size()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func _record_failure(message: String) -> void:
    _failures.append(message)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _record_failure(message)

func _test_generator_uses_config_seed() -> void:
    var config := HexMapConfigScript.new() as HexMapConfig
    config.map_seed = 424242
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    var data: MapData = generator.generate()
    _check(data is MapData, "Generator stub should return MapData.")
    if data is MapData:
        var typed := data as MapData
        _check(typed.seed == 424242, "Returned map data should preserve the configured seed.")
        var tiles := typed.get_tiles()
        _check(tiles.size() > 0, "Stub map should include at least one tile.")
        if tiles.size() > 0:
            var tile := tiles[0]
            _check(tile.draw_stack.size() >= 2, "Tile should include layered draw stack for rendering.")
            if tile.draw_stack.size() > 0:
                var base_layer := tile.draw_stack[0]
                _check(base_layer.asset_id == typed.asset_catalog.get_base_asset_id(), "First draw layer should use the base terrain asset.")
                var base_scene_path := typed.asset_catalog.get_asset_path(base_layer.asset_id)
                _check(not base_scene_path.is_empty(), "Base terrain asset should resolve to a scene path.")

func _test_phase_handlers_receive_map_data() -> void:
    var generator: HexMapGenerator = HexMapGeneratorScript.new(HexMapConfigScript.new() as HexMapConfig)
    var invoked: bool = false
    var handler := func(map_data: MapData, phase: StringName) -> void:
        invoked = true
        map_data.set_phase_payload(phase, {"called": true})
    generator.set_phase_handler(HexMapGeneratorScript.PHASE_TERRAIN, handler)
    var data: MapData = generator.generate()
    _check(invoked, "Custom phase handler should be invoked by the stub pipeline.")
    var stored: Variant = data.get_phase_payload(HexMapGeneratorScript.PHASE_TERRAIN)
    if typeof(stored) == TYPE_DICTIONARY:
        _check(bool(stored.get("called", false)), "Phase handler should be able to write to map data payloads.")
    else:
        _record_failure("Phase handler did not update the expected phase payload.")
