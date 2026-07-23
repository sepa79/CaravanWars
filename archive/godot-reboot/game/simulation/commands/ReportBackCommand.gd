class_name ReportBackCommand
extends RefCounted

var party_id: String = ""
var actor_id: String = ""
var recipient_actor_id: String = ""
var recipient_owner_kind: String = "actor"
var location_id: String = ""
var max_entries: int = 3
var trust: float = 0.9
var distortion_noise: float = 0.02
var listener_interest_tags: Array[String] = []
var notes: String = ""


static func from_dictionary(command_dictionary: Dictionary) -> RefCounted:
    var command: RefCounted = new()
    command.party_id = str(command_dictionary.get("party_id", ""))
    command.actor_id = str(command_dictionary.get("actor_id", ""))
    command.recipient_actor_id = str(command_dictionary.get("recipient_actor_id", ""))
    command.recipient_owner_kind = str(command_dictionary.get("recipient_owner_kind", "actor"))
    command.location_id = str(command_dictionary.get("location_id", ""))
    command.max_entries = int(command_dictionary.get("max_entries", 3))
    command.trust = float(command_dictionary.get("trust", 0.9))
    command.distortion_noise = float(command_dictionary.get("distortion_noise", 0.02))
    command.listener_interest_tags = _string_array_from_variant(command_dictionary.get("listener_interest_tags", []))
    command.notes = str(command_dictionary.get("notes", ""))
    return command


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "actor_id": actor_id,
        "recipient_actor_id": recipient_actor_id,
        "recipient_owner_kind": recipient_owner_kind,
        "location_id": location_id,
        "max_entries": max_entries,
        "trust": trust,
        "distortion_noise": distortion_noise,
        "listener_interest_tags": listener_interest_tags.duplicate(),
        "notes": notes
    }


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
