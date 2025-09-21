extends RefCounted
class_name HexMapGenerator

const PHASE_TERRAIN := StringName("terrain")
const PHASE_RIVERS := StringName("rivers")
const PHASE_BIOMES := StringName("biomes")
const PHASE_BORDERS := StringName("borders")
const PHASE_SETTLEMENTS := StringName("settlements")
const PHASE_ROADS := StringName("roads")
const PHASE_FORTS := StringName("forts")

const MAP_DATA_SCRIPT := preload("res://mapgen/data/MapData.gd")
const TerrainPhaseScript := preload("res://mapgen/phase1/TerrainPhase.gd")
const DebugBoardScript := preload("res://mapgen/phase1/DebugBoard.gd")

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
var data_builder: HexMapData
var phase_handlers: Dictionary = {}
var _builtin_handlers: Dictionary = {}
var _terrain_phase: RefCounted
var debug_board_enabled: bool = false

var _debug_board_builder: RefCounted
var _debug_board_seed_override: int = 0

func _init(p_config: HexMapConfig = HexMapConfig.new()) -> void:
    config = p_config.duplicate_config()
    data_builder = HexMapData.new(config)
    phase_handlers = {}
    _builtin_handlers = {}
    if MAP_DATA_SCRIPT == null:
        push_warning("[HexMapGenerator] Unable to preload MapData script")
    if TerrainPhaseScript != null:
        _terrain_phase = TerrainPhaseScript.new(config, data_builder)
        _builtin_handlers[PHASE_TERRAIN] = Callable(_terrain_phase, "run")
    if DebugBoardScript != null:
        _debug_board_builder = DebugBoardScript.new(config, data_builder)

func generate() -> MapData:
    if debug_board_enabled and _debug_board_builder != null:
        return _debug_board_builder.build(_get_debug_board_seed())
    var dataset: MapData = data_builder.prepare_for_generation()
    print("[HexMapGenerator] Generating map using seed %d (size=%dx%d, kingdoms=%d)" % [
        dataset.map_seed,
        config.map_width,
        config.map_height,
        config.kingdom_count,
    ])
    for phase in PHASE_SEQUENCE:
        var builtin_handler: Callable = _builtin_handlers.get(phase, Callable())
        if builtin_handler != Callable():
            _invoke_handler(builtin_handler, dataset, phase)
        var handler: Callable = phase_handlers.get(phase, Callable())
        if handler != Callable():
            _invoke_handler(handler, dataset, phase)
    return dataset

func set_phase_handler(phase: StringName, handler: Callable) -> void:
    if not PHASE_SEQUENCE.has(phase):
        push_warning("[HexMapGenerator] Unknown phase '%s'" % String(phase))
        return
    phase_handlers[phase] = handler

func get_phase_handler(phase: StringName) -> Callable:
    return phase_handlers.get(phase, Callable())

func clear_phase_handler(phase: StringName) -> void:
    phase_handlers.erase(phase)

func get_map_data() -> MapData:
    return data_builder.get_map_data()

func set_debug_board_enabled(enabled: bool, seed: int = 0) -> void:
    debug_board_enabled = enabled
    if seed != 0:
        _debug_board_seed_override = seed

func is_debug_board_enabled() -> bool:
    return debug_board_enabled

func set_debug_board_seed(seed: int) -> void:
    _debug_board_seed_override = seed

func get_debug_board_seed() -> int:
    return _get_debug_board_seed()

func generate_debug_board(seed: int = 0) -> MapData:
    if _debug_board_builder == null:
        push_warning("[HexMapGenerator] Debug board script unavailable, returning empty map data")
        return data_builder.prepare_for_generation()
    var target_seed: int = seed if seed != 0 else _get_debug_board_seed()
    return _debug_board_builder.build(target_seed)

func _invoke_handler(handler: Callable, dataset: MapData, phase: StringName) -> void:
    var arg_count := _determine_handler_argument_count(handler)
    match arg_count:
        0:
            handler.call()
        1:
            handler.call(dataset)
        _:
            handler.call(dataset, phase)

func _get_debug_board_seed() -> int:
    if _debug_board_seed_override != 0:
        return _debug_board_seed_override
    return config.map_seed

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
