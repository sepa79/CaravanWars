class_name MovePartyCommand
extends RefCounted

var party_id: String = ""
var from_node_id: String = ""
var to_node_id: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.from_node_id = str(command_dictionary.get("from_node_id", ""))
    command.to_node_id = str(command_dictionary.get("to_node_id", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "from_node_id": from_node_id,
        "to_node_id": to_node_id
    }
