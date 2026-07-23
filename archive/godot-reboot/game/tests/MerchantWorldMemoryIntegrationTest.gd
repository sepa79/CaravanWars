extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MERCHANT_FOOD_MANAGER_SCRIPT: GDScript = preload("res://simulation/managers/MerchantFoodManager.gd")
const WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryDomainEventSink.gd")
const WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryQueuedHttpTransport.gd")

var _is_finished: bool = false
var _failed: bool = false
var _transport: RefCounted = null
var _domain_event_sink: RefCounted = null
var _poll_frames: int = 0


func _initialize() -> void:
    _start_merchant_world_memory_export()


func _process(_delta: float) -> bool:
    if not _is_finished and _transport != null:
        _transport.process_queue()
        _poll_frames += 1
        if not _transport.has_pending_work():
            _finish_merchant_world_memory_export()
        elif _poll_frames > 600:
            _expect(false, "Expected queued WorldMemory transport to drain.")
            _finish_merchant_world_memory_export()

    if _failed:
        assert(false, "Merchant WorldMemory integration test failed.")
    return _is_finished


func _start_merchant_world_memory_export() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var manager: RefCounted = MERCHANT_FOOD_MANAGER_SCRIPT.new()
    _transport = WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT.new()
    _transport.configure(_world_memory_host(), _world_memory_port(), "/domain-events/ingest", false)
    _domain_event_sink = WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT.new()
    _domain_event_sink.configure(_transport)
    server.add_event_sink(_domain_event_sink)

    var merchant: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var opole: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID)
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    merchant.cargo.clear()
    opole.resources["food"] = 140
    wroclaw.resources["food"] = 0

    for _day_index: int in range(5):
        manager.process(server, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
        server.tick(1.0)

    _expect(not _domain_event_sink.has_failures(), "Expected WorldMemory sink to queue all merchant events.")
    _expect(_domain_event_sink.exported_payloads.size() >= 4, "Expected merchant scenario to export multiple domain events.")
    _expect(_has_exported_event(_domain_event_sink, "goods_transferred"), "Expected goods transfer to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "party_travel_started"), "Expected travel start to be exported.")
    _expect(_has_exported_event(_domain_event_sink, "party_arrived"), "Expected arrival to be exported.")


func _finish_merchant_world_memory_export() -> void:
    _expect(not _transport.has_failures(), "Expected queued WorldMemory transport to finish without failures.")
    _expect(_transport.completed_results.size() == _domain_event_sink.exported_payloads.size(), "Expected every exported payload to be acknowledged.")
    if not _failed:
        print("[MerchantWorldMemoryIntegrationTest] OK")
    _is_finished = true


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
