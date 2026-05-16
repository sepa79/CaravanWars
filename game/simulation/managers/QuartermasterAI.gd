class_name QuartermasterAI
extends RefCounted

const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const ASK_LOCAL_INFORMATION_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AskLocalInformationCommand.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")


func process(server: RefCounted, party_id: String, memory_entries: Array) -> Dictionary:
    if not server.state.has_party(party_id):
        return _no_action("party_not_found")

    var party: RefCounted = server.state.get_party(party_id)
    if not party.is_idle():
        return _no_action("party_busy")
    if party.order.order_type != PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS:
        return _no_action("no_procure_goods_order")
    if party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ASSIGNED and party.order.status != PARTY_ORDER_STATE_SCRIPT.STATUS_ACTIVE:
        return _no_action("procure_goods_order_not_actionable")

    var order_memory: Dictionary = _matching_order_memory(party, memory_entries)
    if order_memory.is_empty():
        return _no_action("no_order_memory")

    var order_metadata: Dictionary = _metadata(order_memory)
    var target_node_id: String = str(order_metadata.get("target_node_id", ""))
    if target_node_id.is_empty():
        target_node_id = _node_id_for_location(memory_entries, party.order.target_location_id)
    if target_node_id.is_empty():
        return _no_action("target_location_node_unknown")

    var carried_amount: int = int(party.cargo.get(party.order.goods_id, 0))
    if carried_amount > 0:
        if party.current_node_id == target_node_id:
            return _deposit_order_goods(server, party, carried_amount)
        return _travel_to_node(server, party.party_id, target_node_id, "return_to_supply_target")

    var source_memory: Dictionary = _best_source_memory(memory_entries, party.order.goods_id, party.order.target_location_id)
    if source_memory.is_empty():
        return _ask_local_information(server, party, party.order.goods_id)

    var source_metadata: Dictionary = _metadata(source_memory)
    var source_node_id: String = _source_node_id(source_metadata)
    var source_location_id: String = _source_location_id(source_metadata)
    if source_node_id.is_empty() or source_location_id.is_empty():
        return _no_action("source_memory_incomplete")

    if party.current_node_id != source_node_id:
        return _travel_to_node(server, party.party_id, source_node_id, "travel_to_remembered_supply_source")

    var source_amount: int = _source_goods_amount(source_metadata, party.order.goods_id)
    var transfer_amount: int = mini(party.order.amount, source_amount)
    transfer_amount = mini(transfer_amount, _available_capacity_units(server, party, party.order.goods_id))
    if transfer_amount <= 0:
        return _no_action("no_transferable_goods")

    var withdraw_result: RefCounted = _transfer_goods(
        server,
        party.party_id,
        source_location_id,
        party.order.goods_id,
        transfer_amount,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    )
    if not withdraw_result.accepted:
        return _command_rejected("withdraw_rejected", withdraw_result)

    party.order.mark_active()
    var travel_result: Dictionary = _travel_to_node(server, party.party_id, target_node_id, "withdraw_and_return_to_supply_target")
    if not bool(travel_result.get("accepted", false)):
        return travel_result

    travel_result["source_location_id"] = source_location_id
    travel_result["target_location_id"] = party.order.target_location_id
    travel_result["goods_id"] = party.order.goods_id
    travel_result["amount"] = transfer_amount
    return travel_result


func _deposit_order_goods(server: RefCounted, party: RefCounted, carried_amount: int) -> Dictionary:
    var deposit_amount: int = mini(carried_amount, party.order.amount)
    var deposit_result: RefCounted = _transfer_goods(
        server,
        party.party_id,
        party.order.target_location_id,
        party.order.goods_id,
        deposit_amount,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    )
    if not deposit_result.accepted:
        return _command_rejected("deposit_rejected", deposit_result)

    if deposit_amount >= party.order.amount:
        party.order.mark_completed()
    else:
        party.order.mark_active()
    return {
        "action": "deposit_to_supply_target",
        "accepted": true,
        "target_location_id": party.order.target_location_id,
        "goods_id": party.order.goods_id,
        "amount": deposit_amount
    }


func _ask_local_information(server: RefCounted, party: RefCounted, goods_id: String) -> Dictionary:
    var current_locations: Array[RefCounted] = server.state.get_locations_at_node(party.current_node_id)
    if current_locations.is_empty():
        return _no_action("no_local_location_to_ask")

    var location: RefCounted = current_locations[0]
    var command: RefCounted = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.new()
    command.party_id = party.party_id
    command.actor_id = party.manager_actor_id
    command.location_id = location.location_id
    command.query_type = ASK_LOCAL_INFORMATION_COMMAND_SCRIPT.QUERY_GOODS_SOURCE
    command.goods_id = goods_id
    var information_result: RefCounted = server.submit_ask_local_information(command)
    if not information_result.accepted:
        return _command_rejected("ask_local_information_rejected", information_result)

    return {
        "action": "ask_local_information",
        "accepted": true,
        "location_id": location.location_id,
        "goods_id": goods_id
    }


