extends MainLoop

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const CANCEL_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/CancelPartyOrderCommand.gd")
const INTERRUPT_TRAVEL_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InterruptTravelCommand.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const REPLACE_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/ReplacePartyOrderCommand.gd")
const SIMULATION_SAVE_CODEC_SCRIPT: GDScript = preload("res://simulation/SimulationSaveCodec.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_manager_can_assign_travel_order()
    _test_non_manager_cannot_assign_order()
    _test_order_starts_travel_intent_on_tick()
    _test_order_completes_after_arrival()
    _test_manager_can_cancel_assigned_order()
    _test_cancelled_order_allows_new_order()
    _test_cannot_cancel_traveling_order_without_interrupt_model()
    _test_manager_can_replace_assigned_order()
    _test_cannot_replace_traveling_order_without_interrupt()
    _test_manager_can_interrupt_traveling_order()
    _test_mayor_can_assign_supply_procurement_intent()
    _test_non_authorized_actor_cannot_assign_supply_procurement()
    _test_mayor_cannot_assign_remote_supply_procurement_without_delivery()
    _test_save_load_preserves_party_order()
    _test_save_load_preserves_supply_procurement_order()

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


func _test_manager_can_cancel_assigned_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    var cancel_result: RefCounted = server.submit_cancel_party_order(_create_cancel_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "changed_trade_plan"
    ))
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(cancel_result.accepted, "Expected manager to cancel assigned order.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_CANCELLED, "Expected cancelled order status.")
    _expect(party.order.cancel_reason == "changed_trade_plan", "Expected explicit cancel reason.")
    _expect(_event_types(server).has("party_order_cancelled"), "Expected order cancelled event.")


func _test_cancelled_order_allows_new_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    var cancel_result: RefCounted = server.submit_cancel_party_order(_create_cancel_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "manager_changed_destination"
    ))
    _expect(cancel_result.accepted, "Expected setup cancellation to be accepted.")

    var new_order_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "opole"
    ))
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(new_order_result.accepted, "Expected cancelled order to allow new assignment.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED, "Expected new order assigned status.")
    _expect(party.order.target_node_id == "opole", "Expected new order target.")


func _test_cannot_cancel_traveling_order_without_interrupt_model() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    server.tick(0.0)
    var cancel_result: RefCounted = server.submit_cancel_party_order(_create_cancel_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "changed_trade_plan"
    ))
    _expect(not cancel_result.accepted, "Expected active travel cancellation to be rejected until interrupt semantics exist.")
    _expect(cancel_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_INTERRUPT_UNSUPPORTED, "Expected order_interrupt_unsupported.")


