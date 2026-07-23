class_name InterruptTravelCommand
extends RefCounted

var party_id: String = ""
var issued_by_actor_id: String = ""
var reason: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.issued_by_actor_id = str(command_dictionary.get("issued_by_actor_id", ""))
    command.reason = str(command_dictionary.get("reason", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "issued_by_actor_id": issued_by_actor_id,
        "reason": reason
    }
