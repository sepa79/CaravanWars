extends MainLoop

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const QUARTERMASTER_AI_SCRIPT: GDScript = preload("res://simulation/managers/QuartermasterAI.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_quartermaster_travels_to_remembered_source()
    _test_quartermaster_ignores_stale_source_memory()
    _test_quartermaster_asks_local_information_without_source_memory()
    _test_quartermaster_uses_local_information_memory_as_source()
    _test_quartermaster_withdraws_and_returns_to_target()
    _test_quartermaster_deposits_and_completes_order()
    _test_quartermaster_does_nothing_without_order_memory()

    if not _failed:
        print("[QuartermasterAITest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Quartermaster AI test failed.")
    return _is_finished


func _test_quartermaster_travels_to_remembered_source() -> void:
    var server: RefCounted = _server_with_supply_order()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, _quartermaster_memory_entries())

    _expect(bool(result.get("accepted", false)), "Expected quartermaster action to be accepted.")
    _expect(result.get("action", "") == "travel_to_remembered_supply_source", "Expected travel to remembered source, got %s." % str(result))
    _expect(party.travel_state == "traveling", "Expected supply party to start travel.")
    _expect(party.travel_intent_destination_node_id == "opole", "Expected supply party to set Opole source as travel intent.")
    _expect(party.destination_node_id == "opole", "Expected supply party first leg to go to Opole.")


func _test_quartermaster_ignores_stale_source_memory() -> void:
    var server: RefCounted = _server_with_supply_order()
    server.current_day = 200.0
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, [_order_memory(), _opole_source_memory_at_day(1.0)])

    _expect(bool(result.get("accepted", false)), "Expected stale source fallback action to be accepted.")
    _expect(result.get("action", "") == "ask_local_information", "Expected stale source memory to trigger fresh local information.")
    _expect(party.travel_state == "idle", "Expected stale source not to start travel.")


func _test_quartermaster_asks_local_information_without_source_memory() -> void:
    var server: RefCounted = _server_with_supply_order()
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, [_order_memory()])

    _expect(bool(result.get("accepted", false)), "Expected local information action to be accepted.")
    _expect(result.get("action", "") == "ask_local_information", "Expected quartermaster to ask local information.")
    _expect(_event_types(server).has("party_task_started"), "Expected local information task to start.")
    _expect(not _event_types(server).has("worldsim_local_information_received"), "Expected no local information before task completes.")
    server.tick(0.25)
    _expect(_event_types(server).has("worldsim_local_information_received"), "Expected local information event after task duration.")


func _test_quartermaster_uses_local_information_memory_as_source() -> void:
    var server: RefCounted = _server_with_supply_order()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, [_order_memory(), _local_food_source_memory()])

    _expect(bool(result.get("accepted", false)), "Expected local information source action to be accepted.")
    _expect(result.get("action", "") == "travel_to_remembered_supply_source", "Expected travel to source from local information memory.")
    _expect(party.travel_intent_destination_node_id == "opole", "Expected Opole as source travel intent.")


func _test_quartermaster_withdraws_and_returns_to_target() -> void:
    var server: RefCounted = _server_with_supply_order()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var opole: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    party.current_node_id = "opole"
    party.cargo.clear()
    party.cargo["coin"] = 60
    opole.resources["food"] = 90

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, _quartermaster_memory_entries())

    _expect(bool(result.get("accepted", false)), "Expected withdraw and return action to be accepted.")
    _expect(result.get("action", "") == "withdraw_and_return_to_supply_target", "Expected withdraw then return action, got %s." % str(result))
    _expect(int(party.cargo.get("food", 0)) == 40, "Expected supply party to withdraw ordered food amount, got %s." % int(party.cargo.get("food", 0)))
    _expect(int(opole.resources.get("food", 0)) == 50, "Expected Opole food to decrease through command, got %s." % int(opole.resources.get("food", 0)))
    _expect(party.destination_node_id == "wroclaw", "Expected supply party to return to Wroclaw target.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_ACTIVE, "Expected supply order to become active.")


func _test_quartermaster_deposits_and_completes_order() -> void:
    var server: RefCounted = _server_with_supply_order()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    party.current_node_id = "wroclaw"
    party.cargo.clear()
    party.cargo["food"] = 40
    wroclaw.resources["food"] = 10
    party.order.mark_active()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, _quartermaster_memory_entries())

    _expect(bool(result.get("accepted", false)), "Expected deposit action to be accepted.")
    _expect(result.get("action", "") == "deposit_to_supply_target", "Expected deposit to supply target.")
    _expect(int(party.cargo.get("food", 0)) == 0, "Expected supply party food cargo to be deposited.")
    _expect(int(wroclaw.resources.get("food", 0)) == 50, "Expected Wroclaw food to increase through command.")
    _expect(party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_COMPLETED, "Expected supply order to complete.")
    _expect(_event_types(server).has("party_order_completed"), "Expected completed procure order event.")


func _test_quartermaster_does_nothing_without_order_memory() -> void:
    var server: RefCounted = _server_with_supply_order()
    var party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()

    var result: Dictionary = ai.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, [_opole_source_memory()])

    _expect(bool(result.get("accepted", false)), "Expected no-action result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action without order memory.")
    _expect(result.get("reason", "") == "no_order_memory", "Expected no order memory reason.")
    _expect(party.travel_state == "idle", "Expected supply party to remain idle.")


func _server_with_supply_order() -> RefCounted:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected supply order setup to be accepted.")
    return server


func _quartermaster_memory_entries() -> Array[Dictionary]:
    return [
        _order_memory(),
        _opole_source_memory()
    ]


func _order_memory() -> Dictionary:
    return {
        "id": "mem_wroclaw_supply_party_order",
        "kind": "order_ledger",
        "metadata": {
            "party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "manager_actor_id": "quartermaster_wroclaw",
            "issued_by_actor_id": "mayor_wroclaw",
            "order_type": PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS,
            "target_location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "target_node_id": "wroclaw",
            "goods_id": "food",
            "amount": 40
        }
    }


func _opole_source_memory() -> Dictionary:
    return _opole_source_memory_at_day(0.0)


func _opole_source_memory_at_day(observed_day: float) -> Dictionary:
    return {
        "id": "mem_wroclaw_supply_party_observed_opole",
        "kind": "location_observation",
        "heard_at_time": "day:%0.3f" % observed_day,
        "metadata": {
            "owner_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "occurred_day": observed_day,
            "node_id": "opole",
            "observed_location_id": GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID,
            "observed_resources": {
                "food": 90
            }
        }
    }


func _local_food_source_memory() -> Dictionary:
    return {
        "id": "mem_wroclaw_supply_party_local_food_info",
        "kind": "local_information",
        "heard_at_time": "day:0.000",
        "metadata": {
            "party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "occurred_day": 0.0,
            "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "node_id": "wroclaw",
            "query_type": "goods_source",
            "goods_id": "food",
            "known_source_locations": [
                {
                    "location_id": GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID,
                    "node_id": "opole",
                    "goods_id": "food",
                    "observed_amount": 90
                }
            ]
        }
    }


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
