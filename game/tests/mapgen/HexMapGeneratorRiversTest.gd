extends RefCounted
class_name HexMapGeneratorRiversTestSuite

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")

var _failures: Array[String] = []

func run() -> int:
    _failures.clear()
    _test_river_traces_downhill_and_sets_masks()
    _test_confluence_promotes_river_class()
    _test_lake_outlet_extends_to_sea()
    return _failures.size()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func _record_failure(message: String) -> void:
    _failures.append(message)

func _check(condition: bool, message: String) -> void:
    if not condition:
        _record_failure(message)

func _make_generator(radius: int, rivers_cap: int = 6) -> HexMapGenerator:
    var config := HexMapConfigScript.new(12345, radius, 1, rivers_cap)
    return HexMapGeneratorScript.new(config)

func _make_hex_entry(q: int, r: int, region: String, elev: float) -> Dictionary:
    var is_sea := region == "sea"
    var is_water := is_sea or region == "lake"
    return {
        "coord": Vector2i(q, r),
        "region": region,
        "is_water": is_water,
        "is_sea": is_sea,
        "elev": elev,
    }

func _apply_terrain(generator: HexMapGenerator, hexes: Dictionary) -> void:
    var terrain := {
        "hexes": hexes,
        "regions": {},
        "coastline": {},
        "validation": {},
    }
    generator.terrain_state = terrain
    generator.map_data.set_stage_result(HexMapGeneratorScript.PHASE_TERRAIN, terrain)

func _test_river_traces_downhill_and_sets_masks() -> void:
    var generator := _make_generator(2)
    var hexes: Dictionary = {}
    hexes[Vector2i(0, 0)] = _make_hex_entry(0, 0, "mountains", 0.9)
    hexes[Vector2i(0, -1)] = _make_hex_entry(0, -1, "plains", 0.42)
    hexes[Vector2i(0, -2)] = _make_hex_entry(0, -2, "sea", 0.03)
    _apply_terrain(generator, hexes)

    generator._default_rivers_phase()

    var rivers_state: Dictionary = generator.rivers_state
    var networks: Array = rivers_state.get("networks", [])
    _check(networks.size() == 1, "Expected a single river network from mountain peak to sea.")
    if networks.size() > 0:
        var path: Array = networks[0].get("path", [])
        _check(path.size() == 3, "River path should include source, channel and mouth.")
        if path.size() == 3:
            _check(path[0] == Vector2i(0, 0), "River should originate at the mountain peak.")
            _check(path[1] == Vector2i(0, -1), "River should traverse the adjacent channel hex.")
            _check(path[2] == Vector2i(0, -2), "River should terminate in the sea hex.")
    var middle: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(0, -1), {})
    _check(String(middle.get("region", "")) == "valley", "River flow should carve plains into a valley.")
    var mask := int(middle.get("river_mask", 0))
    _check((mask & (1 << 2)) != 0 and (mask & (1 << 5)) != 0, "Valley hex should contain upstream and downstream river mask bits.")
    _check(int(middle.get("river_class", 0)) == 1, "Single-source rivers should default to class 1.")
    var sea_hex: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(0, -2), {})
    _check(bool(sea_hex.get("is_mouth", false)), "Sea hex should be marked as a river mouth.")
    var errors: Array = rivers_state.get("validation", {}).get("errors", [])
    _check(errors.is_empty(), "River validation should report no errors for a complete sink.")

func _test_confluence_promotes_river_class() -> void:
    var generator := _make_generator(3)
    var hexes: Dictionary = {}
    hexes[Vector2i(-1, 0)] = _make_hex_entry(-1, 0, "mountains", 0.94)
    hexes[Vector2i(1, -1)] = _make_hex_entry(1, -1, "mountains", 0.93)
    hexes[Vector2i(0, -1)] = _make_hex_entry(0, -1, "plains", 0.38)
    hexes[Vector2i(0, -2)] = _make_hex_entry(0, -2, "sea", 0.02)
    _apply_terrain(generator, hexes)

    generator._default_rivers_phase()

    var valley: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(0, -1), {})
    _check(String(valley.get("region", "")) == "valley", "Confluence tile should convert to a valley.")
    var mask := int(valley.get("river_mask", 0))
    _check((mask & (1 << 0)) != 0, "Confluence should include flow from east.")
    _check((mask & (1 << 2)) != 0, "Confluence should include downstream flow toward the sea.")
    _check((mask & (1 << 4)) != 0, "Confluence should include flow from west.")
    _check(int(valley.get("river_class", 0)) == 2, "Merged rivers should increase the river class to 2.")
    var rivers_state: Dictionary = generator.rivers_state
    var errors: Array = rivers_state.get("validation", {}).get("errors", [])
    _check(errors.is_empty(), "Confluence network should still reach a valid sink.")

func _test_lake_outlet_extends_to_sea() -> void:
    var generator := _make_generator(4)
    var hexes: Dictionary = {}
    hexes[Vector2i(0, 0)] = _make_hex_entry(0, 0, "mountains", 0.91)
    hexes[Vector2i(0, -1)] = _make_hex_entry(0, -1, "plains", 0.48)
    hexes[Vector2i(1, -1)] = _make_hex_entry(1, -1, "lake", 0.24)
    hexes[Vector2i(1, -2)] = _make_hex_entry(1, -2, "plains", 0.18)
    hexes[Vector2i(1, -3)] = _make_hex_entry(1, -3, "sea", 0.03)
    _apply_terrain(generator, hexes)

    generator._default_rivers_phase()

    var lake_hex: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(1, -1), {})
    var mask := int(lake_hex.get("river_mask", 0))
    _check((mask & (1 << 4)) != 0 and (mask & (1 << 2)) != 0, "Lake should have both inlet and outlet masks set.")
    var outlet: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(1, -2), {})
    _check(String(outlet.get("region", "")) == "valley", "Lake outlet plains should erode into a valley.")
    var rivers_state: Dictionary = generator.rivers_state
    var errors: Array = rivers_state.get("validation", {}).get("errors", [])
    _check(errors.is_empty(), "Lake outlet scenario should not report validation errors.")
    var networks: Array = rivers_state.get("networks", [])
    var sink: Dictionary = {}
    if networks.size() > 0:
        sink = networks[0].get("sink", {})
    _check(String(sink.get("type", "")) == "sea", "Lake outlet should continue until reaching the sea.")
    var sea_hex: Dictionary = generator.terrain_state.get("hexes", {}).get(Vector2i(1, -3), {})
    _check(bool(sea_hex.get("is_mouth", false)), "Downstream sea hex should be flagged as a river mouth.")
