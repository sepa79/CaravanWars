class_name SimulationServer
extends RefCounted

const COMMAND_RESULT_SCRIPT: GDScript = preload("res://simulation/CommandResult.gd")
const ACTOR_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/ActorTaskState.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")
const LOCATION_ECONOMY_CONFIG_SCRIPT: GDScript = preload("res://simulation/LocationEconomyConfig.gd")
const PARTY_CARGO_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyCargoConfig.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const PARTY_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/PartyTaskState.gd")
const PARTY_TRAVEL_CONFIG_SCRIPT: GDScript = preload("res://simulation/PartyTravelConfig.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const SIMULATION_EVENT_LOG_SCRIPT: GDScript = preload("res://simulation/SimulationEventLog.gd")
const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")
const SIMULATION_STATE_SCRIPT: GDScript = preload("res://simulation/SimulationState.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const ASK_LOCAL_INFORMATION_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AskLocalInformationCommand.gd")

const ERROR_PARTY_NOT_FOUND: String = "party_not_found"
const ERROR_PARTY_BUSY: String = "party_busy"
const ERROR_ORIGIN_MISMATCH: String = "origin_mismatch"
const ERROR_NODE_NOT_FOUND: String = "node_not_found"
const ERROR_ROUTE_NOT_FOUND: String = "route_not_found"
const ERROR_ROUTE_UNKNOWN: String = "route_unknown"
const ERROR_DESTINATION_UNKNOWN: String = "destination_unknown"
const ERROR_NO_KNOWN_PATH: String = "no_known_path"
const ERROR_ORDER_NOT_AUTHORIZED: String = "order_not_authorized"
const ERROR_ORDER_BUSY: String = "order_busy"
const ERROR_ORDER_TYPE_UNSUPPORTED: String = "order_type_unsupported"
const ERROR_ORDER_TARGET_LOCATION_NOT_FOUND: String = "order_target_location_not_found"
const ERROR_ORDER_GOODS_NOT_FOUND: String = "order_goods_not_found"
const ERROR_ORDER_INVALID_AMOUNT: String = "order_invalid_amount"
const ERROR_ORDER_ISSUER_NOT_PRESENT: String = "order_issuer_not_present"
const ERROR_LOCATION_NOT_FOUND: String = "location_not_found"
const ERROR_LOCATION_MANAGER_NOT_AUTHORIZED: String = "location_manager_not_authorized"
const ERROR_LOCATION_MISMATCH: String = "location_mismatch"
const ERROR_GOODS_NOT_FOUND: String = "goods_not_found"
const ERROR_INVALID_AMOUNT: String = "invalid_amount"
const ERROR_INVALID_LOCATION_NEED: String = "invalid_location_need"
const ERROR_INFORMATION_QUERY_UNSUPPORTED: String = "information_query_unsupported"
const ERROR_NO_LOCAL_INFORMATION: String = "no_local_information"
const ERROR_ACTOR_NOT_AUTHORIZED: String = "actor_not_authorized"
const ERROR_ACTOR_TASK_BUSY: String = "actor_task_busy"
const ERROR_PARTY_TASK_BUSY: String = "party_task_busy"
const ERROR_TRANSFER_DIRECTION_UNSUPPORTED: String = "transfer_direction_unsupported"
const ERROR_INSUFFICIENT_LOCATION_GOODS: String = "insufficient_location_goods"
const ERROR_INSUFFICIENT_PARTY_GOODS: String = "insufficient_party_goods"
const ERROR_CARGO_CAPACITY_EXCEEDED: String = "cargo_capacity_exceeded"
const ASK_LOCAL_INFORMATION_DURATION_DAYS: float = 0.25

var state: RefCounted = SIMULATION_STATE_SCRIPT.new()
var travel_config: RefCounted = PARTY_TRAVEL_CONFIG_SCRIPT.new()
var cargo_config: RefCounted = PARTY_CARGO_CONFIG_SCRIPT.new()
var goods_catalog: RefCounted = GOODS_CATALOG_SCRIPT.new()
var location_economy_config: RefCounted = LOCATION_ECONOMY_CONFIG_SCRIPT.new()
var event_log: RefCounted = SIMULATION_EVENT_LOG_SCRIPT.new()
var event_sinks: Array[RefCounted] = []
var current_day: float = 0.0


func submit_move_party(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    var party: RefCounted = state.get_party(command.party_id)
    if not party.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_BUSY, "Party is already traveling: %s." % command.party_id)

    if party.current_node_id != command.from_node_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORIGIN_MISMATCH, "Party %s is at %s, not %s." % [party.party_id, party.current_node_id, command.from_node_id])

    if not state.region_graph.has_node(command.from_node_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_NODE_NOT_FOUND, "Origin node does not exist: %s." % command.from_node_id)

    if not state.region_graph.has_node(command.to_node_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_NODE_NOT_FOUND, "Destination node does not exist: %s." % command.to_node_id)

    var route_edge: RefCounted = state.region_graph.get_edge_between(command.from_node_id, command.to_node_id)
    if route_edge == null:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ROUTE_NOT_FOUND, "No route connects %s to %s." % [command.from_node_id, command.to_node_id])

    if not party.knowledge.knows_edge(route_edge.id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ROUTE_UNKNOWN, "Party %s does not know route %s." % [party.party_id, route_edge.id])

    var speed_km_per_day: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_travel_speed_km_per_day(party.composition, travel_config)
    party.start_travel(command.from_node_id, command.to_node_id, route_edge.distance_km, speed_km_per_day)
    party.knowledge.learn_route(route_edge)
    _append_event("party_travel_started", party.party_id, "Party %s started travel from %s to %s." % [party.party_id, command.from_node_id, command.to_node_id], {
        "manager_actor_id": party.manager_actor_id,
        "from_node_id": command.from_node_id,
        "to_node_id": command.to_node_id,
        "edge_id": route_edge.id,
        "distance_km": route_edge.distance_km,
        "speed_km_per_day": speed_km_per_day
    })
    return COMMAND_RESULT_SCRIPT.accepted_result()


