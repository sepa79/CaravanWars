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
var rng := RandomNumberGenerator.new()
var grid: HexGrid
var map_data: HexMapData
var phase_handlers: Dictionary = {}

var terrain_state: Dictionary = {}
var rivers_state: Dictionary = {}
var biomes_state: Dictionary = {}
var borders_state: Dictionary = {}
var settlements_state: Dictionary = {}
var roads_state: Dictionary = {}
var forts_state: Dictionary = {}

func _init(p_config: HexMapConfig = HexMapConfig.new()) -> void:
    config = p_config.duplicate_config()
    rng.seed = config.seed
    grid = HexGrid.new(config.map_radius)
    map_data = HexMapData.new(config)
    map_data.attach_grid(grid)
    _register_default_handlers()
    _reset_phase_state()

func generate() -> HexMapData:
    rng.seed = config.seed
    map_data.clear_stage_results()
    _reset_phase_state()
    print("[HexMapGenerator] Starting map generation with seed %d (radius=%d, kingdoms=%d)" % [
        config.seed,
        config.map_radius,
        config.kingdom_count,
    ])
    for phase in PHASE_SEQUENCE:
        var handler: Callable = phase_handlers.get(phase, Callable())
        var phase_name := String(phase)
        if handler.is_valid():
            print("[HexMapGenerator] -> %s phase" % phase_name)
            handler.call()
            print("[HexMapGenerator] <- %s phase complete" % phase_name)
        else:
            print("[HexMapGenerator] Skipping %s phase (no handler registered)" % phase_name)
    print("[HexMapGenerator] Map generation complete")
    return map_data

func set_phase_handler(phase: StringName, handler: Callable) -> void:
    if not PHASE_SEQUENCE.has(phase):
        push_warning("[HexMapGenerator] Unknown phase '%s'" % String(phase))
        return
    phase_handlers[phase] = handler

func get_phase_handler(phase: StringName) -> Callable:
    return phase_handlers.get(phase, Callable())

func get_rng() -> RandomNumberGenerator:
    return rng

func get_grid() -> HexGrid:
    return grid

func get_map_data() -> HexMapData:
    return map_data

func _register_default_handlers() -> void:
    phase_handlers = {
        PHASE_TERRAIN: Callable(self, "_default_terrain_phase"),
        PHASE_RIVERS: Callable(self, "_default_rivers_phase"),
        PHASE_BIOMES: Callable(self, "_default_biomes_phase"),
        PHASE_BORDERS: Callable(self, "_default_borders_phase"),
        PHASE_SETTLEMENTS: Callable(self, "_default_settlements_phase"),
        PHASE_ROADS: Callable(self, "_default_roads_phase"),
        PHASE_FORTS: Callable(self, "_default_forts_phase"),
    }

func _reset_phase_state() -> void:
    terrain_state = {}
    rivers_state = {}
    biomes_state = {}
    borders_state = {}
    settlements_state = {}
    roads_state = {}
    forts_state = {}

func _default_terrain_phase() -> void:
    terrain_state = {
        "hexes": PackedVector2Array(),
        "regions": {},
    }
    map_data.set_stage_result(PHASE_TERRAIN, terrain_state)

func _default_rivers_phase() -> void:
    rivers_state = {
        "networks": [],
    }
    map_data.set_stage_result(PHASE_RIVERS, rivers_state)

func _default_biomes_phase() -> void:
    biomes_state = {
        "biomes": {},
    }
    map_data.set_stage_result(PHASE_BIOMES, biomes_state)

func _default_borders_phase() -> void:
    borders_state = {
        "edges": [],
    }
    map_data.set_stage_result(PHASE_BORDERS, borders_state)

func _default_settlements_phase() -> void:
    settlements_state = {
        "cities": [],
        "villages": [],
    }
    map_data.set_stage_result(PHASE_SETTLEMENTS, settlements_state)

func _default_roads_phase() -> void:
    roads_state = {
        "routes": [],
    }
    map_data.set_stage_result(PHASE_ROADS, roads_state)

func _default_forts_phase() -> void:
    forts_state = {
        "sites": [],
    }
    map_data.set_stage_result(PHASE_FORTS, forts_state)
