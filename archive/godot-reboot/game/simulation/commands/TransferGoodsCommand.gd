class_name TransferGoodsCommand
extends RefCounted

const DIRECTION_WITHDRAW_FROM_LOCATION: String = "withdraw_from_location"
const DIRECTION_DEPOSIT_TO_LOCATION: String = "deposit_to_location"

var party_id: String = ""
var location_id: String = ""
var goods_id: String = ""
var amount: int = 0
var direction: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.location_id = str(command_dictionary.get("location_id", ""))
    command.goods_id = str(command_dictionary.get("goods_id", ""))
    command.amount = int(command_dictionary.get("amount", 0))
    command.direction = str(command_dictionary.get("direction", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "location_id": location_id,
        "goods_id": goods_id,
        "amount": amount,
        "direction": direction
    }