func submit_inspect_local_routes(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    var party: RefCounted = state.get_party(command.party_id)
    if not party.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_BUSY, "Party is already traveling: %s." % command.party_id)

    var discovered_edge_count: int = 0
    var discovered_node_count: int = 0
    for edge: RefCounted in state.region_graph.get_edges_for_node(party.current_node_id):
        var knew_edge: bool = party.knowledge.knows_edge(edge.id)
        var knew_origin: bool = party.knowledge.knows_node(edge.origin_node_id)
        var knew_target: bool = party.knowledge.knows_node(edge.target_node_id)
        party.knowledge.learn_route(edge)
        if not knew_edge:
            discovered_edge_count += 1
        if not knew_origin:
            discovered_node_count += 1
        if not knew_target:
            discovered_node_count += 1

    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Inspected local routes from %s." % party.current_node_id
    result.details = {
        "discovered_edge_count": discovered_edge_count,
        "discovered_node_count": discovered_node_count
    }
    _append_event("party_local_routes_inspected", party.party_id, "Party %s inspected local routes from %s." % [party.party_id, party.current_node_id], {
        "manager_actor_id": party.manager_actor_id,
        "node_id": party.current_node_id,
        "discovered_edge_count": discovered_edge_count,
        "discovered_node_count": discovered_node_count
    })
    return result


func submit_travel_intent(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    var party: RefCounted = state.get_party(command.party_id)
    if not party.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_BUSY, "Party is already traveling: %s." % command.party_id)

    if not state.region_graph.has_node(command.destination_node_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_NODE_NOT_FOUND, "Destination node does not exist: %s." % command.destination_node_id)

    if not party.knowledge.knows_node(command.destination_node_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_DESTINATION_UNKNOWN, "Party %s does not know destination %s." % [party.party_id, command.destination_node_id])

    if party.current_node_id == command.destination_node_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORIGIN_MISMATCH, "Party %s is already at %s." % [party.party_id, command.destination_node_id])

    var known_path: Dictionary = _find_known_path_for_party(party, command.destination_node_id)
    var path_node_ids: Array[String] = _string_array_from_variant(known_path.get("node_ids", []))
    var path_edge_ids: Array[String] = _string_array_from_variant(known_path.get("edge_ids", []))
    if path_edge_ids.is_empty():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_NO_KNOWN_PATH, "No known path connects %s to %s for party %s." % [party.current_node_id, command.destination_node_id, party.party_id])

    party.set_travel_plan(command.destination_node_id, path_node_ids, path_edge_ids)
    _start_next_planned_leg(party)

    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Accepted travel intent to %s." % command.destination_node_id
    result.details = {
        "manager_actor_id": party.manager_actor_id,
        "destination_node_id": command.destination_node_id,
        "path_node_ids": path_node_ids,
        "path_edge_ids": path_edge_ids
    }
    _append_event("party_travel_intent_started", party.party_id, "Party %s accepted travel intent to %s." % [party.party_id, command.destination_node_id], result.details)
    return result


func submit_assign_party_order(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    var party: RefCounted = state.get_party(command.party_id)
    if not party.can_receive_order_from(command.issued_by_actor_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_NOT_AUTHORIZED, "Actor %s does not manage party %s." % [command.issued_by_actor_id, party.party_id])

    if not party.order.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_BUSY, "Party %s already has an order." % party.party_id)

    if command.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO:
        return _assign_travel_to_order(command, party)
    if command.order_type == PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS:
        return _assign_procure_goods_order(command, party)

    return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_TYPE_UNSUPPORTED, "Unsupported party order type: %s." % command.order_type)


func _assign_travel_to_order(command: RefCounted, party: RefCounted) -> RefCounted:

    if not state.region_graph.has_node(command.target_node_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_NODE_NOT_FOUND, "Order target node does not exist: %s." % command.target_node_id)

    party.order.assign_travel_to(command.target_node_id, command.issued_by_actor_id)
    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Assigned travel order to %s." % command.target_node_id
    result.details = party.order.to_dictionary()
    _append_event("party_order_assigned", party.party_id, "Party %s received order travel_to %s." % [party.party_id, command.target_node_id], {
        "manager_actor_id": party.manager_actor_id,
        "issued_by_actor_id": command.issued_by_actor_id,
        "order_type": command.order_type,
        "target_node_id": command.target_node_id
    })
    return result


