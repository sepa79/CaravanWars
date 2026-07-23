class_name SimulationEvent
extends RefCounted

var event_type: String = ""
var party_id: String = ""
var summary: String = ""
var day: float = 0.0
var details: Dictionary = {}


static func create(new_event_type: String, new_party_id: String, new_summary: String, new_day: float, new_details: Dictionary = {}) -> RefCounted:
    var simulation_event: RefCounted = new()
    simulation_event.event_type = new_event_type
    simulation_event.party_id = new_party_id
    simulation_event.summary = new_summary
    simulation_event.day = new_day
    simulation_event.details = new_details
    return simulation_event


func to_dictionary() -> Dictionary:
    return {
        "event_type": event_type,
        "party_id": party_id,
        "summary": summary,
        "day": day,
        "details": details.duplicate()
    }


static func from_dictionary(event_dictionary: Dictionary) -> RefCounted:
    var simulation_event: RefCounted = new()
    simulation_event.event_type = str(event_dictionary.get("event_type", ""))
    simulation_event.party_id = str(event_dictionary.get("party_id", ""))
    simulation_event.summary = str(event_dictionary.get("summary", ""))
    simulation_event.day = float(event_dictionary.get("day", 0.0))
    var details_value: Variant = event_dictionary.get("details", {})
    if typeof(details_value) == TYPE_DICTIONARY:
        simulation_event.details = details_value.duplicate()
    return simulation_event
