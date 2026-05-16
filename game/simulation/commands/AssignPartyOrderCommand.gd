class_name AssignPartyOrderCommand
extends RefCounted

var party_id: String = ""
var issued_by_actor_id: String = ""
var order_type: String = ""
var target_node_id: String = ""
var target_location_id: String = ""
var goods_id: String = ""
var amount: int = 0
var route_node_ids: Array[String] = []


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.issued_by_actor_id = str(command_dictionary.get("issued_by_actor_id", ""))
    command.order_type = str(command_dictionary.get("order_type", ""))
    command.target_node_id = str(command_dictionary.get("target_node_id", ""))
    command.target_location_id = str(command_dictionary.get("target_location_id", ""))
    command.goods_id = str(command_dictionary.get("goods_id", ""))
    command.amount = int(command_dictionary.get("amount", 0))
    command.route_node_ids = _string_array_from_variant(command_dictionary.get("route_node_ids", []))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "issued_by_actor_id": issued_by_actor_id,
        "order_type": order_type,
        "target_node_id": target_node_id,
        "target_location_id": target_location_id,
        "goods_id": goods_id,
        "amount": amount,
        "route_node_ids": route_node_ids.duplicate()
    }


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
