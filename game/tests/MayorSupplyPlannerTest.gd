extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MAYOR_SUPPLY_PLANNER_SCRIPT: GDScript = preload("res://simulation/managers/MayorSupplyPlanner.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const SIMULATION_SERVER_SCRIPT: GDScript = preload("res://simulation/SimulationServer.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_mayor_assigns_supply_order_from_need_memory()
    _test_mayor_does_not_duplicate_active_supply_intent()
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

    var direct_result: RefCounted = server.submit_assign_party_order(_direct_procure_order())
    _expect(not direct_result.accepted, "Expected direct remote order to be rejected too.")
    _expect(direct_result.error_code == SIMULATION_SERVER_SCRIPT.ERROR_ORDER_ISSUER_NOT_PRESENT, "Expected order issuer not present rejection.")


func _wroclaw_food_need_memory() -> Dictionary:
    return {
        "id": "mem_wroclaw_food_need",
        "kind": "need_ledger",
        "metadata": {
            "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "node_id": "wroclaw",
            "goods_id": "food",
            "needed_amount": 40,
            "reason": "food_below_floor"
        }
    }


func _active_supply_order_memory() -> Dictionary:
    return {
        "id": "mem_mayor_active_supply_order",
        "kind": "order_ledger",
        "metadata": {
            "party_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "issued_by_actor_id": "mayor_wroclaw",
            "order_type": PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS,
            "target_location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "goods_id": "food",
            "amount": 40,
            "status": "assigned"
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


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
