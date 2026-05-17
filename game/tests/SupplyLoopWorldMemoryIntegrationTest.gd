extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MAYOR_FOOD_MANAGER_SCRIPT: GDScript = preload("res://simulation/managers/MayorFoodManager.gd")
const MAYOR_SUPPLY_PLANNER_SCRIPT: GDScript = preload("res://simulation/managers/MayorSupplyPlanner.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const QUARTERMASTER_AI_SCRIPT: GDScript = preload("res://simulation/managers/QuartermasterAI.gd")
const WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryDomainEventSink.gd")
const WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryQueuedHttpTransport.gd")

var _is_finished: bool = false
var _failed: bool = false
var _transport: RefCounted = null
var _domain_event_sink: RefCounted = null
var _poll_frames: int = 0


func _initialize() -> void:
    _run_supply_loop()


func _process(_delta: float) -> bool:
    if not _is_finished and _transport != null:
        _transport.process_queue()
        _poll_frames += 1
        if not _transport.has_pending_work():
            _finish_export()
        elif _poll_frames > 900:
            _expect(false, "Expected queued WorldMemory transport to drain.")
            _finish_export()

    if _failed:
        assert(false, "Supply loop WorldMemory integration test failed.")
    return _is_finished


func _run_supply_loop() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _transport = WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT.new()
    _transport.configure(_world_memory_host(), _world_memory_port(), "/domain-events/ingest", false)
    _domain_event_sink = WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT.new()
    _domain_event_sink.configure(_transport)
    server.add_event_sink(_domain_event_sink)

    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    var opole: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID)
    var supply_party: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID)
    wroclaw.resources["food"] = 10
    opole.resources["food"] = 100
    supply_party.composition.wagon_count = 3

    var mayor_food_manager: RefCounted = MAYOR_FOOD_MANAGER_SCRIPT.new()
    var need_result: Dictionary = mayor_food_manager.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    _expect(need_result.get("action", "") == "declare_food_need", "Expected mayor to declare food need.")

    var mayor_planner: RefCounted = MAYOR_SUPPLY_PLANNER_SCRIPT.new()
    var planner_result: Dictionary = mayor_planner.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_need_memory_from_result(need_result)]
    )
    _expect(planner_result.get("action", "") == "assign_supply_order", "Expected mayor planner to assign supply order. Result: %s." % str(planner_result))
    _expect(int(planner_result.get("amount", 0)) == 70, "Expected supply order to cover declared need amount.")

    var quartermaster: RefCounted = QUARTERMASTER_AI_SCRIPT.new()
    var quartermaster_memory: Array[Dictionary] = [_order_memory_from_party(supply_party), _opole_source_memory()]
    var travel_to_source_result: Dictionary = quartermaster.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, quartermaster_memory)
    _expect(travel_to_source_result.get("action", "") == "travel_to_remembered_supply_source", "Expected quartermaster to travel to source. Result: %s." % str(travel_to_source_result))

    server.tick(4.0)
    _expect(supply_party.current_node_id == "opole", "Expected supply party to arrive at Opole.")

    var withdraw_result: Dictionary = quartermaster.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, quartermaster_memory)
    _expect(withdraw_result.get("action", "") == "withdraw_and_return_to_supply_target", "Expected quartermaster to withdraw and return. Result: %s." % str(withdraw_result))
    _expect(int(supply_party.cargo.get("food", 0)) == 70, "Expected supply party to carry ordered food.")

    server.tick(4.0)
    _expect(supply_party.current_node_id == "wroclaw", "Expected supply party to return to Wroclaw.")

    var deposit_result: Dictionary = quartermaster.process(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, quartermaster_memory)
    _expect(deposit_result.get("action", "") == "deposit_to_supply_target", "Expected quartermaster to deposit at target. Result: %s." % str(deposit_result))
    _expect(supply_party.order.status == PARTY_ORDER_STATE_SCRIPT.STATUS_COMPLETED, "Expected supply order to complete.")
    _expect(int(supply_party.cargo.get("food", 0)) == 0, "Expected supply party to unload food.")
    _expect(int(wroclaw.resources.get("food", 0)) >= 70, "Expected Wroclaw to receive food.")

    _expect(_has_exported_event("location_need_declared"), "Expected exported location need event.")
    _expect(_has_exported_event("mayor_supply_intent_declared"), "Expected exported mayor supply intent event.")
    _expect(_has_exported_event("party_order_assigned"), "Expected exported party order assignment.")
    _expect(_has_exported_event("goods_transferred"), "Expected exported goods transfer events.")
    _expect(_has_exported_event("party_order_completed"), "Expected exported party order completion.")
    _expect(not _domain_event_sink.has_failures(), "Expected WorldMemory sink to queue all supply loop events.")


func _finish_export() -> void:
    _expect(not _transport.has_failures(), "Expected queued WorldMemory transport to finish without failures.")
    _expect(_transport.completed_results.size() == _domain_event_sink.exported_payloads.size(), "Expected every exported payload to be acknowledged.")
    if not _failed:
        print("[SupplyLoopWorldMemoryIntegrationTest] OK")
    _is_finished = true


func _need_memory_from_result(need_result: Dictionary) -> Dictionary:
    var current_amount: int = int(need_result.get("current_amount", 0))
    var desired_amount: int = int(need_result.get("desired_amount", 0))
    return {
        "id": "mem_wroclaw_food_need_scenario",
        "kind": "need_ledger",
        "heard_at_time": "day:0.000",
        "metadata": {
            "location_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID,
            "node_id": "wroclaw",
            "goods_id": "food",
            "current_amount": current_amount,
            "desired_amount": desired_amount,
            "needed_amount": desired_amount - current_amount,
            "reason": "food_below_floor",
            "occurred_day": 0.0
        }
    }


func _order_memory_from_party(party: RefCounted) -> Dictionary:
    return {
        "id": "mem_wroclaw_supply_party_order_scenario",
        "kind": "order_ledger",
        "heard_at_time": "day:0.000",
        "metadata": {
            "party_id": party.party_id,
            "manager_actor_id": party.manager_actor_id,
            "issued_by_actor_id": party.order.issued_by_actor_id,
            "order_type": party.order.order_type,
            "target_location_id": party.order.target_location_id,
            "target_node_id": "wroclaw",
            "goods_id": party.order.goods_id,
            "amount": party.order.amount,
            "status": party.order.status,
            "occurred_day": 0.0
        }
    }


func _opole_source_memory() -> Dictionary:
    return {
        "id": "mem_wroclaw_supply_party_observed_opole_scenario",
        "kind": "location_observation",
        "heard_at_time": "day:0.000",
        "metadata": {
            "owner_id": GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
            "occurred_day": 0.0,
            "node_id": "opole",
            "observed_location_id": GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID,
            "observed_resources": {
                "food": 100
            }
        }
    }


func _world_memory_host() -> String:
    var host: String = OS.get_environment("CW_WORLD_MEMORY_HOST")
    if host.is_empty():
        return "127.0.0.1"
    return host


func _world_memory_port() -> int:
    var port_text: String = OS.get_environment("CW_WORLD_MEMORY_PORT")
    if port_text.is_empty():
        return 8011
    return int(port_text)


func _has_exported_event(event_type: String) -> bool:
    for export_payload: Dictionary in _domain_event_sink.exported_payloads:
        var world_event: Dictionary = export_payload.get("world_event", {})
        if str(world_event.get("event_type", "")) == event_type:
            return true
    return false


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