func _travel_to_node(server: RefCounted, party_id: String, destination_node_id: String, action: String) -> Dictionary:
    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.destination_node_id = destination_node_id
    var travel_result: RefCounted = server.submit_travel_intent(command)
    if not travel_result.accepted:
        return _command_rejected("travel_rejected", travel_result)

    return {
        "action": action,
        "accepted": true,
        "destination_node_id": destination_node_id
    }


func _transfer_goods(server: RefCounted, party_id: String, location_id: String, goods_id: String, amount: int, direction: String) -> RefCounted:
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.location_id = location_id
    command.goods_id = goods_id
    command.amount = amount
    command.direction = direction
    return server.submit_transfer_goods(command)


func _matching_order_memory(party: RefCounted, memory_entries: Array) -> Dictionary:
    for entry: Dictionary in memory_entries:
        if str(entry.get("kind", "")) != "order_ledger":
            continue
        var metadata: Dictionary = _metadata(entry)
        if str(metadata.get("party_id", "")) != party.party_id:
            continue
        if str(metadata.get("order_type", "")) != PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS:
            continue
        if str(metadata.get("target_location_id", "")) != party.order.target_location_id:
            continue
        if str(metadata.get("goods_id", "")) != party.order.goods_id:
            continue
        return entry
    return {}


func _best_source_memory(memory_entries: Array, goods_id: String, target_location_id: String) -> Dictionary:
    var best_entry: Dictionary = {}
    var best_amount: int = 0
    for entry: Dictionary in memory_entries:
        var kind: String = str(entry.get("kind", ""))
        if kind != "location_observation" and kind != "local_information":
            continue
        var metadata: Dictionary = _metadata(entry)
        var observed_location_id: String = _source_location_id(metadata)
        if observed_location_id == target_location_id:
            continue
        var amount: int = _source_goods_amount(metadata, goods_id)
        if amount <= 0:
            continue
        if best_entry.is_empty() or amount > best_amount:
            best_entry = entry
            best_amount = amount
    return best_entry


func _node_id_for_location(memory_entries: Array, location_id: String) -> String:
    for entry: Dictionary in memory_entries:
        var metadata: Dictionary = _metadata(entry)
        var remembered_location_id: String = str(metadata.get("observed_location_id", metadata.get("location_id", metadata.get("target_location_id", ""))))
        if remembered_location_id == location_id:
            return str(metadata.get("node_id", metadata.get("target_node_id", "")))
    return ""


func _observed_goods_amount(metadata: Dictionary, goods_id: String) -> int:
    var observed_resources: Variant = metadata.get("observed_resources", {})
    if typeof(observed_resources) != TYPE_DICTIONARY:
        return 0
    return int(observed_resources.get(goods_id, 0))


func _source_location_id(metadata: Dictionary) -> String:
    if metadata.has("known_source_locations"):
        var known_sources: Variant = metadata.get("known_source_locations", [])
        if typeof(known_sources) == TYPE_ARRAY and not known_sources.is_empty() and typeof(known_sources[0]) == TYPE_DICTIONARY:
            return str(known_sources[0].get("location_id", ""))
    return str(metadata.get("observed_location_id", metadata.get("location_id", "")))


func _source_node_id(metadata: Dictionary) -> String:
    if metadata.has("known_source_locations"):
        var known_sources: Variant = metadata.get("known_source_locations", [])
        if typeof(known_sources) == TYPE_ARRAY and not known_sources.is_empty() and typeof(known_sources[0]) == TYPE_DICTIONARY:
            return str(known_sources[0].get("node_id", ""))
    return str(metadata.get("node_id", ""))


func _source_goods_amount(metadata: Dictionary, goods_id: String) -> int:
    if metadata.has("known_source_locations"):
        var known_sources: Variant = metadata.get("known_source_locations", [])
        if typeof(known_sources) == TYPE_ARRAY and not known_sources.is_empty() and typeof(known_sources[0]) == TYPE_DICTIONARY:
            return int(known_sources[0].get("observed_amount", 0))
    return _observed_goods_amount(metadata, goods_id)


func _metadata(entry: Dictionary) -> Dictionary:
    var metadata_value: Variant = entry.get("metadata", {})
    if typeof(metadata_value) == TYPE_DICTIONARY:
        return metadata_value
    return {}


func _available_capacity_units(server: RefCounted, party: RefCounted, goods_id: String) -> int:
    var capacity_bulk: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_capacity_bulk(party.composition, server.cargo_config)
    var used_bulk: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_used_bulk(party.cargo, server.goods_catalog)
    var goods_entry: Dictionary = server.goods_catalog.get_goods(goods_id)
    var goods_bulk: float = float(goods_entry.get("bulk_per_unit", 1.0))
    if goods_bulk <= 0.0:
        return 0
    return floori((capacity_bulk - used_bulk) / goods_bulk)


func _command_rejected(action: String, command_result: RefCounted) -> Dictionary:
    return {
        "action": action,
        "accepted": false,
        "error_code": command_result.error_code,
        "message": command_result.message
    }


func _no_action(reason: String) -> Dictionary:
    return {
        "action": "none",
        "accepted": true,
        "reason": reason
    }