func _assign_procure_goods_order(command: RefCounted, party: RefCounted) -> RefCounted:
    if not state.has_location(command.target_location_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_TARGET_LOCATION_NOT_FOUND, "Order target location does not exist: %s." % command.target_location_id)

    var target_location: RefCounted = state.get_location(command.target_location_id)
    if command.issued_by_actor_id != party.manager_actor_id and party.current_node_id != target_location.node_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_ISSUER_NOT_PRESENT, "Actor %s cannot issue remote order to party %s without physical delivery." % [command.issued_by_actor_id, party.party_id])

    if not goods_catalog.has_goods(command.goods_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_GOODS_NOT_FOUND, "Order goods does not exist: %s." % command.goods_id)

    if command.amount <= 0:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ORDER_INVALID_AMOUNT, "Order amount must be greater than zero.")

    party.order.assign_procure_goods(command.target_location_id, command.goods_id, command.amount, command.issued_by_actor_id)
    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Assigned procure goods order for %s." % command.goods_id
    result.details = party.order.to_dictionary()
    _append_event("party_order_assigned", party.party_id, "Party %s received order procure_goods %s for %s." % [party.party_id, command.goods_id, command.target_location_id], {
        "manager_actor_id": party.manager_actor_id,
        "issued_by_actor_id": command.issued_by_actor_id,
        "order_type": command.order_type,
        "target_location_id": command.target_location_id,
        "target_node_id": target_location.node_id,
        "goods_id": command.goods_id,
        "amount": command.amount
    })
    return result


func submit_transfer_goods(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    if not state.has_location(command.location_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_NOT_FOUND, "Location does not exist: %s." % command.location_id)

    if not goods_catalog.has_goods(command.goods_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_GOODS_NOT_FOUND, "Goods does not exist: %s." % command.goods_id)

    if command.amount <= 0:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_INVALID_AMOUNT, "Transfer amount must be greater than zero.")

    var party: RefCounted = state.get_party(command.party_id)
    if not party.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_BUSY, "Party is already traveling: %s." % command.party_id)

    var location: RefCounted = state.get_location(command.location_id)
    if party.current_node_id != location.node_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_MISMATCH, "Party %s is at %s, not location %s node %s." % [party.party_id, party.current_node_id, location.location_id, location.node_id])

    if command.direction == TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION:
        return _withdraw_goods_from_location(command, party, location)
    if command.direction == TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION:
        return _deposit_goods_to_location(command, party, location)

    return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_TRANSFER_DIRECTION_UNSUPPORTED, "Unsupported transfer direction: %s." % command.direction)


func submit_declare_location_need(command: RefCounted) -> RefCounted:
    if not state.has_location(command.location_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_NOT_FOUND, "Location does not exist: %s." % command.location_id)

    if not goods_catalog.has_goods(command.goods_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_GOODS_NOT_FOUND, "Goods does not exist: %s." % command.goods_id)

    var location: RefCounted = state.get_location(command.location_id)
    if command.issued_by_actor_id != location.manager_actor_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_MANAGER_NOT_AUTHORIZED, "Actor %s does not manage location %s." % [command.issued_by_actor_id, location.location_id])

    if command.desired_amount <= command.current_amount:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_INVALID_LOCATION_NEED, "Desired amount must be greater than current amount.")

    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Location %s declared need for %s." % [location.location_id, command.goods_id]
    result.details = {
        "location_id": location.location_id,
        "manager_actor_id": location.manager_actor_id,
        "node_id": location.node_id,
        "goods_id": command.goods_id,
        "current_amount": command.current_amount,
        "desired_amount": command.desired_amount,
        "needed_amount": command.desired_amount - command.current_amount,
        "reason": command.reason
    }
    _append_event("location_need_declared", "", "Location %s needs %s %s." % [location.location_id, command.desired_amount - command.current_amount, command.goods_id], result.details)
    return result


