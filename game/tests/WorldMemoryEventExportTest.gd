extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const CANCEL_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/CancelPartyOrderCommand.gd")
const DECLARE_SUPPLY_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/DeclareSupplyIntentCommand.gd")
const INTERRUPT_TRAVEL_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InterruptTravelCommand.gd")
const INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InspectLocalRoutesCommand.gd")
const MOVE_PARTY_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/MovePartyCommand.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const TEST_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/TestSimulationEventSink.gd")
const TEST_WORLD_MEMORY_DOMAIN_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/TestWorldMemoryDomainTransport.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryDomainEventSink.gd")
const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")
const WORLD_MEMORY_HTTP_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryHttpTransport.gd")
const WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryQueuedHttpTransport.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_event_sink_receives_authoritative_events()
    _test_arrival_event_maps_to_world_event_payload()
    _test_local_route_inspection_exports_bounded_metadata()
    _test_goods_transfer_exports_trade_metadata()
    _test_party_order_exports_supply_intent_metadata()
    _test_completed_procure_order_exports_terminal_metadata()
    _test_cancelled_order_exports_terminal_metadata()
    _test_interrupted_order_exports_terminal_metadata()
    _test_mayor_supply_intent_exports_operational_metadata()
    _test_location_economy_exports_location_subject()
    _test_domain_event_sink_sends_exported_payload()
    _test_domain_event_sink_records_transport_failures()
    _test_http_transport_has_explicit_endpoint_configuration()
    _test_queued_http_transport_queues_without_blocking()
    _test_unknown_event_type_is_not_exported()

    if _failed:
        assert(false, "WorldMemory event export test failed.")
    else:
        print("[WorldMemoryEventExportTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    return _is_finished


func _test_event_sink_receives_authoritative_events() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var event_sink: RefCounted = TEST_EVENT_SINK_SCRIPT.new()
    server.add_event_sink(event_sink)

    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)

    _expect(result.accepted, "Expected local route inspection command to be accepted.")
    _expect(event_sink.event_types().has("party_local_routes_inspected"), "Expected event sink to receive local route inspection event.")


func _test_arrival_event_maps_to_world_event_payload() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = MOVE_PARTY_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.from_node_id = "wroclaw"
    command.to_node_id = "opole"
    var result: RefCounted = server.submit_move_party(command)
    _expect(result.accepted, "Expected setup move command to be accepted.")

    server.tick(4.0)
    var arrival_event: RefCounted = _event_by_type(server, "party_arrived")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(arrival_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(export_payload.get("export_kind", "") == "world_event", "Expected world event export kind.")
    _expect(world_event.get("event_type", "") == "party_arrived", "Expected party_arrived export event type.")
    _expect(world_event.get("location_id", "") == "opole", "Expected arrival location to be Opole.")
    _expect(metadata.get("party_id", "") == GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID, "Expected party id in metadata.")
    _expect(metadata.get("manager_actor_id", "") == "player_caravan_leader", "Expected manager actor id in metadata.")
    _expect(is_equal_approx(float(metadata.get("occurred_day", -1.0)), 4.0), "Expected occurred day in metadata.")


func _test_local_route_inspection_exports_bounded_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)
    _expect(result.accepted, "Expected local route inspection command to be accepted.")

    var inspection_event: RefCounted = _event_by_type(server, "party_local_routes_inspected")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(inspection_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("location_id", "") == "wroclaw", "Expected local inspection location to be current node.")
    _expect(metadata.has("discovered_edge_count"), "Expected discovered edge count metadata.")
    _expect(metadata.has("discovered_node_count"), "Expected discovered node count metadata.")
    _expect(not metadata.has("known_routes"), "Expected export to avoid full known route list.")
    _expect(not metadata.has("region_graph"), "Expected export to avoid full region graph.")


