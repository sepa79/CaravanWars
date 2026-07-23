extends MainLoop

const ASK_LOCAL_INFORMATION_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AskLocalInformationCommand.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_party_asks_local_location_for_goods_source()
    _test_party_task_blocks_travel_and_transfer_until_complete()
    _test_party_must_be_at_location_to_ask()

    if not _failed:
        print("[AskLocalInformationCommandTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Ask local information command test failed.")
    return _is_finished


func _test_party_asks_local_location_for_goods_source() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.actor_id = "quartermaster_wroclaw"
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.query_type = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE
    command.goods_id = "food"

    var result: RefCounted = server.submit_ask_local_information(command)
    _expect(result.accepted, "Expected local information query to be accepted.")
    _expect(result.details.has("duration_days"), "Expected task duration in result details.")
    _expect(result.details.get("actor_id", "") == "quartermaster_wroclaw", "Expected actor id in task start details.")
    _expect(_event_by_type(server, "party_task_started").event_type == "party_task_started", "Expected party task started event.")
    _expect(_event_count_by_type(server, "worldsim_local_information_received") == 0, "Expected no information before task completes.")

    server.tick(0.25)

    var information_event: RefCounted = _event_by_type(server, "worldsim_local_information_received")
    var sources: Array = information_event.details.get("known_source_locations", [])
    _expect(not sources.is_empty(), "Expected at least one local source.")
    _expect(_source_location_ids(sources).has(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID), "Expected Opole as remembered food source.")

    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(information_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "worldsim_local_information_received", "Expected local information export event.")
    _expect(metadata.get("party_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected party id metadata.")
    _expect(metadata.get("actor_id", "") == "quartermaster_wroclaw", "Expected actor id metadata.")
    _expect(metadata.get("query_type", "") == ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE, "Expected query type metadata.")
    _expect(metadata.has("known_source_locations"), "Expected known sources metadata.")
    _expect(float(metadata.get("duration_days", 0.0)) > 0.0, "Expected duration metadata.")


func _test_party_must_be_at_location_to_ask() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    party.current_node_id = "odra_crossing"

    var command: RefCounted = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.actor_id = "quartermaster_wroclaw"
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.query_type = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE
    command.goods_id = "food"

    var result: RefCounted = server.submit_ask_local_information(command)
    _expect(not result.accepted, "Expected remote local information query to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_LOCATION_MISMATCH, "Expected location mismatch.")


func _test_party_task_blocks_travel_and_transfer_until_complete() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var start_result: RefCounted = server.submit_ask_local_information(_ask_food_command())
    _expect(start_result.accepted, "Expected local information task setup to be accepted.")

    var travel_result: RefCounted = server.submit_travel_intent(_travel_to_opole_command())
    _expect(not travel_result.accepted, "Expected travel intent to be rejected during task.")
    _expect(travel_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party busy for travel during task.")

    var move_result: RefCounted = server.submit_move_party(_move_to_opole_command())
    _expect(not move_result.accepted, "Expected move command to be rejected during task.")
    _expect(move_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party busy for move during task.")

    var transfer_result: RefCounted = server.submit_transfer_goods(_withdraw_food_command())
    _expect(not transfer_result.accepted, "Expected transfer to be rejected during task.")
    _expect(transfer_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party busy for transfer during task.")

    var second_ask_result: RefCounted = server.submit_ask_local_information(_ask_food_command())
    _expect(not second_ask_result.accepted, "Expected second local information task to be rejected during task.")
    _expect(second_ask_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party busy for second ask during task.")

    server.tick(0.25)

    var after_task_travel_result: RefCounted = server.submit_travel_intent(_travel_to_opole_command())
    _expect(after_task_travel_result.accepted, "Expected travel intent after task completion to be accepted.")


func _ask_food_command() -> RefCounted:
    var command: RefCounted = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.actor_id = "quartermaster_wroclaw"
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.query_type = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE
    command.goods_id = "food"
    return command


func _travel_to_opole_command() -> RefCounted:
    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.destination_node_id = "opole"
    return command


func _move_to_opole_command() -> RefCounted:
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"
    return command


func _withdraw_food_command() -> RefCounted:
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 1
    command.direction = TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    return command


func _source_location_ids(sources: Array) -> Array[String]:
    var location_ids: Array[String] = []
    for source_value: Variant in sources:
        if typeof(source_value) == TYPE_DICTIONARY:
            location_ids.append(str(source_value.get("location_id", "")))
    return location_ids


func _event_by_type(server: RefCounted, event_type: String) -> RefCounted:
    for event_dictionary: Dictionary in server.get_recent_events(20):
        if str(event_dictionary.get("event_type", "")) == event_type:
            return SIMULATION_EVENT_SCRIPT.from_dictionary(event_dictionary)
    _expect(false, "Expected event type not found: %s." % event_type)
    return SIMULATION_EVENT_SCRIPT.create("", "", "", 0.0, {})


func _event_count_by_type(server: RefCounted, event_type: String) -> int:
    var count: int = 0
    for event_dictionary: Dictionary in server.get_recent_events(20):
        if str(event_dictionary.get("event_type", "")) == event_type:
            count += 1
    return count


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