func submit_ask_local_information(command: RefCounted) -> RefCounted:
    if not state.has_party(command.party_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_NOT_FOUND, "Party does not exist: %s." % command.party_id)

    if not state.has_location(command.location_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_NOT_FOUND, "Location does not exist: %s." % command.location_id)

    if command.query_type != ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_INFORMATION_QUERY_UNSUPPORTED, "Unsupported local information query: %s." % command.query_type)

    if not goods_catalog.has_goods(command.goods_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_GOODS_NOT_FOUND, "Goods does not exist: %s." % command.goods_id)

    var party: RefCounted = state.get_party(command.party_id)
    if not party.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_BUSY, "Party is already traveling: %s." % command.party_id)

    if command.actor_id != party.manager_actor_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ACTOR_NOT_AUTHORIZED, "Actor %s cannot act for party %s." % [command.actor_id, party.party_id])

    if party.has_active_actor_task(command.actor_id):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_ACTOR_TASK_BUSY, "Actor %s already has an active task." % command.actor_id)

    var location: RefCounted = state.get_location(command.location_id)
    if party.current_node_id != location.node_id:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_LOCATION_MISMATCH, "Party %s is at %s, not location %s node %s." % [party.party_id, party.current_node_id, location.location_id, location.node_id])

    if not party.task.is_idle():
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_PARTY_TASK_BUSY, "Party %s is already busy with task %s." % [party.party_id, party.task.task_type])

    var actor_task: RefCounted = ACTOR_TASK_STATE_SCRIPT.new()
    actor_task.start_ask_local_information(command.actor_id, party.party_id, location.location_id, command.query_type, command.goods_id, ASK_LOCAL_INFORMATION_DURATION_DAYS, current_day, command.actor_id, true)
    party.set_actor_task(actor_task)

    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Started local information task about %s." % command.goods_id
    result.details = {
        "party_id": party.party_id,
        "actor_id": command.actor_id,
        "manager_actor_id": party.manager_actor_id,
        "location_id": location.location_id,
        "location_manager_actor_id": location.manager_actor_id,
        "node_id": location.node_id,
        "query_type": command.query_type,
        "goods_id": command.goods_id,
        "duration_days": ASK_LOCAL_INFORMATION_DURATION_DAYS,
        "requires_party_lock": actor_task.requires_party_lock
    }
    _append_event("party_task_started", party.party_id, "Party %s started task ask_local_information at %s." % [party.party_id, location.location_id], result.details)
    return result


func tick(days: float) -> void:
    var previous_full_day: int = floori(current_day)
    current_day += days
    var elapsed_full_days: int = floori(current_day) - previous_full_day
    _process_location_economy(elapsed_full_days)

    for party: RefCounted in state.parties_by_id.values():
        _process_actor_tasks(party, days)
        _process_party_task(party, days)
        _process_party_order(party)
        var previous_travel_state: String = party.travel_state
        var previous_destination_node_id: String = party.destination_node_id
        party.tick_travel(days)
        if previous_travel_state == "traveling" and party.travel_state == "idle":
            _append_event("party_arrived", party.party_id, "Party %s arrived at %s." % [party.party_id, party.current_node_id], {
                "manager_actor_id": party.manager_actor_id,
                "node_id": party.current_node_id,
                "previous_destination_node_id": previous_destination_node_id
            })
            if not party.travel_intent_destination_node_id.is_empty():
                if party.current_node_id == party.travel_intent_destination_node_id:
                    _append_event("party_travel_intent_completed", party.party_id, "Party %s completed travel intent at %s." % [party.party_id, party.current_node_id], {
                        "manager_actor_id": party.manager_actor_id,
                        "destination_node_id": party.current_node_id
                    })
                    party.clear_travel_plan()
                    _complete_party_order_if_target_reached(party)
                else:
                    _start_next_planned_leg(party)
            else:
                _complete_party_order_if_target_reached(party)


func get_snapshot() -> Dictionary:
    var snapshot: Dictionary = state.to_snapshot_dictionary()
    snapshot["current_day"] = current_day
    snapshot["events"] = event_log.to_dictionary_array()
    return snapshot


func get_neighbor_node_ids_for_party(party_id: String) -> Array[String]:
    if not state.has_party(party_id):
        return []

    var party: RefCounted = state.get_party(party_id)
    return state.region_graph.get_neighbors(party.current_node_id)


func get_known_neighbor_node_ids_for_party(party_id: String) -> Array[String]:
    if not state.has_party(party_id):
        return []

    var party: RefCounted = state.get_party(party_id)
    var neighbor_node_ids: Array[String] = []
    for edge_id: String in party.knowledge.known_edge_ids:
        var edge: RefCounted = state.region_graph.edges_by_id.get(edge_id)
        if edge == null:
            continue
        if edge.origin_node_id == party.current_node_id and party.knowledge.knows_node(edge.target_node_id):
            neighbor_node_ids.append(edge.target_node_id)
        elif edge.target_node_id == party.current_node_id and party.knowledge.knows_node(edge.origin_node_id):
            neighbor_node_ids.append(edge.origin_node_id)

    return neighbor_node_ids


func get_known_destination_node_ids_for_party(party_id: String) -> Array[String]:
    if not state.has_party(party_id):
        return []

    var party: RefCounted = state.get_party(party_id)
    var destination_node_ids: Array[String] = []
    for node_id: String in party.knowledge.known_node_ids:
        if node_id != party.current_node_id and _has_known_path_for_party(party, node_id):
            destination_node_ids.append(node_id)

    destination_node_ids.sort()
    return destination_node_ids


