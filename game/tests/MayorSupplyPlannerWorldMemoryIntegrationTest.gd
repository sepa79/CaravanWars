extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MAYOR_SUPPLY_PLANNER_SCRIPT: GDScript = preload("res://simulation/managers/MayorSupplyPlanner.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    var mayor_memory: Array = _load_mayor_memory()
    if mayor_memory.is_empty():
        _expect(false, "Expected mayor memory fixture from WorldMemory.")
    else:
        _test_mayor_does_not_duplicate_fresh_world_memory_order(mayor_memory)
        _test_mayor_reissues_after_stale_world_memory_order(mayor_memory)

    if _failed:
        assert(false, "Mayor supply planner WorldMemory integration test failed.")
    else:
        print("[MayorSupplyPlannerWorldMemoryIntegrationTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    return _is_finished


func _test_mayor_does_not_duplicate_fresh_world_memory_order(mayor_memory: Array) -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 1.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        mayor_memory
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected fresh mayor memory result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no duplicate order from fresh WorldMemory. Result: %s." % str(result))
    _expect(result.get("reason", "") == "supply_intent_already_active", "Expected active supply intent from WorldMemory. Result: %s." % str(result))
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected planner not to mutate party when active memory exists.")


func _test_mayor_reissues_after_stale_world_memory_order(mayor_memory: Array) -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 100.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        mayor_memory
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected stale mayor memory result to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected stale WorldMemory order not to block new order. Result: %s." % str(result))
    _expect(result.get("source_report_status", "") == "stale", "Expected stale source report status from old heard report. Result: %s." % str(result))
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected planner to assign new supply order after stale memory.")


func _load_mayor_memory() -> Array:
    var memory_path: String = OS.get_environment("CW_MAYOR_MEMORY_FILE")
    if memory_path.is_empty():
        _expect(false, "CW_MAYOR_MEMORY_FILE is required.")
        return []

    var file: FileAccess = FileAccess.open(memory_path, FileAccess.READ)
    if file == null:
        _expect(false, "Could not open mayor memory file: %s." % memory_path)
        return []

    var parsed_json: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed_json) != TYPE_ARRAY:
        _expect(false, "Mayor memory file must contain an array.")
        return []

    var mayor_memory: Array = parsed_json
    print("[MayorSupplyPlannerWorldMemoryIntegrationTest] Loaded memory entries: %d" % mayor_memory.size())
    for entry: Dictionary in mayor_memory:
        var metadata: Dictionary = {}
        var metadata_value: Variant = entry.get("metadata", {})
        if typeof(metadata_value) == TYPE_DICTIONARY:
            metadata = metadata_value
        print("[MayorSupplyPlannerWorldMemoryIntegrationTest] memory kind=%s owner=%s target=%s goods=%s occurred_day=%s heard_at=%s source=%s" % [
            str(entry.get("kind", "")),
            str(entry.get("owner_id", "")),
            str(metadata.get("target_location_id", metadata.get("location_id", ""))),
            str(metadata.get("goods_id", "")),
            str(metadata.get("occurred_day", "")),
            str(entry.get("heard_at_time", "")),
            str(metadata.get("source", ""))
        ])
    return mayor_memory


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    print("[MayorSupplyPlannerWorldMemoryIntegrationTest] FAIL: %s" % failure_message)
    push_error(failure_message)
    _failed = true
