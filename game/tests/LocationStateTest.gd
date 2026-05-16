extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_new_game_contains_managed_locations()
    _test_client_snapshot_shows_current_location_only()
    _test_client_snapshot_updates_location_after_travel()
    _test_save_load_preserves_locations()

    if not _failed:
        print("[LocationStateTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Location state test failed.")
    return _is_finished


func _test_new_game_contains_managed_locations() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _expect(server.state.has_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID), "Expected Wroclaw location.")
    _expect(server.state.has_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID), "Expected Opole location.")
    _expect(server.state.has_location(GAME_SESSION_FACTORY_SCRIPT.NYSA_LOCATION_ID), "Expected Nysa location.")

    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    _expect(wroclaw.manager_actor_id == "mayor_wroclaw", "Expected Wroclaw manager actor.")
    _expect(int(wroclaw.resources.get("food", 0)) == 120, "Expected Wroclaw seed food.")


func _test_client_snapshot_shows_current_location_only() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var client_snapshot: Dictionary = server.get_client_snapshot(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var current_locations: Array = client_snapshot.get("current_locations", [])
    var location_ids: Array[String] = _location_ids(current_locations)

    _expect(location_ids.has(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID), "Expected Wroclaw location visible at start.")
    _expect(not location_ids.has(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID), "Expected Opole location hidden while in Wroclaw.")


func _test_client_snapshot_updates_location_after_travel() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"
    var result: RefCounted = server.submit_move_party(command)
    _expect(result.accepted, "Expected setup travel to be accepted.")

    server.tick(3.0)
    var client_snapshot: Dictionary = server.get_client_snapshot(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var location_ids: Array[String] = _location_ids(client_snapshot.get("current_locations", []))
    _expect(location_ids.has(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID), "Expected Opole location visible after arrival.")
    _expect(not location_ids.has(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID), "Expected Wroclaw location hidden after leaving.")


func _test_save_load_preserves_locations() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    wroclaw.resources["food"] = 111

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save with locations to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_wroclaw: RefCounted = loaded_server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    _expect(loaded_wroclaw.manager_actor_id == "mayor_wroclaw", "Expected loaded Wroclaw manager actor.")
    _expect(int(loaded_wroclaw.resources.get("food", 0)) == 111, "Expected loaded Wroclaw resources.")


func _location_ids(locations: Array) -> Array[String]:
    var location_ids: Array[String] = []
    for location_value: Variant in locations:
        if typeof(location_value) == TYPE_DICTIONARY:
            location_ids.append(str(location_value.get("location_id", "")))
    return location_ids


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