func get_client_snapshot(party_id: String) -> Dictionary:
    if not state.has_party(party_id):
        return {
            "region_graph_id": state.region_graph.id,
            "party": {},
            "known_nodes": [],
            "known_routes": []
        }

    var party: RefCounted = state.get_party(party_id)
    var known_nodes: Array[Dictionary] = []
    for node_id: String in party.knowledge.known_node_ids:
        var node: RefCounted = state.region_graph.get_node(node_id)
        if node != null:
            known_nodes.append({
                "node_id": node.id,
                "display_name": node.display_name,
                "kind": node.kind
            })

    var known_routes: Array[Dictionary] = []
    for edge_id: String in party.knowledge.known_edge_ids:
        var edge: RefCounted = state.region_graph.edges_by_id.get(edge_id)
        if edge != null:
            known_routes.append({
                "edge_id": edge.id,
                "from_node_id": edge.origin_node_id,
                "to_node_id": edge.target_node_id,
                "distance_km": edge.distance_km,
                "kind": edge.kind
            })

    return {
        "region_graph_id": state.region_graph.id,
        "party": party.to_dictionary(),
        "current_locations": get_visible_locations_for_party(party_id),
        "visible_parties": get_visible_parties_for_party(party_id),
        "known_nodes": known_nodes,
        "known_routes": known_routes,
        "recent_events": get_recent_events(5),
        "current_day": current_day
    }


func get_visible_parties_for_party(party_id: String) -> Array[Dictionary]:
    var visible_parties: Array[Dictionary] = []
    if not state.has_party(party_id):
        return visible_parties

    var observing_party: RefCounted = state.get_party(party_id)
    for other_party: RefCounted in state.parties_by_id.values():
        if other_party.party_id == party_id:
            continue
        if other_party.travel_state != "idle":
            continue
        if other_party.current_node_id != observing_party.current_node_id:
            continue

        visible_parties.append({
            "party_id": other_party.party_id,
            "party_type": other_party.party_type,
            "manager_actor_id": other_party.manager_actor_id,
            "current_node_id": other_party.current_node_id,
            "travel_state": other_party.travel_state
        })

    return visible_parties


func get_visible_locations_for_party(party_id: String) -> Array[Dictionary]:
    var visible_locations: Array[Dictionary] = []
    if not state.has_party(party_id):
        return visible_locations

    var party: RefCounted = state.get_party(party_id)
    for location: RefCounted in state.get_locations_at_node(party.current_node_id):
        visible_locations.append(location.to_dictionary())

    return visible_locations


func get_recent_events(limit: int) -> Array[Dictionary]:
    return event_log.get_recent_events(limit)


func add_event_sink(event_sink: RefCounted) -> void:
    event_sinks.append(event_sink)


func record_worldsim_observation(event_type: String, owner_party_id: String, summary: String, details: Dictionary) -> void:
    _append_event(event_type, owner_party_id, summary, details)


func _append_event(event_type: String, party_id: String, summary: String, details: Dictionary) -> void:
    var simulation_event: RefCounted = SIMULATION_EVENT_SCRIPT.create(event_type, party_id, summary, current_day, details)
    event_log.append_event(simulation_event)
    for event_sink: RefCounted in event_sinks:
        event_sink.handle_event(simulation_event)


func _process_location_economy(elapsed_full_days: int) -> void:
    if elapsed_full_days <= 0:
        return

    for location: RefCounted in state.locations_by_id.values():
        var resource_changes: Dictionary = location_economy_config.apply_to_location(location, elapsed_full_days)
        if resource_changes.is_empty():
            continue
        _append_event("location_economy_ticked", "", "Location %s processed %s economy day(s)." % [location.location_id, elapsed_full_days], {
            "location_id": location.location_id,
            "manager_actor_id": location.manager_actor_id,
            "elapsed_full_days": elapsed_full_days,
            "resource_changes": resource_changes
        })


func _withdraw_goods_from_location(command: RefCounted, party: RefCounted, location: RefCounted) -> RefCounted:
    var location_amount: int = int(location.resources.get(command.goods_id, 0))
    if location_amount < command.amount:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_INSUFFICIENT_LOCATION_GOODS, "Location %s has only %s %s." % [location.location_id, location_amount, command.goods_id])

    var candidate_cargo: Dictionary[String, int] = party.cargo.duplicate()
    candidate_cargo[command.goods_id] = int(candidate_cargo.get(command.goods_id, 0)) + command.amount
    if not PARTY_STATS_CALCULATOR_SCRIPT.is_cargo_within_capacity(candidate_cargo, party.composition, goods_catalog, cargo_config):
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_CARGO_CAPACITY_EXCEEDED, "Party %s cannot carry %s more %s." % [party.party_id, command.amount, command.goods_id])

    location.resources[command.goods_id] = location_amount - command.amount
    party.cargo[command.goods_id] = candidate_cargo[command.goods_id]
    return _accepted_transfer_result(command, party, location)


func _deposit_goods_to_location(command: RefCounted, party: RefCounted, location: RefCounted) -> RefCounted:
    var party_amount: int = int(party.cargo.get(command.goods_id, 0))
    if party_amount < command.amount:
        return COMMAND_RESULT_SCRIPT.rejected_result(ERROR_INSUFFICIENT_PARTY_GOODS, "Party %s has only %s %s." % [party.party_id, party_amount, command.goods_id])

    var location_amount: int = int(location.resources.get(command.goods_id, 0))
    party.cargo[command.goods_id] = party_amount - command.amount
    location.resources[command.goods_id] = location_amount + command.amount
    return _accepted_transfer_result(command, party, location)