func _test_manager_can_replace_assigned_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    var replace_command: RefCounted = REPLACE_PARTY_ORDER_COMMAND_SCRIPT.new()
    replace_command.party_id = GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID
    replace_command.issued_by_actor_id = "merchant_miroslaw"
    replace_command.reason = "better_market_information"
    replace_command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO
    replace_command.target_node_id = "opole"
    var replace_result: RefCounted = server.submit_replace_party_order(replace_command)
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(replace_result.accepted, "Expected manager to replace assigned order.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED, "Expected replacement order to be assigned.")
    _expect(party.order.target_node_id == "opole", "Expected replacement target.")
    _expect(_event_types(server).has("party_order_replaced"), "Expected order replaced event.")


func _test_cannot_replace_traveling_order_without_interrupt() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    server.tick(0.0)
    var replace_command: RefCounted = REPLACE_PARTY_ORDER_COMMAND_SCRIPT.new()
    replace_command.party_id = GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID
    replace_command.issued_by_actor_id = "merchant_miroslaw"
    replace_command.reason = "better_market_information"
    replace_command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO
    replace_command.target_node_id = "opole"
    var replace_result: RefCounted = server.submit_replace_party_order(replace_command)
    _expect(not replace_result.accepted, "Expected traveling order replacement to be rejected.")
    _expect(replace_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_INTERRUPT_UNSUPPORTED, "Expected order_interrupt_unsupported.")


func _test_manager_can_interrupt_traveling_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var assign_result: RefCounted = server.submit_assign_party_order(_create_order_command(
        GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID,
        "merchant_miroslaw",
        "raciborz"
    ))
    _expect(assign_result.accepted, "Expected setup order assignment to be accepted.")

    server.tick(0.0)
    var interrupt_command: RefCounted = INTERRUPT_TRAVEL_COMMAND_SCRIPT.new()
    interrupt_command.party_id = GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID
    interrupt_command.issued_by_actor_id = "merchant_miroslaw"
    interrupt_command.reason = "ambush_spotted"
    var interrupt_result: RefCounted = server.submit_interrupt_travel(interrupt_command)
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    _expect(interrupt_result.accepted, "Expected manager to interrupt active travel.")
    _expect(party.travel_state == "interrupted", "Expected interrupted travel state.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_INTERRUPTED, "Expected order interrupted status.")
    _expect(_event_types(server).has("party_travel_interrupted"), "Expected travel interrupted event.")
    _expect(_event_types(server).has("party_order_interrupted"), "Expected order interrupted event.")

    var interrupted_node_id: String = party.current_node_id
    server.tick(10.0)
    _expect(party.travel_state == "interrupted", "Expected interrupted party not to keep traveling.")
    _expect(party.current_node_id == interrupted_node_id, "Expected interrupted party not to arrive through tick.")


func _test_mayor_can_assign_supply_procurement_intent() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40

    var result: RefCounted = server.submit_assign_party_order(command)
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    _expect(result.accepted, "Expected mayor to assign supply procurement intent.")
    _expect(party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected procure_goods order type.")
    _expect(party.order.target_location_id == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected supply order target location.")
    _expect(party.order.goods_id == "food", "Expected supply order goods id.")
    _expect(party.order.amount == 40, "Expected supply order amount.")
    _expect(party.order.issued_by_actor_id == "mayor_wroclaw", "Expected mayor as issuing actor.")


func _test_non_authorized_actor_cannot_assign_supply_procurement() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "merchant_miroslaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40

    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(not result.accepted, "Expected unauthorized supply procurement assignment to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_NOT_AUTHORIZED, "Expected order_not_authorized.")


func _test_mayor_cannot_assign_remote_supply_procurement_without_delivery() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    party.current_node_id = "odra_crossing"

    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40

    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(not result.accepted, "Expected remote mayor supply procurement assignment to be rejected.")
    _expect(result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_ISSUER_NOT_PRESENT, "Expected order_issuer_not_present.")


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


func _test_save_load_preserves_supply_procurement_order() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected setup supply order assignment to be accepted.")

    var saved_dictionary: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.to_dictionary(server)
    var load_result: Dictionary = SIMULATION_SAVE_CODEC_SCRIPT.load_from_dictionary(saved_dictionary)
    _expect(bool(load_result.get("accepted", false)), "Expected save with supply order to load.")
    if not bool(load_result.get("accepted", false)):
        return

    var loaded_server: RefCounted = load_result.get("server")
    var loaded_party: RefCounted = loaded_server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    _expect(loaded_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected loaded supply order type.")
    _expect(loaded_party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED, "Expected loaded supply order status.")
    _expect(loaded_party.order.issued_by_actor_id == "mayor_wroclaw", "Expected loaded supply order issuing actor.")
    _expect(loaded_party.order.target_location_id == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected loaded supply order target location.")
    _expect(loaded_party.order.goods_id == "food", "Expected loaded supply order goods id.")
    _expect(loaded_party.order.amount == 40, "Expected loaded supply order amount.")


func _create_order_command(party_id: String, issued_by_actor_id: String, target_node_id: String) -> RefCounted:
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.issued_by_actor_id = issued_by_actor_id
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO
    command.target_node_id = target_node_id
    return command


func _create_cancel_order_command(party_id: String, issued_by_actor_id: String, reason: String) -> RefCounted:
    var command: RefCounted = CANCEL_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.issued_by_actor_id = issued_by_actor_id
    command.reason = reason
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
