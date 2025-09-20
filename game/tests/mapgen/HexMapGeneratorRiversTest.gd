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
    var data: HexMapData = generator.generate()
    _check(data is HexMapData, "Generator stub should return HexMapData.")
    if data is HexMapData:
        _check((data as HexMapData).map_seed == 424242, "Returned map data should preserve the configured seed.")

func _test_phase_handlers_receive_map_data() -> void:
    var generator: HexMapGenerator = HexMapGeneratorScript.new(HexMapConfigScript.new() as HexMapConfig)
    var invoked: bool = false
    var handler := func(map_data: HexMapData, phase: StringName) -> void:
        invoked = true
        map_data.set_stage_result(phase, {"called": true})
    generator.set_phase_handler(HexMapGeneratorScript.PHASE_TERRAIN, handler)
    var data: HexMapData = generator.generate()
    _check(invoked, "Custom phase handler should be invoked by the stub pipeline.")
    var stored: Variant = data.get_stage_result(HexMapGeneratorScript.PHASE_TERRAIN)
    if typeof(stored) == TYPE_DICTIONARY:
        _check(bool(stored.get("called", false)), "Phase handler should be able to write to map data stage results.")
    else:
        _record_failure("Phase handler did not update the expected stage result payload.")
