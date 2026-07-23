class_name MayorSupplyPlanner
extends RefCounted

const ASSIGN_PARTY_ORDER_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/AssignPartyOrderCommand.gd")
const DECLARE_SUPPLY_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/DeclareSupplyIntentCommand.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const MEMORY_FRESHNESS_POLICY_SCRIPT: GDScript = preload("res://simulation/managers/MemoryFreshnessPolicy.gd")

const FOOD_GOODS_ID: String = "food"


func process_candidates(server: RefCounted, location_id: String, supply_party_ids: Array[String], memory_entries: Array) -> Dictionary:
    if supply_party_ids.is_empty():
        return _no_action("no_supply_party_candidates")
    if not server.state.has_location(location_id):
        return _no_action("location_not_found")

    var location: RefCounted = server.state.get_location(location_id)
    var need_memory: Dictionary = _best_need_memory(memory_entries, location.location_id)
    if need_memory.is_empty():
        return _no_action("no_need_memory")

    var need_metadata: Dictionary = _metadata(need_memory)
    var goods_id: String = str(need_metadata.get("goods_id", ""))
    var needed_amount: int = int(need_metadata.get("needed_amount", 0))
    if goods_id.is_empty() or needed_amount <= 0:
        return _no_action("need_memory_incomplete")

    if _has_active_supply_intent(memory_entries, location.location_id, goods_id, server.current_day):
        return _no_action("supply_intent_already_active")
    if _has_matching_candidate_order(server, supply_party_ids, location.location_id, goods_id):
        return _no_action("candidate_supply_order_already_active")

    var skipped_parties: Array[Dictionary] = []
    for supply_party_id: String in supply_party_ids:
        var result: Dictionary = process(server, location_id, supply_party_id, memory_entries)
        if str(result.get("action", "")) == "assign_supply_order":
            result["selected_party_id"] = supply_party_id
            result["skipped_parties"] = skipped_parties
            return result

        var reason: String = str(result.get("reason", ""))
        if reason == "supply_party_not_found" or reason == "supply_party_already_ordered" or reason == "no_present_supply_party":
            skipped_parties.append({
                "party_id": supply_party_id,
                "reason": reason
            })
            continue

        result["selected_party_id"] = ""
        result["skipped_parties"] = skipped_parties
        return result

    var no_candidate_result: Dictionary = _no_action("no_available_supply_party")
    no_candidate_result["selected_party_id"] = ""
    no_candidate_result["skipped_parties"] = skipped_parties
    return no_candidate_result


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

    if _has_active_supply_intent(memory_entries, location.location_id, goods_id, server.current_day):
        return _no_action("supply_intent_already_active")
    if not supply_party.order.is_idle():
        return _no_action("supply_party_already_ordered")
    if supply_party.current_node_id != location.node_id:
        return _no_action("no_present_supply_party")

    var intent_command: RefCounted = DECLARE_SUPPLY_INTENT_COMMAND_SCRIPT.new()
    intent_command.location_id = location.location_id
    intent_command.issued_by_actor_id = location.manager_actor_id
    intent_command.supply_party_id = supply_party.party_id
    intent_command.goods_id = goods_id
    intent_command.amount = needed_amount
    intent_command.reason = str(need_metadata.get("reason", "supply_need"))
    var intent_result: RefCounted = server.submit_declare_supply_intent(intent_command)
    if not intent_result.accepted:
        return {
            "action": "declare_supply_intent_rejected",
            "accepted": false,
            "error_code": intent_result.error_code,
            "message": intent_result.message
        }

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

    var source_report: Dictionary = _best_fresh_source_report(memory_entries, goods_id, location.location_id, server.current_day)
    var source_report_status: String = "none"
    if not source_report.is_empty():
        source_report_status = "fresh"
    elif _has_stale_source_report(memory_entries, goods_id, location.location_id, server.current_day):
        source_report_status = "stale"

    return {
        "action": "assign_supply_order",
        "accepted": true,
        "party_id": supply_party.party_id,
        "location_id": location.location_id,
        "goods_id": goods_id,
        "amount": needed_amount,
        "intent_declared": true,
        "source_report_status": source_report_status,
        "known_source_locations": _source_locations_from_report(source_report)
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


func _has_active_supply_intent(memory_entries: Array, location_id: String, goods_id: String, current_day: float) -> bool:
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
        if _has_newer_terminal_supply_intent(memory_entries, entry, location_id, goods_id):
            continue
        if not MEMORY_FRESHNESS_POLICY_SCRIPT.is_supply_intent_active(entry, current_day):
            continue
        return true
    return false


func _has_newer_terminal_supply_intent(memory_entries: Array, active_entry: Dictionary, location_id: String, goods_id: String) -> bool:
    var active_metadata: Dictionary = _metadata(active_entry)
    var active_party_id: String = _supply_intent_party_id(active_metadata)
    var active_day: float = MEMORY_FRESHNESS_POLICY_SCRIPT.observed_day_for_entry(active_entry)
    for entry: Dictionary in memory_entries:
        var kind: String = str(entry.get("kind", ""))
        if kind != "order_ledger" and kind != "mayor_supply_intent":
            continue
        var metadata: Dictionary = _metadata(entry)
        var status: String = str(metadata.get("status", "active"))
        if status != "cancelled" and status != "completed" and status != "failed":
            continue
        if str(metadata.get("target_location_id", metadata.get("location_id", ""))) != location_id:
            continue
        if str(metadata.get("goods_id", "")) != goods_id:
            continue
        if not active_party_id.is_empty() and _supply_intent_party_id(metadata) != active_party_id:
            continue
        var terminal_day: float = MEMORY_FRESHNESS_POLICY_SCRIPT.observed_day_for_entry(entry)
        if terminal_day < 0.0:
            continue
        if active_day < 0.0 or terminal_day >= active_day:
            return true
    return false


func _supply_intent_party_id(metadata: Dictionary) -> String:
    return str(metadata.get("party_id", metadata.get("supply_party_id", "")))


func _has_matching_candidate_order(server: RefCounted, supply_party_ids: Array[String], location_id: String, goods_id: String) -> bool:
    for supply_party_id: String in supply_party_ids:
        if not server.state.has_party(supply_party_id):
            continue
        var party: RefCounted = server.state.get_party(supply_party_id)
        if party.order.is_idle():
            continue
        if party.order.order_type != PARTY_ORDER_STATE_SCRIPT.ORDER_TYPE_PROCURE_GOODS:
            continue
        if party.order.target_location_id != location_id:
            continue
        if party.order.goods_id != goods_id:
            continue
        return true
    return false


func _best_fresh_source_report(memory_entries: Array, goods_id: String, target_location_id: String, current_day: float) -> Dictionary:
    var best_entry: Dictionary = {}
    var best_amount: int = 0
    for entry: Dictionary in memory_entries:
        if not _is_source_report(entry, goods_id, target_location_id):
            continue
        if not MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_actionable(entry, current_day):
            continue
        var amount: int = _source_goods_amount(_metadata(entry), goods_id)
        if best_entry.is_empty() or amount > best_amount:
            best_entry = entry
            best_amount = amount
    return best_entry


func _has_stale_source_report(memory_entries: Array, goods_id: String, target_location_id: String, current_day: float) -> bool:
    for entry: Dictionary in memory_entries:
        if not _is_source_report(entry, goods_id, target_location_id):
            continue
        if MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_stale(entry, current_day):
            return true
    return false


func _is_source_report(entry: Dictionary, goods_id: String, target_location_id: String) -> bool:
    var kind: String = str(entry.get("kind", ""))
    if kind != "heard_report" and kind != "local_information" and kind != "location_observation":
        return false
    var metadata: Dictionary = _metadata(entry)
    if str(metadata.get("goods_id", "")) != goods_id:
        return false
    var source_location_id: String = _source_location_id(metadata)
    return not source_location_id.is_empty() and source_location_id != target_location_id


func _source_locations_from_report(entry: Dictionary) -> Array[Dictionary]:
    var source_locations: Array[Dictionary] = []
    if entry.is_empty():
        return source_locations

    var metadata: Dictionary = _metadata(entry)
    var known_sources: Variant = metadata.get("known_source_locations", [])
    if typeof(known_sources) == TYPE_ARRAY:
        for source_value: Variant in known_sources:
            if typeof(source_value) == TYPE_DICTIONARY:
                source_locations.append(source_value)
    return source_locations


func _source_location_id(metadata: Dictionary) -> String:
    if metadata.has("known_source_locations"):
        var known_sources: Variant = metadata.get("known_source_locations", [])
        if typeof(known_sources) == TYPE_ARRAY and not known_sources.is_empty() and typeof(known_sources[0]) == TYPE_DICTIONARY:
            return str(known_sources[0].get("location_id", ""))
    return str(metadata.get("observed_location_id", metadata.get("location_id", "")))


func _source_goods_amount(metadata: Dictionary, goods_id: String) -> int:
    if metadata.has("known_source_locations"):
        var known_sources: Variant = metadata.get("known_source_locations", [])
        if typeof(known_sources) == TYPE_ARRAY and not known_sources.is_empty() and typeof(known_sources[0]) == TYPE_DICTIONARY:
            return int(known_sources[0].get("observed_amount", 0))
    var observed_resources: Variant = metadata.get("observed_resources", {})
    if typeof(observed_resources) != TYPE_DICTIONARY:
        return 0
    return int(observed_resources.get(goods_id, 0))


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
