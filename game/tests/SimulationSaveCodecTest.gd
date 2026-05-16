extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InspectLocalRoutesCommand.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_new_game_factory_creates_start_state()
    _test_save_load_preserves_travel_intent_state()
    _test_load_rejects_wrong_schema_version()
    _test_load_rejects_unknown_region_graph()

    if not _failed:
        print("[SimulationSaveCodecTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Simulation save codec test failed.")
    return _is_finished


func _test_new_game_factory_creates_start_state() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _expect(is_equal_approx(server.current_day, 0.0), "Expected new game to start at day 0.")
    _expect(server.state.region_graph.id == "silesia", "Expected new game to load Silesia graph.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID), "Expected new game to create player party.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID), "Expected new game to create bandit party.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID), "Expected new game to create merchant party.")

    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    _expect(party.current_node_id == "wroclaw", "Expected player party to start in Wroclaw.")
    _expect(party.manager_actor_id == "player_caravan_leader", "Expected player party manager actor.")
    _expect(party.knowledge.knows_edge("wroclaw_opole"), "Expected player party to know Wroclaw-Opole route.")


func _test_save_load_preserves_travel_intent_state() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var inspect_command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    inspect_command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var inspect_result: RefCounted = server.submit_inspect_local_routes(inspect_command)
    _expect(inspect_result.accepted, "Expected local route inspection setup to be accepted.")

    var intent_command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    intent_command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    intent_command.destination_node_id = "raciborz"
    var intent_result: RefCounted = server.submit_travel_intent(intent_command)
    _expect(intent_result.accepted, "Expected travel intent setup to be accepted.")

    server.tick(1.0)
    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save snapshot to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_party: RefCounted = loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var original_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)

    _expect(is_equal_approx(loaded_server.current_day, server.current_day), "Expected loaded current day to match saved day.")
    _expect(loaded_party.current_node_id == original_party.current_node_id, "Expected loaded current node to match.")
    _expect(loaded_party.travel_state == original_party.travel_state, "Expected loaded travel state to match.")
    _expect(loaded_party.destination_node_id == original_party.destination_node_id, "Expected loaded active destination to match.")
    _expect(loaded_party.travel_intent_destination_node_id == "raciborz", "Expected loaded travel intent destination.")
    _expect(loaded_party.travel_path_edge_ids == original_party.travel_path_edge_ids, "Expected loaded travel path edges to match.")
    _expect(loaded_party.knowledge.knows_edge("wroclaw_raciborz"), "Expected loaded knowledge to preserve inspected local route.")
    _expect(loaded_server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID), "Expected loaded save to keep bandit party.")
    _expect(loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID).manager_actor_id == "merchant_miroslaw", "Expected loaded save to keep merchant manager.")
    _expect(loaded_server.get_recent_events(20).size() == server.get_recent_events(20).size(), "Expected runtime event log to load.")
    _expect(saved_dictionary.has("player_map_state"), "Expected save snapshot to reserve player map state field.")


func _test_load_rejects_wrong_schema_version() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    saved_dictionary["schema_version"] = 999

    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(not bool(load_result.get("accepted", false)), "Expected wrong schema version to be rejected.")
    _expect(str(load_result.get("error_code", "")) == SIMULATION_SAVE_CODEC_SCRIPT.ERROR_INVALID_SCHEMA_VERSION, "Expected invalid_schema_version error.")


func _test_load_rejects_unknown_region_graph() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    saved_dictionary["region_graph_id"] = "missing_region"

    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(not bool(load_result.get("accepted", false)), "Expected unknown region graph to be rejected.")
    _expect(str(load_result.get("error_code", "")) == SIMULATION_SAVE_CODEC_SCRIPT.ERROR_UNKNOWN_REGION_GRAPH, "Expected unknown_region_graph error.")


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
