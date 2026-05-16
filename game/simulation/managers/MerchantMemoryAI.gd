class_name MerchantMemoryAI
extends RefCounted

const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")

const FOOD_GOODS_ID: String = "food"
const DEFAULT_TRANSFER_AMOUNT: int = 10


func process(server: RefCounted, party_id: String, memory_entries: Array) -> Dictionary:
    if not server.state.has_party(party_id):
        return _no_action("party_not_found")

    var party: RefCounted = server.state.get_party(party_id)
    if not party.is_idle():
        return _no_action("party_busy")

    var cargo_food: int = int(party.cargo.get(FOOD_GOODS_ID, 0))
    var remembered_need: Dictionary = _best_food_need(memory_entries)
    if remembered_need.is_empty():
        return _no_action("no_food_need_memory")

    var need_metadata: Dictionary = _metadata(remembered_need)
    var destination_node_id: String = str(need_metadata.get("node_id", ""))
    var destination_location_id: String = str(need_metadata.get("location_id", ""))
    if destination_node_id.is_empty() or destination_location_id.is_empty():
        return _no_action("food_need_memory_incomplete")

    if cargo_food > 0:
        if party.current_node_id == destination_node_id:
            return _deposit_food(server, party.party_id, destination_location_id, cargo_food)
        return _travel_to_node(server, party.party_id, destination_node_id, "travel_to_remembered_need")

    var source_memory: Dictionary = _best_food_source_at_current_node(memory_entries, party.current_node_id)
    if source_memory.is_empty():
        return _no_action("no_local_food_source_memory")

    var source_metadata: Dictionary = _metadata(source_memory)
    var source_location_id: String = str(source_metadata.get("observed_location_id", source_metadata.get("location_id", "")))
    var source_food: int = _observed_food_amount(source_metadata)
    if source_location_id.is_empty():
        return _no_action("source_memory_incomplete")
    if source_food <= 0:
        return _no_action("source_memory_has_no_food")

    var transfer_amount: int = mini(DEFAULT_TRANSFER_AMOUNT, source_food)
    transfer_amount = mini(transfer_amount, _available_food_capacity_units(server, party))
    transfer_amount = mini(transfer_amount, int(need_metadata.get("needed_amount", DEFAULT_TRANSFER_AMOUNT)))
    if transfer_amount <= 0:
        return _no_action("no_cargo_capacity")

    var withdraw_result: RefCounted = _transfer_food(
        server,
        party.party_id,
        source_location_id,
        transfer_amount,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    )
    if not withdraw_result.accepted:
        return _command_rejected("withdraw_rejected", withdraw_result)

    var travel_result: Dictionary = _travel_to_node(server, party.party_id, destination_node_id, "withdraw_and_travel_to_remembered_need")
    if not bool(travel_result.get("accepted", false)):
        return travel_result

    travel_result["source_location_id"] = source_location_id
    travel_result["destination_location_id"] = destination_location_id
    travel_result["amount"] = transfer_amount
    return travel_result


func _deposit_food(server: RefCounted, party_id: String, location_id: String, cargo_food: int) -> Dictionary:
    var deposit_result: RefCounted = _transfer_food(
        server,
        party_id,
        location_id,
        cargo_food,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    )
    if not deposit_result.accepted:
        return _command_rejected("deposit_rejected", deposit_result)

    return {
        "action": "deposit_to_remembered_need",
        "accepted": true,
        "location_id": location_id,
        "amount": cargo_food
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


func _transfer_food(server: RefCounted, party_id: String, location_id: String, amount: int, direction: String) -> RefCounted:
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.location_id = location_id
    command.goods_id = FOOD_GOODS_ID
    command.amount = amount
    command.direction = direction
    return server.submit_transfer_goods(command)


func _best_food_need(memory_entries: Array) -> Dictionary:
    var best_entry: Dictionary = {}
    var best_needed_amount: int = 0
    for entry: Dictionary in memory_entries:
        if str(entry.get("kind", "")) != "need_ledger":
            continue
        var metadata: Dictionary = _metadata(entry)
        if str(metadata.get("goods_id", "")) != FOOD_GOODS_ID:
            continue
        var needed_amount: int = int(metadata.get("needed_amount", 0))
        if best_entry.is_empty() or needed_amount > best_needed_amount:
            best_entry = entry
            best_needed_amount = needed_amount
    return best_entry


func _best_food_source_at_current_node(memory_entries: Array, current_node_id: String) -> Dictionary:
    var best_entry: Dictionary = {}
    var best_food_amount: int = 0
    for entry: Dictionary in memory_entries:
        if str(entry.get("kind", "")) != "location_observation":
            continue
        var metadata: Dictionary = _metadata(entry)
        if str(metadata.get("node_id", "")) != current_node_id:
            continue
        var food_amount: int = _observed_food_amount(metadata)
        if best_entry.is_empty() or food_amount > best_food_amount:
            best_entry = entry
            best_food_amount = food_amount
    return best_entry


func _observed_food_amount(metadata: Dictionary) -> int:
    var observed_resources: Variant = metadata.get("observed_resources", {})
    if typeof(observed_resources) != TYPE_DICTIONARY:
        return 0
    return int(observed_resources.get(FOOD_GOODS_ID, 0))


func _metadata(entry: Dictionary) -> Dictionary:
    var metadata_value: Variant = entry.get("metadata", {})
    if typeof(metadata_value) == TYPE_DICTIONARY:
        return metadata_value
    return {}


func _available_food_capacity_units(server: RefCounted, party: RefCounted) -> int:
    var capacity_bulk: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_capacity_bulk(party.composition, server.cargo_config)
    var used_bulk: float = PARTY_STATS_CALCULATOR_SCRIPT.calculate_cargo_used_bulk(party.cargo, server.goods_catalog)
    var food_entry: Dictionary = server.goods_catalog.get_goods(FOOD_GOODS_ID)
    var food_bulk: float = float(food_entry.get("bulk_per_unit", 1.0))
    if food_bulk <= 0.0:
        return 0
    return floori((capacity_bulk - used_bulk) / food_bulk)


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
