extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")
const WORLD_SIM_OBSERVATION_SERVICE_SCRIPT: GDScript = preload("res://simulation/WorldSimObservationService.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_worldsim_observes_local_location_for_party_memory()
    _test_worldsim_observes_same_node_party_for_party_memory()

    if not _failed:
        print("[WorldSimObservationTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "WorldSim observation test failed.")
    return _is_finished


func _test_worldsim_observes_local_location_for_party_memory() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var service: RefCounted = WORLD_SIM_OBSERVATION_SERVICE_SCRIPT.new()

    var result: Dictionary = service.observe_local_context(server, GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    _expect(bool(result.get("accepted", false)), "Expected WorldSim observation to be accepted.")
    _expect(int(result.get("emitted_event_count", 0)) >= 1, "Expected WorldSim observation event.")

    var observation_event: RefCounted = _event_by_type(server, "worldsim_location_observed")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(observation_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "worldsim_location_observed", "Expected location observation export.")
    _expect(metadata.get("owner_id", "") == GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID, "Expected observation owner to be observer party.")
    _expect(metadata.get("observed_location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected observed Wroclaw location.")
    _expect(metadata.has("observed_resources"), "Expected high-enough observation score to include local resources.")


func _test_worldsim_observes_same_node_party_for_party_memory() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var player_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var merchant_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    merchant_party.current_node_id = player_party.current_node_id

    var service: RefCounted = WORLD_SIM_OBSERVATION_SERVICE_SCRIPT.new()
    service.observe_local_context(server, GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)

    var observation_event: RefCounted = _event_by_type(server, "worldsim_party_observed")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(observation_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "worldsim_party_observed", "Expected party observation export.")
    _expect(metadata.get("owner_id", "") == GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID, "Expected party observation owner.")
    _expect(metadata.get("observed_party_id", "") == GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID, "Expected observed merchant party.")


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