func _test_goods_transfer_exports_trade_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 1
    command.direction = TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    var result: RefCounted = server.submit_transfer_goods(command)
    _expect(result.accepted, "Expected setup goods transfer to be accepted.")

    var transfer_event: RefCounted = _event_by_type(server, "goods_transferred")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(transfer_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected transfer location id.")
    _expect(metadata.get("goods_id", "") == "food", "Expected goods id metadata.")
    _expect(int(metadata.get("amount", 0)) == 1, "Expected transfer amount metadata.")
    _expect(metadata.get("direction", "") == TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION, "Expected transfer direction metadata.")


func _test_party_order_exports_supply_intent_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected supply order assignment to be accepted.")

    var order_event: RefCounted = _event_by_type(server, "party_order_assigned")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(order_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected order target location as export location.")
    _expect(metadata.get("party_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected order recipient party id.")
    _expect(metadata.get("issued_by_actor_id", "") == "mayor_wroclaw", "Expected order issuer metadata.")
    _expect(metadata.get("manager_actor_id", "") == "quartermaster_wroclaw", "Expected order manager metadata.")
    _expect(metadata.get("order_type", "") == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected order type metadata.")
    _expect(metadata.get("target_location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected target location metadata.")
    _expect(metadata.get("target_node_id", "") == "wroclaw", "Expected target node metadata.")
    _expect(metadata.get("goods_id", "") == "food", "Expected goods id metadata.")
    _expect(int(metadata.get("amount", 0)) == 40, "Expected amount metadata.")


func _test_completed_procure_order_exports_terminal_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected supply order assignment to be accepted.")

    var completion_result: RefCounted = server.complete_procure_goods_order(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, 40)
    _expect(completion_result.accepted, "Expected procure order completion to be accepted.")

    var completion_event: RefCounted = _event_by_type(server, "party_order_completed")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(completion_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "party_order_completed", "Expected completed order export event type.")
    _expect(metadata.get("order_type", "") == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected completed order type metadata.")
    _expect(metadata.get("target_location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected completed order target metadata.")
    _expect(metadata.get("goods_id", "") == "food", "Expected completed order goods metadata.")
    _expect(int(metadata.get("delivered_amount", 0)) == 40, "Expected delivered amount metadata.")
    _expect(metadata.get("status", "") == PARTY_ORDER_STATE_SCRIPT.STATUS_COMPLETED, "Expected completed order status metadata.")


func _test_cancelled_order_exports_terminal_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.goods_id = "food"
    command.amount = 40
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected supply order assignment to be accepted.")

    var cancel_command: RefCounted = CANCEL_PARTY_ORDER_COMMAND_SCRIPT.new()
    cancel_command.party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    cancel_command.issued_by_actor_id = "mayor_wroclaw"
    cancel_command.reason = "city_stock_recovered"
    var cancel_result: RefCounted = server.submit_cancel_party_order(cancel_command)
    _expect(cancel_result.accepted, "Expected supply order cancellation to be accepted.")

    var cancel_event: RefCounted = _event_by_type(server, "party_order_cancelled")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(cancel_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "party_order_cancelled", "Expected cancelled order export event type.")
    _expect(metadata.get("order_type", "") == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS, "Expected cancelled order type metadata.")
    _expect(metadata.get("target_location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected cancelled order target metadata.")
    _expect(metadata.get("goods_id", "") == "food", "Expected cancelled order goods metadata.")
    _expect(metadata.get("status", "") == PARTY_ORDER_STATE_SCRIPT.STATUS_CANCELLED, "Expected cancelled order status metadata.")
    _expect(metadata.get("cancel_reason", "") == "city_stock_recovered", "Expected cancel reason metadata.")


func _test_interrupted_order_exports_terminal_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID
    command.issued_by_actor_id = "merchant_miroslaw"
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO
    command.target_node_id = "raciborz"
    var result: RefCounted = server.submit_assign_party_order(command)
    _expect(result.accepted, "Expected travel order assignment to be accepted.")

    server.tick(0.0)
    var interrupt_command: RefCounted = INTERRUPT_TRAVEL_COMMAND_SCRIPT.new()
    interrupt_command.party_id = GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID
    interrupt_command.issued_by_actor_id = "merchant_miroslaw"
    interrupt_command.reason = "ambush_spotted"
    var interrupt_result: RefCounted = server.submit_interrupt_travel(interrupt_command)
    _expect(interrupt_result.accepted, "Expected travel interruption to be accepted.")

    var order_event: RefCounted = _event_by_type(server, "party_order_interrupted")
    var order_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(order_event)
    var order_world_event: Dictionary = order_payload.get("world_event", {})
    var order_metadata: Dictionary = order_world_event.get("metadata", {})
    _expect(order_world_event.get("event_type", "") == "party_order_interrupted", "Expected interrupted order export event type.")
    _expect(order_metadata.get("status", "") == PARTY_ORDER_STATE_SCRIPT.STATUS_INTERRUPTED, "Expected interrupted order status metadata.")
    _expect(order_metadata.get("interrupt_reason", "") == "ambush_spotted", "Expected interrupt reason metadata.")

    var travel_event: RefCounted = _event_by_type(server, "party_travel_interrupted")
    var travel_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(travel_event)
    var travel_world_event: Dictionary = travel_payload.get("world_event", {})
    var travel_metadata: Dictionary = travel_world_event.get("metadata", {})
    _expect(travel_world_event.get("event_type", "") == "party_travel_interrupted", "Expected interrupted travel export event type.")
    _expect(travel_metadata.get("travel_state", "") == "interrupted", "Expected interrupted travel state metadata.")
    _expect(travel_metadata.has("progress_km"), "Expected interrupted travel progress metadata.")


func _test_mayor_supply_intent_exports_operational_metadata() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var command: RefCounted = DECLARE_SUPPLY_INTENT_COMMAND_SCRIPT.new()
    command.location_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID
    command.issued_by_actor_id = "mayor_wroclaw"
    command.supply_party_id = GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID
    command.goods_id = "food"
    command.amount = 40
    command.reason = "food_below_floor"
    var result: RefCounted = server.submit_declare_supply_intent(command)
    _expect(result.accepted, "Expected mayor supply intent declaration to be accepted.")

    var intent_event: RefCounted = _event_by_type(server, "mayor_supply_intent_declared")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(intent_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "mayor_supply_intent_declared", "Expected mayor supply intent export event type.")
    _expect(world_event.get("location_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID, "Expected mayor supply intent location.")
    _expect(metadata.get("party_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected event subject party id.")
    _expect(metadata.get("supply_party_id", "") == GAME_SESSION_FACTORY_SCRIPT.WROCLAW_SUPPLY_PARTY_ID, "Expected supply party id metadata.")
    _expect(metadata.get("issued_by_actor_id", "") == "mayor_wroclaw", "Expected issuer actor metadata.")
    _expect(metadata.get("supply_party_manager_actor_id", "") == "quartermaster_wroclaw", "Expected supply party manager metadata.")
    _expect(metadata.get("goods_id", "") == "food", "Expected goods id metadata.")
    _expect(int(metadata.get("amount", 0)) == 40, "Expected supply intent amount metadata.")
    _expect(metadata.get("status", "") == "active", "Expected active supply intent status metadata.")


func _test_location_economy_exports_location_subject() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    server.tick(1.0)

    var economy_event: RefCounted = _event_by_type(server, "location_economy_ticked")
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(economy_event)
    var world_event: Dictionary = export_payload.get("world_event", {})
    var metadata: Dictionary = world_event.get("metadata", {})

    _expect(world_event.get("event_type", "") == "location_economy_ticked", "Expected economy tick export event type.")
    _expect(str(world_event.get("id", "")).contains(str(world_event.get("location_id", ""))), "Expected economy event id to include location subject.")
    _expect(metadata.has("resource_changes"), "Expected economy event to export resource changes.")


func _test_domain_event_sink_sends_exported_payload() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var transport: RefCounted = TEST_WORLD_MEMORY_DOMAIN_TRANSPORT_SCRIPT.new()
    var domain_event_sink: RefCounted = WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT.new()
    domain_event_sink.configure(transport)
    server.add_event_sink(domain_event_sink)

    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)
    _expect(result.accepted, "Expected local route inspection command to be accepted.")

    _expect(transport.sent_payloads.size() == 1, "Expected WorldMemory transport to receive one payload.")
    var export_payload: Dictionary = transport.sent_payloads[0]
    var world_event: Dictionary = export_payload.get("world_event", {})
    _expect(export_payload.get("export_kind", "") == "world_event", "Expected domain sink to send world event payload.")
    _expect(world_event.get("event_type", "") == "party_local_routes_inspected", "Expected domain sink to send mapped event type.")
    _expect(not domain_event_sink.has_failures(), "Expected domain sink to have no failures.")


func _test_domain_event_sink_records_transport_failures() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var transport: RefCounted = TEST_WORLD_MEMORY_DOMAIN_TRANSPORT_SCRIPT.new()
    transport.fail_next_send = true
    var domain_event_sink: RefCounted = WORLD_MEMORY_DOMAIN_EVENT_SINK_SCRIPT.new()
    domain_event_sink.emit_godot_errors = false
    domain_event_sink.configure(transport)
    server.add_event_sink(domain_event_sink)

    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = GAME_SESSION_FACTORY_SCRIPT.PLAYER_PARTY_ID
    var result: RefCounted = server.submit_inspect_local_routes(command)
    _expect(result.accepted, "Expected local route inspection command to be accepted.")

    _expect(domain_event_sink.has_failures(), "Expected domain sink to record transport failure.")
    _expect(domain_event_sink.failed_exports[0].get("error_code", "") == "test_transport_failed", "Expected explicit transport failure code.")


func _test_http_transport_has_explicit_endpoint_configuration() -> void:
    var transport: RefCounted = WORLD_MEMORY_HTTP_TRANSPORT_SCRIPT.new()
    _expect(transport.host == "127.0.0.1", "Expected default WorldMemory host.")
    _expect(transport.port == 8011, "Expected default WorldMemory port.")
    _expect(transport.path == "/domain-events/ingest", "Expected default WorldMemory ingest path.")

    transport.configure("localhost", 9001, "/custom-ingest", false)
    _expect(transport.host == "localhost", "Expected configured WorldMemory host.")
    _expect(transport.port == 9001, "Expected configured WorldMemory port.")
    _expect(transport.path == "/custom-ingest", "Expected configured WorldMemory ingest path.")

    var empty_result: Dictionary = transport.send_domain_event({})
    _expect(not bool(empty_result.get("accepted", true)), "Expected empty payload to be rejected before HTTP.")
    _expect(empty_result.get("error_code", "") == "empty_payload", "Expected explicit empty payload error.")


func _test_queued_http_transport_queues_without_blocking() -> void:
    var transport: RefCounted = WORLD_MEMORY_QUEUED_HTTP_TRANSPORT_SCRIPT.new()
    transport.configure("localhost", 9001, "/custom-ingest", false)
    var empty_result: Dictionary = transport.send_domain_event({})
    _expect(not bool(empty_result.get("accepted", true)), "Expected queued transport to reject empty payload.")

    var payload: Dictionary = {
        "export_kind": "world_event",
        "world_event": {
            "id": "test_event:test:0.000"
        }
    }
    var queued_result: Dictionary = transport.send_domain_event(payload)
    _expect(bool(queued_result.get("accepted", false)), "Expected queued transport to accept payload without immediate HTTP.")
    _expect(bool(queued_result.get("queued", false)), "Expected queued transport to report queued payload.")
    _expect(transport.has_pending_work(), "Expected queued transport to have pending work.")


func _test_unknown_event_type_is_not_exported() -> void:
    var simulation_event: RefCounted = SIMULATION_EVENT_SCRIPT.create("debug_only_event", "party", "Debug only.", 0.0, {})
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(simulation_event)
    _expect(export_payload.is_empty(), "Expected unknown event type to be ignored by mapper.")


func _event_by_type(server: RefCounted, event_type: String) -> RefCounted:
    for event_dictionary: Dictionary in server.get_recent_events(20):
        if str(event_dictionary.get("event_type", "")) == event_type:
            return SIMULATION_EVENT_SCRIPT.from_dictionary(event_dictionary)
    _expect(false, "Expected event type not found: %s." % event_type)
    return SIMULATION_EVENT_SCRIPT.create("", "", "", 0.0, {})


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