func _accepted_transfer_result(command: RefCounted, party: RefCounted, location: RefCounted) -> RefCounted:
    var result: RefCounted = COMMAND_RESULT_SCRIPT.accepted_result()
    result.message = "Transferred %s %s." % [command.amount, command.goods_id]
    result.details = {
        "party_id": party.party_id,
        "manager_actor_id": party.manager_actor_id,
        "location_id": location.location_id,
        "location_manager_actor_id": location.manager_actor_id,
        "node_id": location.node_id,
        "goods_id": command.goods_id,
        "amount": command.amount,
        "direction": command.direction,
        "party_cargo_amount": int(party.cargo.get(command.goods_id, 0)),
        "location_resource_amount": int(location.resources.get(command.goods_id, 0))
    }
    _append_event("goods_transferred", party.party_id, "Party %s transferred %s %s with location %s." % [party.party_id, command.amount, command.goods_id, location.location_id], result.details)
    return result


func _known_local_goods_sources(goods_id: String, asking_location_id: String) -> Array[Dictionary]:
    var sources: Array[Dictionary] = []
    for location: RefCounted in state.locations_by_id.values():
        if location.location_id == asking_location_id:
            continue
        var amount: int = int(location.resources.get(goods_id, 0))
        if amount <= 0:
            continue
        sources.append({
            "location_id": location.location_id,
            "node_id": location.node_id,
            "goods_id": goods_id,
            "observed_amount": amount
        })

    sources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("observed_amount", 0)) > int(right.get("observed_amount", 0))
    )
    return sources


func _process_party_task(party: RefCounted, days: float) -> void:
    if party.task.status != PARTY_TASK_STATE_SCRIPT.STATUS_ACTIVE:
        return

    party.task.tick(days)
    if party.task.remaining_days > 0.0:
        return

    if party.task.task_type == PARTY_TASK_STATE_SCRIPT.TASK_TYPE_ASK_LOCAL_INFORMATION:
        _complete_ask_local_information_task(party)
        return

    party.task.mark_failed("task_type_unsupported", "Unsupported task type: %s." % party.task.task_type)
    _append_event("party_task_failed", party.party_id, "Party %s failed unsupported task %s." % [party.party_id, party.task.task_type], {
        "manager_actor_id": party.manager_actor_id,
        "task_type": party.task.task_type,
        "failure_code": party.task.failure_code
    })


func _process_actor_tasks(party: RefCounted, days: float) -> void:
    for actor_task: RefCounted in party.actor_tasks_by_actor_id.values():
        if actor_task.status != ACTOR_TASK_STATE_SCRIPT.STATUS_ACTIVE:
            continue

        actor_task.tick(days)
        if actor_task.remaining_days > 0.0:
            continue

        if actor_task.task_type == ACTOR_TASK_STATE_SCRIPT.TASK_TYPE_ASK_LOCAL_INFORMATION:
            _complete_ask_local_information_actor_task(party, actor_task)
            continue

        actor_task.mark_failed("task_type_unsupported", "Unsupported actor task type: %s." % actor_task.task_type)
        _append_event("party_task_failed", party.party_id, "Actor %s failed unsupported task %s." % [actor_task.actor_id, actor_task.task_type], {
            "party_id": party.party_id,
            "actor_id": actor_task.actor_id,
            "manager_actor_id": party.manager_actor_id,
            "task_type": actor_task.task_type,
            "failure_code": actor_task.failure_code
        })


func _complete_ask_local_information_actor_task(party: RefCounted, actor_task: RefCounted) -> void:
    var location_id: String = actor_task.location_id
    var query_type: String = actor_task.query_type
    var goods_id: String = actor_task.goods_id
    var location: RefCounted = state.get_location(location_id)
    var known_source_locations: Array[Dictionary] = _known_local_goods_sources(goods_id, location_id)
    if known_source_locations.is_empty():
        actor_task.mark_failed(ERROR_NO_LOCAL_INFORMATION, "Location %s has no local information about %s." % [location_id, goods_id])
        _append_event("party_task_failed", party.party_id, "Actor %s found no local information at %s about %s." % [actor_task.actor_id, location_id, goods_id], {
            "party_id": party.party_id,
            "actor_id": actor_task.actor_id,
            "manager_actor_id": party.manager_actor_id,
            "task_type": actor_task.task_type,
            "location_id": location_id,
            "query_type": query_type,
            "goods_id": goods_id,
            "failure_code": actor_task.failure_code
        })
        return

    actor_task.mark_completed()
    _append_event("party_task_completed", party.party_id, "Actor %s completed task ask_local_information at %s." % [actor_task.actor_id, location_id], {
        "party_id": party.party_id,
        "actor_id": actor_task.actor_id,
        "manager_actor_id": party.manager_actor_id,
        "task_type": ACTOR_TASK_STATE_SCRIPT.TASK_TYPE_ASK_LOCAL_INFORMATION,
        "location_id": location_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "duration_days": actor_task.total_days
    })
    _append_event("worldsim_local_information_received", party.party_id, "Actor %s received local information at %s about %s." % [actor_task.actor_id, location_id, goods_id], {
        "party_id": party.party_id,
        "actor_id": actor_task.actor_id,
        "manager_actor_id": party.manager_actor_id,
        "location_id": location_id,
        "location_manager_actor_id": location.manager_actor_id,
        "node_id": location.node_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "duration_days": actor_task.total_days,
        "known_source_locations": known_source_locations
    })


