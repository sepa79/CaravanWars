extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const REPORT_BACK_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/ReportBackCommand.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_report_back_emits_memory_report_event()
    _test_report_back_requires_physical_recipient()
    _test_report_back_locks_party_until_complete()

    if not _failed:
        print("[ReportBackCommandTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Report back command test failed.")
    return _is_finished


func _test_report_back_emits_memory_report_event() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_report_back(_report_to_mayor_command())
    _expect(result.accepted, "Expected report back task to be accepted.")
    _expect(result.details.get("recipient_actor_id", "") == "mayor_wroclaw", "Expected recipient actor in task start details.")
    _expect(_event_by_type(server, "party_task_started").event_type == "party_task_started", "Expected report task started event.")
    _expect(_event_count_by_type(server, "worldsim_memory_reported") == 0, "Expected no report event before task completes.")

    server.tick(0.10)

    var report_event: RefCounted = _event_by_type(server, "worldsim_memory_reported")
    _expect(report_event.details.get("from_owner_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected party as report source owner.")
    _expect(report_event.details.get("to_owner_id", "") == "mayor_wroclaw", "Expected mayor as report recipient owner.")
    _expect(report_event.details.get("actor_id", "") == "quartermaster_wroclaw", "Expected quartermaster as report actor.")

    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(report_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "worldsim_memory_reported", "Expected report export event.")
    _expect(metadata.get("from_owner_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected source owner metadata.")
    _expect(metadata.get("to_owner_id", "") == "mayor_wroclaw", "Expected recipient owner metadata.")
    _expect(metadata.has("listener_interest_tags"), "Expected interest tags metadata.")


func _test_report_back_requires_physical_recipient() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = _report_to_mayor_command()
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID

    var result: RefCounted = server.submit_report_back(command)
    _expect(not result.accepted, "Expected report back at remote location to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_LOCATION_MISMATCH, "Expected location mismatch for remote report.")

    command = _report_to_mayor_command()
    command.recipient_actor_id = "missing_actor"
    result = server.submit_report_back(command)
    _expect(not result.accepted, "Expected report back to missing actor to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_REPORT_RECIPIENT_NOT_PRESENT, "Expected recipient not present.")


func _test_report_back_locks_party_until_complete() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var start_result: RefCounted = server.submit_report_back(_report_to_mayor_command())
    _expect(start_result.accepted, "Expected report back setup to be accepted.")

    var travel_command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    travel_command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    travel_command.destination_node_id = "opole"
    var travel_result: RefCounted = server.submit_travel_intent(travel_command)
    _expect(not travel_result.accepted, "Expected travel to be rejected during report back task.")
    _expect(travel_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party busy during report back task.")

    server.tick(0.10)

    var after_task_travel_result: RefCounted = server.submit_travel_intent(travel_command)
    _expect(after_task_travel_result.accepted, "Expected travel after report back task to be accepted.")


func _report_to_mayor_command() -> RefCounted:
    var command: RefCounted = REPORT_BACK_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.actor_id = "quartermaster_wroclaw"
    command.recipient_actor_id = "mayor_wroclaw"
    command.recipient_owner_kind = "actor"
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.max_entries = 3
    command.trust = 0.9
    command.distortion_noise = 0.02
    command.listener_interest_tags.append("food")
    command.listener_interest_tags.append(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    command.notes = "Supply party report back"
    return command


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
