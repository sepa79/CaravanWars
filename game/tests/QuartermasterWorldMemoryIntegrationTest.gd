extends MainLoop

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const QUARTERMASTER_AI_SCRIPT: GDScript = preload("res://simulation/managers/QuartermasterAI.gd")
const REPORT_BACK_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/ReportBackCommand.gd")
const WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryDomainEventSink.gd")
const WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryQueuedHttpTransport.gd")

var _is_finished: bool = false
var _failed: bool = false
var _transport: RefCounted = null
var _domain_event_sink: RefCounted = null
var _poll_frames: int = 0


func _initialize() -> void:
    _start_quartermaster_world_memory_export()


func _process(_delta: float) -> bool:
    if not _is_finished and _transport != null:
        _transport.process_queue()
        _poll_frames += 1
        if not _transport.has_pending_work():
            _finish_quartermaster_world_memory_export()
        elif _poll_frames > 600:
            _expect(false, "Expected queued WorldMemory transport to drain.")
            _finish_quartermaster_world_memory_export()

    if _failed:
        assert(false, "Quartermaster WorldMemory integration test failed.")
    return _is_finished


func _start_quartermaster_world_memory_export() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _transport = WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT.new()
    _transport.configure(_world_memory_host(), _world_memory_port(), "/domain-events/ingest", false)
    _domain_event_sink = WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT.new()
    _domain_event_sink.configure(_transport)
    server.add_event_sink(_domain_event_sink)

    var order_result: RefCounted = server.submit_assign_party_order(_supply_order_command())
    _expect(order_result.accepted, "Expected setup supply order to be accepted.")

    var ai: RefCounted = QUARTERMASTER_AI_SCRIPT.new()
    var ai_result: Dictionary = ai.process(
        server,
        GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID,
        [_order_memory()]
    )

    _expect(bool(ai_result.get("accepted", false)), "Expected QuartermasterAI to ask local information.")
    _expect(ai_result.get("action", "") == "ask_local_information", "Expected ask local information action.")
    server.tick(0.25)
    var report_result: RefCounted = server.submit_report_back(_report_back_command())
    _expect(report_result.accepted, "Expected report back task to be accepted.")
    server.tick(0.10)
    _expect(_has_exported_event(_domain_event_sink, "party_order_assigned"), "Expected order assignment to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "party_task_started"), "Expected local information task start to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "party_task_completed"), "Expected local information task completion to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "worldsim_local_information_received"), "Expected local information event to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "worldsim_memory_reported"), "Expected report back event to be exported.")
    _expect(not _domain_event_sink.has_failures(), "Expected WorldMemory sink to queue all quartermaster events.")


func _finish_quartermaster_world_memory_export() -> void:
    _expect(not _transport.has_failures(), "Expected queued WorldMemory transport to finish without failures.")
    _expect(_transport.completed_results.size() == _domain_event_sink.exported_payloads.size(), "Expected every exported payload to be acknowledged.")
    if not _failed:
        print("[QuartermasterWorldMemoryIntegrationTest] OK")
    _is_finished = true


func _supply_order_command() -> RefCounted:
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    return command


func _report_back_command() -> RefCounted:
    var command: RefCounted = REPORT_BACK_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.actor_id = "quartermaster_wroclaw"
    command.recipient_actor_id = "mayor_wroclaw"
    command.recipient_owner_kind = "actor"
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.max_entries = 3
    command.trust = 0.9
    command.distortion_noise = 0.02
    command.listener_interest_tags.append("food")
    command.listener_interest_tags.append(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    command.notes = "Supply party report back"
    return command


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


func _has_exported_event(domain_event_sink: RefCounted, event_type: String) -> bool:
    for export_payload: Dictionary in domain_event_sink.exported_payloads:
        var world_event: Dictionary = export_payload.get("world_event", {})
        if str(world_event.get("event_type", "")) == event_type:
            return true
    return false


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
