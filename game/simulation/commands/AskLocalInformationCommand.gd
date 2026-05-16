class_name AskLocalInformationCommand
extends RefCounted

const QUERY_GOODS_SOURCE: String = "goods_source"

var party_id: String = ""
var actor_id: String = ""
var location_id: String = ""
var query_type: String = ""
var goods_id: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.actor_id = str(command_dictionary.get("actor_id", ""))
    command.location_id = str(command_dictionary.get("location_id", ""))
    command.query_type = str(command_dictionary.get("query_type", ""))
    command.goods_id = str(command_dictionary.get("goods_id", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "actor_id": actor_id,
        "location_id": location_id,
        "query_type": query_type,
        "goods_id": goods_id
    }
