extends MainLoop

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_manager_can_assign_travel_order()
    _test_non_manager_cannot_assign_order()
    _test_order_starts_travel_intent_on_tick()
    _test_order_completes_after_arrival()
    _test_save_load_preserves_party_order()

    if not _failed:
        print("[PartyOrdersTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Party orders test failed.")
    return _is_finished


func _test_manager_can_assign_travel_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(result.accepted, "Expected manager to assign order.")
    _expect(party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO, "Expected travel_to order type.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED, "Expected assigned order status.")


func _test_non_manager_cannot_assign_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "bandit_chief_boruta",
        "raciborz"
    ))
    _expect(not result.accepted, "Expected non-manager order assignment to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_NOT_AUTHORIZED, "Expected order_not_authorized.")


func _test_order_starts_travel_intent_on_tick() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(result.accepted, "Expected setup order assignment to be accepted.")

    server.tick(0.0)
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ACTIVE, "Expected order to become active after tick.")
    _expect(party.travel_intent_destination_node_id == "raciborz", "Expected order to start travel intent.")
    _expect(_event_types(server).has("party_order_started"), "Expected order started event.")


func _test_order_completes_after_arrival() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(result.accepted, "Expected setup order assignment to be accepted.")

    server.tick(0.0)
    server.tick(3.0)
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(party.current_node_id == "raciborz", "Expected merchant party to arrive at Raciborz.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_COMPLETED, "Expected order to be completed after arrival.")
    _expect(_event_types(server).has("party_order_completed"), "Expected order completed event.")


func _test_save_load_preserves_party_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(result.accepted, "Expected setup order assignment to be accepted.")

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save with assigned order to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_party: RefCounted = loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(loaded_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO, "Expected loaded order type.")
    _expect(loaded_party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED, "Expected loaded order status.")
    _expect(loaded_party.order.issued_by_actor_id == "merchant_miroslaw", "Expected loaded issuing actor.")
    _expect(loaded_party.order.target_node_id == "raciborz", "Expected loaded target node.")


func _create_order_command(party_id: String, issued_by_actor_id: String, target_node_id: String) -> RefCounted:
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.issued_by_actor_id = issued_by_actor_id
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO
    command.target_node_id = target_node_id
    return command


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
