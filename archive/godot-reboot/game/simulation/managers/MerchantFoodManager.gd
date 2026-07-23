class_name MerchantFoodManager
extends RefCounted

const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const TRANSFER_GOODS_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TransferGoodsCommand.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")

const FOOD_GOODS_ID: String = "food"
const DEFAULT_TRANSFER_AMOUNT: int = 10


func process(server: RefCounted, party_id: String) -> Dictionary:
    if not server.state.has_party(party_id):
        return _no_action("party_not_found")

    var party: RefCounted = server.state.get_party(party_id)
    if not party.is_idle():
        return _no_action("party_busy")

    var current_location: RefCounted = _current_location(server, party)
    if current_location == null:
        return _no_action("no_current_location")

    var destination_location: RefCounted = _lowest_food_known_location(server, party)
    if destination_location == null:
        return _no_action("no_known_destination")

    var cargo_food: int = int(party.cargo.get(FOOD_GOODS_ID, 0))
    if cargo_food > 0:
        if current_location.location_id == destination_location.location_id:
            return _deposit_food(server, party, current_location, cargo_food)
        return _travel_to_location(server, party, destination_location)

    if current_location.location_id == destination_location.location_id:
        return _no_action("current_location_is_lowest_food")

    var current_food: int = int(current_location.resources.get(FOOD_GOODS_ID, 0))
    var destination_food: int = int(destination_location.resources.get(FOOD_GOODS_ID, 0))
    if current_food <= destination_food:
        return _no_action("no_food_surplus")

    var available_capacity_units: int = _available_food_capacity_units(server, party)
    var transfer_amount: int = mini(DEFAULT_TRANSFER_AMOUNT, current_food - destination_food)
    transfer_amount = mini(transfer_amount, available_capacity_units)
    if transfer_amount <= 0:
        return _no_action("no_cargo_capacity")

    var withdraw_result: RefCounted = _transfer_food(
        server,
        party.party_id,
        current_location.location_id,
        transfer_amount,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_WITHDRAW_FROM_LOCATION
    )
    if not withdraw_result.accepted:
        return _command_rejected("withdraw_rejected", withdraw_result)

    var travel_result: RefCounted = _travel_intent(server, party.party_id, destination_location.node_id)
    if not travel_result.accepted:
        return _command_rejected("travel_rejected_after_withdraw", travel_result)

    return {
        "action": "withdraw_and_travel",
        "accepted": true,
        "location_id": current_location.location_id,
        "destination_location_id": destination_location.location_id,
        "amount": transfer_amount
    }


func _deposit_food(server: RefCounted, party: RefCounted, current_location: RefCounted, cargo_food: int) -> Dictionary:
    var deposit_result: RefCounted = _transfer_food(
        server,
        party.party_id,
        current_location.location_id,
        cargo_food,
        TRANSFER_GOODS_COMMAND_SCRIPT.DIRECTION_DEPOSIT_TO_LOCATION
    )
    if not deposit_result.accepted:
        return _command_rejected("deposit_rejected", deposit_result)

    return {
        "action": "deposit",
        "accepted": true,
        "location_id": current_location.location_id,
        "amount": cargo_food
    }


func _travel_to_location(server: RefCounted, party: RefCounted, destination_location: RefCounted) -> Dictionary:
    var travel_result: RefCounted = _travel_intent(server, party.party_id, destination_location.node_id)
    if not travel_result.accepted:
        return _command_rejected("travel_rejected", travel_result)

    return {
        "action": "travel_to_lowest_food",
        "accepted": true,
        "destination_location_id": destination_location.location_id
    }


func _transfer_food(server: RefCounted, party_id: String, location_id: String, amount: int, direction: String) -> RefCounted:
    var command: RefCounted = TRANSFER_GOODS_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.location_id = location_id
    command.goods_id = FOOD_GOODS_ID
    command.amount = amount
    command.direction = direction
    return server.submit_transfer_goods(command)


func _travel_intent(server: RefCounted, party_id: String, destination_node_id: String) -> RefCounted:
    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.destination_node_id = destination_node_id
    return server.submit_travel_intent(command)


func _current_location(server: RefCounted, party: RefCounted) -> RefCounted:
    var locations: Array[RefCounted] = server.state.get_locations_at_node(party.current_node_id)
    if locations.is_empty():
        return null
    return locations[0]


func _lowest_food_known_location(server: RefCounted, party: RefCounted) -> RefCounted:
    var lowest_location: RefCounted = null
    var lowest_food: int = 0
    var known_destination_node_ids: Array[String] = server.get_known_destination_node_ids_for_party(party.party_id)
    known_destination_node_ids.append(party.current_node_id)

    for location: RefCounted in server.state.locations_by_id.values():
        if not known_destination_node_ids.has(location.node_id):
            continue
        if not party.knowledge.knows_node(location.node_id):
            continue

        var location_food: int = int(location.resources.get(FOOD_GOODS_ID, 0))
        if lowest_location == null or location_food < lowest_food:
            lowest_location = location
            lowest_food = location_food

    return lowest_location


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
