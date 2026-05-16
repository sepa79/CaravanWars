extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InspectLocalRoutesCommand.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const TEST_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/TestSimulationEventSink.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_event_sink_receives_authoritative_events()
    _test_arrival_event_maps_to_world_event_payload()
    _test_local_route_inspection_exports_bounded_metadata()
    _test_goods_transfer_exports_trade_metadata()
    _test_unknown_event_type_is_not_exported()

    if not _failed:
        print("[WorldMemoryEventExportTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "WorldMemory event export test failed.")
    return _is_finished


func _test_event_sink_receives_authoritative_events() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var event_sink: RefCounted = TEST_EVENT_SINK_SCRIPT.new()
    server.add_event_sink(event_sink)

    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)

    _expect(result.accepted, "Expected local route inspection command to be accepted.")
    _expect(event_sink.event_types().has("party_local_routes_inspected"), "Expected event sink to receive local route inspection event.")


func _test_arrival_event_maps_to_world_event_payload() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"
    var result: RefCounted = server.submit_move_party(command)
    _expect(result.accepted, "Expected setup move command to be accepted.")

    server.tick(3.0)
    var arrival_event: RefCounted = _event_by_type(server, "party_arrived")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(arrival_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(export_payload.get("export_kind", "") == "world_event", "Expected world event export kind.")
    _expect(world_event.get("event_type", "") == "party_arrived", "Expected party_arrived export event type.")
    _expect(world_event.get("location_id", "") == "opole", "Expected arrival location to be Opole.")
    _expect(metadata.get("party_id", "") == GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID, "Expected party id in metadata.")
    _expect(metadata.get("manager_actor_id", "") == "player_caravan_leader", "Expected manager actor id in metadata.")
    _expect(is_equal_approx(float(metadata.get("occurred_day", -1.0)), 3.0), "Expected occurred day in metadata.")


func _test_local_route_inspection_exports_bounded_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)
    _expect(result.accepted, "Expected local route inspection command to be accepted.")

    var inspection_event: RefCounted = _event_by_type(server, "party_local_routes_inspected")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(inspection_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("location_id", "") == "wroclaw", "Expected local inspection location to be current node.")
    _expect(metadata.has("discovered_edge_count"), "Expected discovered edge count metadata.")
    _expect(metadata.has("discovered_node_count"), "Expected discovered node count metadata.")
    _expect(not metadata.has("known_routes"), "Expected export to avoid full known route list.")
    _expect(not metadata.has("region_graph"), "Expected export to avoid full region graph.")


func _test_goods_transfer_exports_trade_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 1
    command.direction = TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    var result: RefCounted = server.submit_transfer_goods(command)
    _expect(result.accepted, "Expected setup goods transfer to be accepted.")

    var transfer_event: RefCounted = _event_by_type(server, "goods_transferred")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(transfer_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected transfer location id.")
    _expect(metadata.get("goods_id", "") == "food", "Expected goods id metadata.")
    _expect(int(metadata.get("amount", 0)) == 1, "Expected transfer amount metadata.")
    _expect(metadata.get("direction", "") == TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION, "Expected transfer direction metadata.")


func _test_unknown_event_type_is_not_exported() -> void:
    var simulation_event: RefCounted = SIMULATION_EVENT_SCRIPT.create("debug_only_event", "party", "Debug only.", 0.0, {})
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(simulation_event)
    _expect(export_payload.is_empty(), "Expected unknown event type to be ignored by mapper.")


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