func _complete_ask_local_information_task(party: RefCounted) -> void:
    var location_id: String = party.task.location_id
    var query_type: String = party.task.query_type
    var goods_id: String = party.task.goods_id
    var location: RefCounted = state.get_location(location_id)
    var known_source_locations: Array[Dictionary] = _known_local_goods_sources(goods_id, location_id)
    if known_source_locations.is_empty():
        party.task.mark_failed(ERROR_NO_LOCAL_INFORMATION, "Location %s has no local information about %s." % [location_id, goods_id])
        _append_event("party_task_failed", party.party_id, "Party %s found no local information at %s about %s." % [party.party_id, location_id, goods_id], {
            "manager_actor_id": party.manager_actor_id,
            "task_type": party.task.task_type,
            "location_id": location_id,
            "query_type": query_type,
            "goods_id": goods_id,
            "failure_code": party.task.failure_code
        })
        return

    party.task.mark_completed()
    _append_event("party_task_completed", party.party_id, "Party %s completed task ask_local_information at %s." % [party.party_id, location_id], {
        "manager_actor_id": party.manager_actor_id,
        "task_type": PARTY_TASK_STATE_SCRIPT.TASK_TYPE_ASK_LOCAL_INFORMATION,
        "location_id": location_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "duration_days": party.task.total_days
    })
    _append_event("worldsim_local_information_received", party.party_id, "Party %s received local information at %s about %s." % [party.party_id, location_id, goods_id], {
        "party_id": party.party_id,
        "manager_actor_id": party.manager_actor_id,
        "location_id": location_id,
        "location_manager_actor_id": location.manager_actor_id,
        "node_id": location.node_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "duration_days": party.task.total_days,
        "known_source_locations": known_source_locations
    })


func _start_next_planned_leg(party: RefCounted) -> void:
    if party.travel_path_index >= party.travel_path_edge_ids.size():
        return

    var edge_id: String = party.travel_path_edge_ids[party.travel_path_index]
    var route_edge: RefCounted = state.region_graph.edges_by_id.get(edge_id)
    if route_edge == null:
        _fail_travel_plan(party, "Planned route edge does not exist: %s." % edge_id)
        return

    var next_node_id: String = ""
    if route_edge.origin_node_id == party.current_node_id:
        next_node_id = route_edge.target_node_id
    elif route_edge.target_node_id == party.current_node_id:
        next_node_id = route_edge.origin_node_id
    else:
        _fail_travel_plan(party, "Planned route edge %s does not connect to current node %s." % [edge_id, party.current_node_id])
        return

    var speed_km_per_day: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_travel_speed_km_per_day(party.composition, travel_config)
    party.start_travel(party.current_node_id, next_node_id, route_edge.distance_km, speed_km_per_day)
    party.travel_path_index += 1
    _append_event("party_travel_started", party.party_id, "Party %s started travel from %s to %s." % [party.party_id, party.origin_node_id, party.destination_node_id], {
        "manager_actor_id": party.manager_actor_id,
        "from_node_id": party.origin_node_id,
        "to_node_id": party.destination_node_id,
        "edge_id": route_edge.id,
        "distance_km": route_edge.distance_km,
        "speed_km_per_day": speed_km_per_day,
        "travel_intent_destination_node_id": party.travel_intent_destination_node_id
    })


func _fail_travel_plan(party: RefCounted, failure_message: String) -> void:
    var failed_destination_node_id: String = party.travel_intent_destination_node_id
    party.clear_travel_plan()
    _append_event("party_travel_intent_failed", party.party_id, failure_message, {
        "manager_actor_id": party.manager_actor_id,
        "destination_node_id": failed_destination_node_id
    })


func _process_party_order(party: RefCounted) -> void:
    if not party.is_idle():
        return
    if party.order.order_type != PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO:
        return
    if party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED and party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ACTIVE:
        return

    if party.current_node_id == party.order.target_node_id:
        party.order.mark_completed()
        _append_event("party_order_completed", party.party_id, "Party %s completed order travel_to %s." % [party.party_id, party.order.target_node_id], {
            "manager_actor_id": party.manager_actor_id,
            "issued_by_actor_id": party.order.issued_by_actor_id,
            "order_type": party.order.order_type,
            "target_node_id": party.order.target_node_id
        })
        return

    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = party.party_id
    command.destination_node_id = party.order.target_node_id
    var result: RefCounted = submit_travel_intent(command)
    if result.accepted:
        party.order.mark_active()
        _append_event("party_order_started", party.party_id, "Party %s started order travel_to %s." % [party.party_id, party.order.target_node_id], {
            "manager_actor_id": party.manager_actor_id,
            "issued_by_actor_id": party.order.issued_by_actor_id,
            "order_type": party.order.order_type,
            "target_node_id": party.order.target_node_id
        })
    else:
        party.order.mark_failed(result.error_code, result.message)
        _append_event("party_order_failed", party.party_id, "Party %s failed order travel_to %s: %s." % [party.party_id, party.order.target_node_id, result.error_code], {
            "manager_actor_id": party.manager_actor_id,
            "issued_by_actor_id": party.order.issued_by_actor_id,
            "order_type": party.order.order_type,
            "target_node_id": party.order.target_node_id,
            "failure_code": result.error_code
        })


