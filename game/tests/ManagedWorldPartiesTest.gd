extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_new_game_contains_managed_world_parties()
    _test_client_snapshot_hides_distant_parties()
    _test_client_snapshot_shows_party_at_same_node()
    _test_non_player_party_uses_same_move_command()

    if not _failed:
        print("[ManagedWorldPartiesTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Managed world parties test failed.")
    return _is_finished


func _test_new_game_contains_managed_world_parties() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID), "Expected player party.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID), "Expected bandit party.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID), "Expected merchant party.")
    _expect(server.state.has_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID), "Expected Wroclaw supply party.")

    var bandit_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID)
    var merchant_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    _expect(bandit_party.manager_actor_id == "bandit_chief_boruta", "Expected bandit manager actor.")
    _expect(merchant_party.manager_actor_id == "merchant_miroslaw", "Expected merchant manager actor.")
    _expect(supply_party.manager_actor_id == "quartermaster_wroclaw", "Expected supply party manager actor.")
    _expect(supply_party.authorized_issuer_actor_ids.has("mayor_wroclaw"), "Expected mayor to be authorized supply order issuer.")


func _test_client_snapshot_hides_distant_parties() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var client_snapshot: Dictionary = server.get_client_snapshot(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var visible_parties: Array = client_snapshot.get("visible_parties", [])
    var visible_party_ids: Array[String] = _visible_party_ids(visible_parties)
    _expect(visible_party_ids.has(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID), "Expected city supply party visible at Wroclaw game start.")
    _expect(not visible_party_ids.has(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID), "Expected distant merchant party hidden at game start.")
    _expect(not visible_party_ids.has(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID), "Expected distant bandit party hidden at game start.")


func _test_client_snapshot_shows_party_at_same_node() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"
    var result: RefCounted = server.submit_move_party(command)
    _expect(result.accepted, "Expected player move setup to be accepted.")

    server.tick(4.0)
    var client_snapshot: Dictionary = server.get_client_snapshot(GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID)
    var visible_parties: Array = client_snapshot.get("visible_parties", [])
    _expect(_visible_party_ids(visible_parties).has(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID), "Expected merchant party visible at Opole.")
    _expect(_visible_manager_actor_id(visible_parties, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID) == "merchant_miroslaw", "Expected visible merchant manager id.")
    _expect(not _visible_party_ids(visible_parties).has(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID), "Expected distant bandit party to remain hidden.")


func _test_non_player_party_uses_same_move_command() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID
    command.from_node_id = "great_forest"
    command.to_node_id = "opole"

    var result: RefCounted = server.submit_move_party(command)
    var bandit_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.BANDIT_PARTY_ID)
    _expect(result.accepted, "Expected bandit party to use same movement command.")
    _expect(bandit_party.destination_node_id == "opole", "Expected bandit party destination to be Opole.")


func _visible_party_ids(visible_parties: Array) -> Array[String]:
    var party_ids: Array[String] = []
    for party_value: Variant in visible_parties:
        if typeof(party_value) == TYPE_DICTIONARY:
            party_ids.append(str(party_value.get("party_id", "")))
    return party_ids


func _visible_manager_actor_id(visible_parties: Array, party_id: String) -> String:
    for party_value: Variant in visible_parties:
        if typeof(party_value) == TYPE_DICTIONARY and str(party_value.get("party_id", "")) == party_id:
            return str(party_value.get("manager_actor_id", ""))
    return ""


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
