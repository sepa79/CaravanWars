extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MAYOR_SUPPLY_PLANNER_SCRIPT: GDScript = preload("res://simulation/managers/MayorSupplyPlanner.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")

const SECOND_WROCLAW_SUPPLY_PARTY_ID: String = "wroclaw_supply_party_02"

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_mayor_assigns_supply_order_from_need_memory()
    _test_mayor_includes_fresh_source_report_status()
    _test_mayor_marks_stale_source_report_as_stale()
    _test_mayor_does_not_duplicate_active_supply_intent()
    _test_mayor_ignores_completed_supply_intent()
    _test_mayor_ignores_stale_active_supply_intent()
    _test_mayor_selects_available_supply_party_from_candidates()
    _test_mayor_does_not_assign_second_candidate_when_intent_exists()
    _test_mayor_does_not_assign_second_candidate_when_candidate_order_exists()
    _test_mayor_does_not_assign_when_supply_party_away()

    if not _failed:
        print("[MayorSupplyPlannerTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Mayor supply planner test failed.")
    return _is_finished


func _test_mayor_assigns_supply_order_from_need_memory() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory()]
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected mayor supply planner action to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected mayor to assign supply order.")
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected procure goods order.")
    _expect(supply_party.order.target_location_id == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected Wroclaw target location.")
    _expect(supply_party.order.goods_id == "food", "Expected food order.")
    _expect(supply_party.order.amount == 40, "Expected need amount order.")
    _expect(supply_party.order.issued_by_actor_id == "mayor_wroclaw", "Expected mayor as issuing actor.")
    _expect(bool(result.get("intent_declared", false)), "Expected planner result to report declared supply intent.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 1, "Expected one mayor supply intent event.")
    _expect(_event_count_by_type(server, "party_order_assigned") == 1, "Expected one party order event.")


func _test_mayor_includes_fresh_source_report_status() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 10.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory(), _mayor_heard_source_report_at_day(8.0)]
    )

    _expect(bool(result.get("accepted", false)), "Expected mayor supply planner action with fresh source to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected mayor to assign supply order with fresh source report.")
    _expect(result.get("source_report_status", "") == "fresh", "Expected fresh source report status.")
    var known_sources: Array = result.get("known_source_locations", [])
    _expect(not known_sources.is_empty(), "Expected known source locations in planner result.")


func _test_mayor_marks_stale_source_report_as_stale() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 200.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory(), _mayor_heard_source_report_at_day(1.0)]
    )

    _expect(bool(result.get("accepted", false)), "Expected mayor supply planner action with stale source to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected mayor to still assign broad procurement order.")
    _expect(result.get("source_report_status", "") == "stale", "Expected stale source report status.")
    var known_sources: Array = result.get("known_source_locations", [])
    _expect(known_sources.is_empty(), "Expected stale source report not to be used as actionable source list.")


func _test_mayor_does_not_duplicate_active_supply_intent() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory(), _active_supply_order_memory()]
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected no-action duplicate result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action when active supply intent exists.")
    _expect(result.get("reason", "") == "supply_intent_already_active", "Expected duplicate supply intent reason.")
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected no duplicate order assigned.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 0, "Expected no new supply intent when active intent exists.")


func _test_mayor_ignores_completed_supply_intent() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 3.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory(), _active_supply_order_memory_at_day(1.0), _completed_supply_order_memory_at_day(2.0)]
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected completed intent result to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected completed previous intent not to block a still-open need.")
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected new supply order after completed previous intent.")


func _test_mayor_does_not_assign_when_supply_party_away() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    supply_party.current_node_id = "odra_crossing"
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory()]
    )

    _expect(bool(result.get("accepted", false)), "Expected no-action away result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action when supply party is away.")
    _expect(result.get("reason", "") == "no_present_supply_party", "Expected no present supply party reason.")
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected no remote order assigned.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 0, "Expected no supply intent event when party is away.")

    var direct_result: RefCounted = server.submit_assign_party_order(_direct_procure_order())
    _expect(not direct_result.accepted, "Expected direct remote order to be rejected too.")
    _expect(direct_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_ISSUER_NOT_PRESENT, "Expected order issuer not present rejection.")