func _complete_party_order_if_target_reached(party: RefCounted) -> void:
    if party.order.order_type != PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_TRAVEL_TO:
        return
    if party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ACTIVE and party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED:
        return
    if party.current_node_id != party.order.target_node_id:
        return

    party.order.mark_completed()
    _append_event("party_order_completed", party.party_id, "Party %s completed order travel_to %s." % [party.party_id, party.order.target_node_id], {
        "manager_actor_id": party.manager_actor_id,
        "issued_by_actor_id": party.order.issued_by_actor_id,
        "order_type": party.order.order_type,
        "target_node_id": party.order.target_node_id
    })


func _has_known_path_for_party(party: RefCounted, destination_node_id: String) -> bool:
    var known_path: Dictionary = _find_known_path_for_party(party, destination_node_id)
    return not _string_array_from_variant(known_path.get("edge_ids", [])).is_empty()


func _find_known_path_for_party(party: RefCounted, destination_node_id: String) -> Dictionary:
    var start_node_id: String = party.current_node_id
    if start_node_id == destination_node_id:
        return {
            "node_ids": [start_node_id],
            "edge_ids": []
        }

    var open_node_ids: Array[String] = [start_node_id]
    var visited_node_ids: Array[String] = []
    var distances_by_node_id: Dictionary[String, float] = {}
    var previous_node_by_node_id: Dictionary[String, String] = {}
    var previous_edge_by_node_id: Dictionary[String, String] = {}
    distances_by_node_id[start_node_id] = 0.0

    while not open_node_ids.is_empty():
        var current_node_id: String = _pop_nearest_open_node(open_node_ids, distances_by_node_id)
        if current_node_id == destination_node_id:
            return _build_path_dictionary(start_node_id, destination_node_id, previous_node_by_node_id, previous_edge_by_node_id)

        visited_node_ids.append(current_node_id)
        for edge_id: String in party.knowledge.known_edge_ids:
            var edge: RefCounted = state.region_graph.edges_by_id.get(edge_id)
            if edge == null:
                continue

            var neighbor_node_id: String = ""
            if edge.origin_node_id == current_node_id:
                neighbor_node_id = edge.target_node_id
            elif edge.target_node_id == current_node_id:
                neighbor_node_id = edge.origin_node_id
            else:
                continue

            if not party.knowledge.knows_node(neighbor_node_id):
                continue
            if visited_node_ids.has(neighbor_node_id):
                continue

            var candidate_distance: float = distances_by_node_id[current_node_id] + edge.distance_km
            if not distances_by_node_id.has(neighbor_node_id) or candidate_distance < distances_by_node_id[neighbor_node_id]:
                distances_by_node_id[neighbor_node_id] = candidate_distance
                previous_node_by_node_id[neighbor_node_id] = current_node_id
                previous_edge_by_node_id[neighbor_node_id] = edge.id
                if not open_node_ids.has(neighbor_node_id):
                    open_node_ids.append(neighbor_node_id)

    return {
        "node_ids": [],
        "edge_ids": []
    }


func _pop_nearest_open_node(open_node_ids: Array[String], distances_by_node_id: Dictionary[String, float]) -> String:
    var nearest_index: int = 0
    var nearest_distance: float = distances_by_node_id[open_node_ids[0]]
    for index: int in range(1, open_node_ids.size()):
        var node_id: String = open_node_ids[index]
        var node_distance: float = distances_by_node_id[node_id]
        if node_distance < nearest_distance:
            nearest_distance = node_distance
            nearest_index = index

    var nearest_node_id: String = open_node_ids[nearest_index]
    open_node_ids.remove_at(nearest_index)
    return nearest_node_id


func _build_path_dictionary(start_node_id: String, destination_node_id: String, previous_node_by_node_id: Dictionary[String, String], previous_edge_by_node_id: Dictionary[String, String]) -> Dictionary:
    var reversed_node_ids: Array[String] = [destination_node_id]
    var reversed_edge_ids: Array[String] = []
    var current_node_id: String = destination_node_id
    while current_node_id != start_node_id:
        reversed_edge_ids.append(previous_edge_by_node_id[current_node_id])
        current_node_id = previous_node_by_node_id[current_node_id]
        reversed_node_ids.append(current_node_id)

    reversed_node_ids.reverse()
    reversed_edge_ids.reverse()
    return {
        "node_ids": reversed_node_ids,
        "edge_ids": reversed_edge_ids
    }


func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
