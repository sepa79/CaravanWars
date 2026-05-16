extends MainLoop

const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_STATE_SCRIPT: GDScript = preload("res://simulation/PartyState.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const PARTY_TRAVEL_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyTravelConfig.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_valid_party_move_arrives_after_ticks()
    _test_move_and_arrival_emit_events()
    _test_invalid_route_is_rejected()
    _test_unknown_route_is_rejected()
    _test_origin_mismatch_is_rejected()
    _test_busy_party_is_rejected()
    _test_composition_changes_travel_speed()

    if not _failed:
        print("[PartyTravelCommandTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Party travel command test failed.")
    return _is_finished


func _test_valid_party_move_arrives_after_ticks() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("player_party", "caravan", "wroclaw", {
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 1,
        "pack_animal_count": 1,
        "guard_count": 2
    })
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")

    var result: RefCounted = server.submit_move_party(_create_move_command("player_party", "wroclaw", "opole"))
    _expect(result.accepted, "Expected valid move command to be accepted.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_TRAVELING, "Expected party to start traveling.")
    _expect(party.destination_node_id == "opole", "Expected destination to be Opole.")
    _expect(is_equal_approx(party.travel_distance_km, 80.0), "Expected Wroclaw-Opole distance to be 80 km.")

    server.tick(1.0)
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_TRAVELING, "Expected party to still be traveling after 1 day.")
    _expect(party.current_node_id == "wroclaw", "Expected party to stay at origin until arrival.")

    server.tick(2.0)
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected party to become idle after arrival.")
    _expect(party.current_node_id == "opole", "Expected party to arrive at Opole.")


func _test_invalid_route_is_rejected() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("pilgrim_party", "pilgrims", "wroclaw", {
        "foot_count": 12,
        "horse_count": 0,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 1
    })
    server.state.add_party(party)

    var result: RefCounted = server.submit_move_party(_create_move_command("pilgrim_party", "wroclaw", "great_forest"))
    _expect(not result.accepted, "Expected move to unconnected node to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ROUTE_NOT_FOUND, "Expected route_not_found error.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected rejected command to leave party idle.")


func _test_move_and_arrival_emit_events() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("event_party", "caravan", "wroclaw", {
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 1,
        "pack_animal_count": 1,
        "guard_count": 2
    })
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")

    var result: RefCounted = server.submit_move_party(_create_move_command("event_party", "wroclaw", "opole"))
    _expect(result.accepted, "Expected event move command to be accepted.")
    _expect(_event_types(server).has("party_travel_started"), "Expected travel start event.")

    server.tick(3.0)
    _expect(_event_types(server).has("party_arrived"), "Expected arrival event.")


func _test_unknown_route_is_rejected() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("route_party", "travelers", "wroclaw", {
        "foot_count": 3,
        "horse_count": 2,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 1
    })
    server.state.add_party(party)

    var result: RefCounted = server.submit_move_party(_create_move_command("route_party", "wroclaw", "opole"))
    _expect(not result.accepted, "Expected unknown but real route to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ROUTE_UNKNOWN, "Expected route_unknown error.")
    _expect(party.travel_state == PARTY_STATE_SCRIPT.TRAVEL_STATE_IDLE, "Expected unknown route rejection to leave party idle.")


func _test_origin_mismatch_is_rejected() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("bishop_retinue", "bishop_retinue", "wroclaw", {
        "foot_count": 4,
        "horse_count": 6,
        "wagon_count": 2,
        "pack_animal_count": 1,
        "guard_count": 6
    })
    server.state.add_party(party)
    _teach_route(server, party, "opole", "raciborz")

    var result: RefCounted = server.submit_move_party(_create_move_command("bishop_retinue", "opole", "raciborz"))
    _expect(not result.accepted, "Expected origin mismatch to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORIGIN_MISMATCH, "Expected origin_mismatch error.")
    _expect(party.current_node_id == "wroclaw", "Expected party position to remain unchanged.")


func _test_busy_party_is_rejected() -> void:
    var server: RefCounted = _create_server()
    var party: RefCounted = _create_party("local_lord", "local_lord_retinue", "wroclaw", {
        "foot_count": 5,
        "horse_count": 5,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 5
    })
    server.state.add_party(party)
    _teach_route(server, party, "wroclaw", "opole")
    _teach_route(server, party, "wroclaw", "legnica")

    var first_result: RefCounted = server.submit_move_party(_create_move_command("local_lord", "wroclaw", "opole"))
    var second_result: RefCounted = server.submit_move_party(_create_move_command("local_lord", "wroclaw", "legnica"))
    _expect(first_result.accepted, "Expected first move to be accepted.")
    _expect(not second_result.accepted, "Expected second move while traveling to be rejected.")
    _expect(second_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party_busy error.")


func _test_composition_changes_travel_speed() -> void:
    var travel_config: RefCounted = PARTY_TRAVEL_CONFIG_SCRIPT.load_from_file("res://data/simulation/party_travel.json")
    var mounted_composition: RefCounted = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 2,
        "horse_count": 8,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 2
    })
    var wagon_composition: RefCounted = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 8,
        "horse_count": 2,
        "wagon_count": 4,
        "pack_animal_count": 2,
        "guard_count": 3
    })

    var mounted_speed: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_travel_speed_km_per_day(mounted_composition, travel_config)
    var wagon_speed: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_travel_speed_km_per_day(wagon_composition, travel_config)
    _expect(mounted_speed > wagon_speed, "Expected mounted party to be faster than wagon-heavy party.")
    _expect(wagon_speed >= travel_config.minimum_speed_km_per_day, "Expected wagon-heavy party speed to respect minimum speed.")


func _create_server() -> RefCounted:
    var server: RefCounted = SIMULATION_SERVER_SCRIPT.new()
    server.state = SIMULATION_STATE_SCRIPT.new()
    server.state.region_graph = REGION_GRAPH_LOADER_SCRIPT.load_from_file("res://data/regions/silesia.json")
    server.travel_config = PARTY_TRAVEL_CONFIG_SCRIPT.load_from_file("res://data/simulation/party_travel.json")
    return server


func _create_party(party_id: String, party_type: String, current_node_id: String, composition_dictionary: Dictionary) -> RefCounted:
    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = party_id
    party.party_type = party_type
    party.current_node_id = current_node_id
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary(composition_dictionary)
    return party


func _create_move_command(party_id: String, from_node_id: String, to_node_id: String) -> RefCounted:
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.from_node_id = from_node_id
    command.to_node_id = to_node_id
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


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