func _test_mayor_ignores_stale_active_supply_intent() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.current_day = 200.0
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()

    var result: Dictionary = planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_wroclaw_food_need_memory(), _active_supply_order_memory_at_day(1.0)]
    )
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)

    _expect(bool(result.get("accepted", false)), "Expected mayor to ignore stale active intent.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected stale active intent not to block new order.")
    _expect(supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected new supply order after stale intent.")


func _test_mayor_selects_available_supply_party_from_candidates() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _add_second_wroclaw_supply_party(server)
    var first_supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var second_supply_party: RefCounted = server.state.get_party(SECOND_WROCLAW_SUPPLY_PARTY_ID)
    first_supply_party.current_node_id = "odra_crossing"
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()
    var supply_party_ids: Array[String] = [GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, SECOND_WROCLAW_SUPPLY_PARTY_ID]

    var result: Dictionary = planner.process_candidates(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        supply_party_ids,
        [_wroclaw_food_need_memory()]
    )

    _expect(bool(result.get("accepted", false)), "Expected multi-party planner result to be accepted.")
    _expect(result.get("action", "") == "assign_supply_order", "Expected planner to assign an available supply party.")
    _expect(result.get("selected_party_id", "") == SECOND_WROCLAW_SUPPLY_PARTY_ID, "Expected planner to select second supply party.")
    _expect(first_supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected away first supply party to remain idle.")
    _expect(second_supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected second supply party to receive order.")
    var skipped_parties: Array = result.get("skipped_parties", [])
    _expect(skipped_parties.size() == 1, "Expected one skipped party.")
    _expect(str(skipped_parties[0].get("reason", "")) == "no_present_supply_party", "Expected away party skip reason.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 1, "Expected one mayor intent event for selected party.")
    _expect(_event_count_by_type(server, "party_order_assigned") == 1, "Expected one party order event for selected party.")


func _test_mayor_does_not_assign_second_candidate_when_intent_exists() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _add_second_wroclaw_supply_party(server)
    var first_supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var second_supply_party: RefCounted = server.state.get_party(SECOND_WROCLAW_SUPPLY_PARTY_ID)
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()
    var supply_party_ids: Array[String] = [GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, SECOND_WROCLAW_SUPPLY_PARTY_ID]

    var result: Dictionary = planner.process_candidates(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        supply_party_ids,
        [_wroclaw_food_need_memory(), _active_mayor_supply_intent_memory()]
    )

    _expect(bool(result.get("accepted", false)), "Expected active intent multi-party result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action when active intent already exists.")
    _expect(result.get("reason", "") == "supply_intent_already_active", "Expected active intent to block all candidates.")
    _expect(first_supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected first supply party to remain idle.")
    _expect(second_supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected second supply party to remain idle.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 0, "Expected no extra intent when active intent exists.")


func _test_mayor_does_not_assign_second_candidate_when_candidate_order_exists() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _add_second_wroclaw_supply_party(server)
    var first_supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    var second_supply_party: RefCounted = server.state.get_party(SECOND_WROCLAW_SUPPLY_PARTY_ID)
    first_supply_party.order.assign_procure_goods(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "food", 40, "mayor_wroclaw")
    var planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()
    var supply_party_ids: Array[String] = [GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, SECOND_WROCLAW_SUPPLY_PARTY_ID]

    var result: Dictionary = planner.process_candidates(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        supply_party_ids,
        [_wroclaw_food_need_memory()]
    )

    _expect(bool(result.get("accepted", false)), "Expected active candidate order result to be accepted.")
    _expect(result.get("action", "") == "none", "Expected no action when candidate already has matching order.")
    _expect(result.get("reason", "") == "candidate_supply_order_already_active", "Expected candidate order to block extra supply party.")
    _expect(second_supply_party.order.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_IDLE, "Expected second supply party to remain idle.")
    _expect(_event_count_by_type(server, "mayor_supply_intent_declared") == 0, "Expected no extra intent when candidate order exists.")


func _wroclaw_food_need_memory() -> Dictionary:
    return {
        "id": "mem_wroclaw_food_need",
        "kind": "need_ledger",
        "metadata": {
            "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "occurred_day": 0.0,
            "node_id": "wroclaw",
            "goods_id": "food",
            "needed_amount": 40,
            "reason": "food_below_floor"
        }
    }


func _active_supply_order_memory() -> Dictionary:
    return _active_supply_order_memory_at_day(0.0)


func _active_supply_order_memory_at_day(occurred_day: float) -> Dictionary:
    return {
        "id": "mem_mayor_active_supply_order",
        "kind": "order_ledger",
        "heard_at_time": "day:%0.3f" % occurred_day,
        "metadata": {
            "party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "occurred_day": occurred_day,
            "issued_by_actor_id": "mayor_wroclaw",
            "order_type": PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS,
            "target_location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "goods_id": "food",
            "amount": 40,
            "status": "assigned"
        }
    }


func _completed_supply_order_memory_at_day(occurred_day: float) -> Dictionary:
    var memory: Dictionary = _active_supply_order_memory_at_day(occurred_day)
    memory["id"] = "mem_mayor_completed_supply_order"
    var metadata: Dictionary = memory.get("metadata", {})
    metadata["status"] = "completed"
    memory["metadata"] = metadata
    return memory


func _active_mayor_supply_intent_memory() -> Dictionary:
    return {
        "id": "mem_mayor_supply_intent",
        "kind": "mayor_supply_intent",
        "heard_at_time": "day:0.000",
        "metadata": {
            "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "target_location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "supply_party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "issued_by_actor_id": "mayor_wroclaw",
            "goods_id": "food",
            "amount": 40,
            "status": "active",
            "occurred_day": 0.0
        }
    }


func _mayor_heard_source_report_at_day(occurred_day: float) -> Dictionary:
    return {
        "id": "mem_mayor_source_report",
        "kind": "heard_report",
        "heard_at_time": "day:%0.3f" % occurred_day,
        "metadata": {
            "party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "occurred_day": occurred_day,
            "query_type": "goods_source",
            "goods_id": "food",
            "delivery_kind": "report",
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


func _direct_procure_order() -> RefCounted:
    var command: RefCounted = preload("res://simulation/commands/AssignPartyOrderCommand.gd").new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    return command


func _add_second_wroclaw_supply_party(server: RefCounted) -> void:
    var party: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_wroclaw_supply_party()
    party.party_id = SECOND_WROCLAW_SUPPLY_PARTY_ID
    party.manager_actor_id = "quartermaster_wroclaw_second"
    party.order = PARTY_ORDER_STATE_SCRIPT.new()
    party.task = preload("res://simulation/PartyTaskState.gd").new()
    server.state.add_party(party)


func _event_count_by_type(server: RefCounted, event_type: String) -> int:
    var event_count: int = 0
    for event_dictionary: Dictionary in server.get_recent_events(20):
        if str(event_dictionary.get("event_type", "")) == event_type:
            event_count += 1
    return event_count


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
