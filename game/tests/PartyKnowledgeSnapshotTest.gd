extends MainLoop

const LOCAL_GAME_BOOTSTRAP_SCRIPT: GDScript = preload("res://simulation/LocalGameBootstrap.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_STATE_SCRIPT: GDScript = preload("res://simulation/PartyState.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")
const INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InspectLocalRoutesCommand.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_client_snapshot_hides_unknown_routes()
    _test_unknown_route_command_is_rejected()
    _test_inspect_local_routes_discovers_local_routes()
    _test_inspect_local_routes_rejected_while_traveling()

    if not _failed:
        print("[PartyKnowledgeSnapshotTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Party knowledge snapshot test failed.")
    return _is_finished


func _test_client_snapshot_hides_unknown_routes() -> void:
    var server: RefCounted = LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server()
    var full_neighbors: Array[String] = server.get_neighbor_node_ids_for_party(LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID)
    var known_neighbors: Array[String] = server.get_known_neighbor_node_ids_for_party(LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID)
    var client_snapshot: Dictionary = server.get_client_snapshot(LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID)

    _expect(full_neighbors.has("nysa"), "Expected full server graph to know Wroclaw-Nysa.")
    _expect(not known_neighbors.has("nysa"), "Expected client-visible knowledge to hide unknown Wroclaw-Nysa.")
    _expect(known_neighbors.has("opole"), "Expected client-visible knowledge to include Opole.")
    _expect(_route_ids_from_snapshot(client_snapshot).has("wroclaw_opole"), "Expected client snapshot to include known Wroclaw-Opole route.")
    _expect(not _route_ids_from_snapshot(client_snapshot).has("wroclaw_nysa"), "Expected client snapshot to hide unknown Wroclaw-Nysa route.")


func _test_unknown_route_command_is_rejected() -> void:
    var server: RefCounted = _create_server_with_party_without_route_knowledge()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = "limited_party"
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"

    var result: RefCounted = server.submit_move_party(command)
    _expect(not result.accepted, "Expected command over unknown route to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ROUTE_UNKNOWN, "Expected route_unknown for unknown route command.")


func _test_inspect_local_routes_discovers_local_routes() -> void:
    var server: RefCounted = LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server()
    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID

    var result: RefCounted = server.submit_inspect_local_routes(command)
    var known_neighbors: Array[String] = server.get_known_neighbor_node_ids_for_party(LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID)
    var client_snapshot: Dictionary = server.get_client_snapshot(LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID)

    _expect(result.accepted, "Expected inspect local routes command to be accepted.")
    _expect(int(result.details.get("discovered_edge_count", 0)) > 0, "Expected local route inspection to discover at least one route.")
    _expect(known_neighbors.has("nysa"), "Expected local route inspection at Wroclaw to reveal Nysa.")
    _expect(_route_ids_from_snapshot(client_snapshot).has("wroclaw_nysa"), "Expected client snapshot to include Wroclaw-Nysa after local route inspection.")
    _expect(_event_types(server).has("party_local_routes_inspected"), "Expected local route inspection event.")


func _test_inspect_local_routes_rejected_while_traveling() -> void:
    var server: RefCounted = LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server()
    var move_command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    move_command.party_id = LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID
    move_command.from_node_id = "wroclaw"
    move_command.to_node_id = "opole"
    var move_result: RefCounted = server.submit_move_party(move_command)
    _expect(move_result.accepted, "Expected setup move command to be accepted.")

    var inspect_command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    inspect_command.party_id = LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID
    var inspect_result: RefCounted = server.submit_inspect_local_routes(inspect_command)
    _expect(not inspect_result.accepted, "Expected local route inspection to be rejected while traveling.")
    _expect(inspect_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_PARTY_BUSY, "Expected party_busy for local route inspection while traveling.")


func _create_server_with_party_without_route_knowledge() -> RefCounted:
    var server: RefCounted = SIMULATION_SERVER_SCRIPT.new()
    server.state = SIMULATION_STATE_SCRIPT.new()
    server.state.region_graph = REGION_GRAPH_LOADER_SCRIPT.load_from_file("res://data/regions/silesia.json")

    var party: RefCounted = PARTY_STATE_SCRIPT.new()
    party.party_id = "limited_party"
    party.party_type = "pilgrims"
    party.current_node_id = "wroclaw"
    party.composition = PARTY_COMPOSITION_SCRIPT.from_dictionary({
        "foot_count": 6,
        "horse_count": 0,
        "wagon_count": 0,
        "pack_animal_count": 0,
        "guard_count": 0
    })
    party.knowledge.add_known_node("wroclaw")
    party.knowledge.add_known_node("opole")
    server.state.add_party(party)
    return server


func _route_ids_from_snapshot(client_snapshot: Dictionary) -> Array[String]:
    var route_ids: Array[String] = []
    var routes: Variant = client_snapshot.get("known_routes", [])
    if typeof(routes) != TYPE_ARRAY:
        return route_ids

    for route_value: Variant in routes:
        if typeof(route_value) == TYPE_DICTIONARY:
            route_ids.append(str(route_value.get("edge_id", "")))
    return route_ids


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
