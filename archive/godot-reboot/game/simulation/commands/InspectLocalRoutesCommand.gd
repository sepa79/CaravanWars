class_name InspectLocalRoutesCommand
extends RefCounted

var party_id: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id
    }
