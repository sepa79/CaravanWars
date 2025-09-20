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
var map_data: HexMapData
var phase_handlers: Dictionary = {}

func _init(p_config: HexMapConfig = HexMapConfig.new()) -> void:
    config = p_config.duplicate_config()
    map_data = HexMapData.new(config)
    phase_handlers = {}

func generate() -> HexMapData:
    map_data.clear_stage_results()
    print("[HexMapGenerator] Stub generating map using seed %d (radius=%d, kingdoms=%d)" % [
        config.map_seed,
        config.map_radius,
        config.kingdom_count,
    ])
    for phase in PHASE_SEQUENCE:
        var handler: Callable = phase_handlers.get(phase, Callable())
        if handler.is_valid():
            var arg_count := _determine_handler_argument_count(handler)
            match arg_count:
                0:
                    handler.call()
                1:
                    handler.call(map_data)
                _:
                    handler.call(map_data, phase)
    return map_data

func set_phase_handler(phase: StringName, handler: Callable) -> void:
    if not PHASE_SEQUENCE.has(phase):
        push_warning("[HexMapGenerator] Unknown phase '%s'" % String(phase))
        return
    phase_handlers[phase] = handler

func get_phase_handler(phase: StringName) -> Callable:
    return phase_handlers.get(phase, Callable())

func clear_phase_handler(phase: StringName) -> void:
    phase_handlers.erase(phase)

func get_map_data() -> HexMapData:
    return map_data

func _determine_handler_argument_count(handler: Callable) -> int:
    var target := handler.get_object()
    var method_name := handler.get_method()
    if target == null or method_name.is_empty():
        return 2
    if not target.has_method(method_name):
        return 2
    var method_list: Array = target.get_method_list()
    for method_info in method_list:
        if typeof(method_info) != TYPE_DICTIONARY:
            continue
        if String(method_info.get("name", "")) != method_name:
            continue
        var args: Array = method_info.get("args", [])
        return args.size()
    return 2
