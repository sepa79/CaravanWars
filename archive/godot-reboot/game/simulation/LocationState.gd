class_name LocationState
extends RefCounted

var location_id: String = ""
var location_type: String = ""
var manager_actor_id: String = ""
var node_id: String = ""
var resources: Dictionary[String, int] = {}


static func from_dictionary(location_dictionary: Dictionary) -> RefCounted:
    var location: RefCounted = new()
    location.location_id = str(location_dictionary.get("location_id", ""))
    location.location_type = str(location_dictionary.get("location_type", ""))
    location.manager_actor_id = str(location_dictionary.get("manager_actor_id", ""))
    location.node_id = str(location_dictionary.get("node_id", ""))
    location.resources = _int_dictionary_from_variant(location_dictionary.get("resources", {}))
    return location


func to_dictionary() -> Dictionary:
    return {
        "location_id": location_id,
        "location_type": location_type,
        "manager_actor_id": manager_actor_id,
        "node_id": node_id,
        "resources": resources.duplicate()
    }


static func _int_dictionary_from_variant(value: Variant) -> Dictionary[String, int]:
    var values: Dictionary[String, int] = {}
    if typeof(value) != TYPE_DICTIONARY:
        return values

    for key: Variant in value.keys():
        values[str(key)] = int(value.get(key))
    return values
