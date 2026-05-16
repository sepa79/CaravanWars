extends MainLoop

const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_STATE_SCRIPT: GDScript = preload("res://simulation/PartyState.gd")
const PARTY_TRAVEL_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyTravelConfig.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_travel_intent_follows_known_multi_leg_path()
    _test_travel_intent_rejects_unknown_destination()
    _test_travel_intent_rejects_destination_without_known_path()
    _test_known_destinations_include_reachable_non_neighbors()

    if not _failed:
        print("[TravelIntentCommandTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Travel intent command test failed.")
    return _is_finished


func _test_travel_intent_follows_known_multi_leg_path() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("player_party", "caravan", "wroclaw")
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")
    _teach_route(server, party, "opole", "raciborz")

    var result: RefCounted = server.submit_travel_intent(_create_travel_intent_command("player_party", "raciborz"))
    _expect(result.accepted, "Expected travel intent to reachable known destination to be accepted.")
    _expect(_string_array_from_variant(result.details.get("path_node_ids", [])) == ["wroclaw", "opole", "raciborz"], "Expected path via Opole.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_TRAVELING, "Expected party to start first leg.")
    _expect(party.destination_node_id == "opole", "Expected first leg destination to be Opole.")
    _expect(party.travel_intent_destination_node_id == "raciborz", "Expected intent destination to remain Raciborz.")

    server.tick(3.0)
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_TRAVELING, "Expected party to continue onto second leg after Opole.")
    _expect(party.current_node_id == "opole", "Expected party to be at Opole after first leg.")
    _expect(party.destination_node_id == "raciborz", "Expected second leg destination to be Raciborz.")

    server.tick(2.0)
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected party to become idle after intent completion.")
    _expect(party.current_node_id == "raciborz", "Expected party to arrive at Raciborz.")
    _expect(party.travel_intent_destination_node_id.is_empty(), "Expected completed intent plan to be cleared.")
    _expect(_event_types(server).has("party_travel_intent_started"), "Expected travel intent start event.")
    _expect(_event_types(server).has("party_travel_intent_completed"), "Expected travel intent completion event.")


func _test_travel_intent_rejects_unknown_destination() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("limited_party", "pilgrims", "wroclaw")
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")

    var result: RefCounted = server.submit_travel_intent(_create_travel_intent_command("limited_party", "raciborz"))
    _expect(not result.accepted, "Expected intent to unknown destination to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_DESTINATION_UNKNOWN, "Expected destination_unknown error.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected rejected intent to leave party idle.")


func _test_travel_intent_rejects_destination_without_known_path() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("fragmented_party", "patrol", "wroclaw")
    party.knowledge.add_known_node("raciborz")
    server.state.add_party(party)

    var result: RefCounted = server.submit_travel_intent(_create_travel_intent_command("fragmented_party", "raciborz"))
    _expect(not result.accepted, "Expected intent without known path to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_NO_KNOWN_PATH, "Expected no_known_path error.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected no-path rejection to leave party idle.")


func _test_known_destinations_include_reachable_non_neighbors() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("route_party", "retinue", "wroclaw")
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")
    _teach_route(server, party, "opole", "raciborz")

    var destination_node_ids: Array[String] = server.get_known_destination_node_ids_for_party("route_party")
    _expect(destination_node_ids.has("opole"), "Expected adjacent known destination.")
    _expect(destination_node_ids.has("raciborz"), "Expected reachable non-neighbor destination.")


func _create_server() -> RefCounted:
    var server: RefCounted = SIMULATION_SERVER_SCRIPT.new()
    server.state = SIMULATION_STATE_SCRIPT.new()
    server.state.region_graph = REGION_GRAPH_LOADER_SCRIPT.load_from_file("res://data/regions/silesia.json")
    server.travel_config = PARTY_TRAVEL_CONFIG_SCRIPT.load_from_file("res://data/simulation/party_travel.json")
    return server


func _create_party(party_id: String, party_type: String, current_node_id: String) -> RefCounted:
    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = party_id
    party.party_type = party_type
    party.current_node_id = current_node_id
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 1,
        "pack_animal_count": 1,
        "guard_count": 2
    })
    party.knowledge.add_known_node(current_node_id)
    return party


func _create_travel_intent_command(party_id: String, destination_node_id: String) -> RefCounted:
    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.destination_node_id = destination_node_id
    return command


func _teach_route(server: RefCounted, party: RefCounted, from_node_id: String, to_node_id: String) -> void:
    var route_edge: RefCounted = server.state.region_graph.get_edge_between(from_node_id, to_node_id)
    if route_edge != null:
        party.knowledge.learn_route(route_edge)


func _event_types(server: RefCounted) -> Array[String]:
    var event_types: Array[String] = []
    for event_dictionary: Dictionary in server.get_recent_events(20):
        event_types.append(str(event_dictionary.get("event_type", "")))
    return event_types


func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
