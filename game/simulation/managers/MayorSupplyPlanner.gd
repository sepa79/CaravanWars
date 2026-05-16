class_name MayorSupplyPlanner
extends RefCounted

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")

const FOOD_GOODS_ID: String = "food"


func process(server: RefCounted, location_id: String, supply_party_id: String, memory_entries: Array) -> Dictionary:
    if not server.state.has_location(location_id):
        return _no_action("location_not_found")
    if not server.state.has_party(supply_party_id):
        return _no_action("supply_party_not_found")

    var location: RefCounted = server.state.get_location(location_id)
    var supply_party: RefCounted = server.state.get_party(supply_party_id)
    var need_memory: Dictionary = _best_need_memory(memory_entries, location.location_id)
    if need_memory.is_empty():
        return _no_action("no_need_memory")

    var need_metadata: Dictionary = _metadata(need_memory)
    var goods_id: String = str(need_metadata.get("goods_id", ""))
    var needed_amount: int = int(need_metadata.get("needed_amount", 0))
    if goods_id.is_empty() or needed_amount <= 0:
        return _no_action("need_memory_incomplete")

    if _has_active_supply_intent(memory_entries, location.location_id, goods_id):
        return _no_action("supply_intent_already_active")
    if not supply_party.order.is_idle():
        return _no_action("supply_party_already_ordered")
    if supply_party.current_node_id != location.node_id:
        return _no_action("no_present_supply_party")

    var command: RefCounted = ASSIGN_PARTY_ORDER_COMMAND_SCRIPT.new()
    command.party_id = supply_party.party_id
    command.issued_by_actor_id = location.manager_actor_id
    command.order_type = PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS
    command.target_location_id = location.location_id
    command.goods_id = goods_id
    command.amount = needed_amount

    var result: RefCounted = server.submit_assign_party_order(command)
    if not result.accepted:
        return {
            "action": "assign_supply_order_rejected",
            "accepted": false,
            "error_code": result.error_code,
            "message": result.message
        }

    return {
        "action": "assign_supply_order",
        "accepted": true,
        "party_id": supply_party.party_id,
        "location_id": location.location_id,
        "goods_id": goods_id,
        "amount": needed_amount
    }


func _best_need_memory(memory_entries: Array, location_id: String) -> Dictionary:
    var best_entry: Dictionary = {}
    var best_needed_amount: int = 0
    for entry: Dictionary in memory_entries:
        if str(entry.get("kind", "")) != "need_ledger":
            continue
        var metadata: Dictionary = _metadata(entry)
        if str(metadata.get("location_id", "")) != location_id:
            continue
        var needed_amount: int = int(metadata.get("needed_amount", 0))
        if best_entry.is_empty() or needed_amount > best_needed_amount:
            best_entry = entry
            best_needed_amount = needed_amount
    return best_entry


func _has_active_supply_intent(memory_entries: Array, location_id: String, goods_id: String) -> bool:
    for entry: Dictionary in memory_entries:
        var kind: String = str(entry.get("kind", ""))
        if kind != "order_ledger" and kind != "mayor_supply_intent":
            continue
        var metadata: Dictionary = _metadata(entry)
        if str(metadata.get("target_location_id", metadata.get("location_id", ""))) != location_id:
            continue
        if str(metadata.get("goods_id", "")) != goods_id:
            continue
        var status: String = str(metadata.get("status", "active"))
        if status == "cancelled" or status == "completed" or status == "failed":
            continue
        return true
    return false


func _metadata(entry: Dictionary) -> Dictionary:
    var metadata_value: Variant = entry.get("metadata", {})
    if typeof(metadata_value) == TYPE_DICTIONARY:
        return metadata_value
    return {}


func _no_action(reason: String) -> Dictionary:
    return {
        "action": "none",
        "accepted": true,
        "reason": reason
    }
