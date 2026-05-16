extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MAYOR_FOOD_MANAGER_SCRIPT: GDScript = preload("res://simulation/managers/MayorFoodManager.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_mayor_declares_food_need()
    _test_mayor_does_not_declare_need_above_floor()

    if not _failed:
        print("[MayorFoodManagerTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Mayor food manager test failed.")
    return _is_finished


func _test_mayor_declares_food_need() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var manager: RefCounted = MAYOR_FOOD_MANAGER_SCRIPT.new()
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    wroclaw.resources["food"] = 5

    var result: Dictionary = manager.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    _expect(bool(result.get("accepted", false)), "Expected mayor food manager action to be accepted.")
    _expect(result.get("action", "") == "declare_food_need", "Expected mayor to declare food need.")

    var need_event: RefCounted = _event_by_type(server, "location_need_declared")
    var details: Dictionary = need_event.details
    _expect(details.get("location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected need event location id.")
    _expect(details.get("manager_actor_id", "") == "mayor_wroclaw", "Expected need event manager id.")
    _expect(details.get("goods_id", "") == "food", "Expected need event goods id.")
    _expect(int(details.get("needed_amount", 0)) == 75, "Expected need amount from current to desired food.")

    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(need_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})
    _expect(world_event.get("event_type", "") == "location_need_declared", "Expected WorldMemory need event type.")
    _expect(metadata.get("reason", "") == "food_below_floor", "Expected need reason metadata.")


func _test_mayor_does_not_declare_need_above_floor() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var manager: RefCounted = MAYOR_FOOD_MANAGER_SCRIPT.new()

    var result: Dictionary = manager.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    _expect(bool(result.get("accepted", false)), "Expected mayor no-action to be accepted.")
    _expect(result.get("action", "") == "none", "Expected mayor to do nothing above floor.")
    _expect(result.get("reason", "") == "food_above_floor", "Expected no-action reason above floor.")


func _event_by_type(server: RefCounted, event_type: String) -> RefCounted:
    for event_dictionary: Dictionary in server.get_recent_events(20):
        if str(event_dictionary.get("event_type", "")) == event_type:
            return SIMULATION_EVENT_SCRIPT.from_dictionary(event_dictionary)
    _expect(false, "Expected event type not found: %s." % event_type)
    return SIMULATION_EVENT_SCRIPT.create("", "", "", 0.0, {})


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
