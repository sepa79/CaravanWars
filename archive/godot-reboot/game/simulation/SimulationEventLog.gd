class_name SimulationEventLog
extends RefCounted

var events: Array[RefCounted] = []


func append_event(simulation_event: RefCounted) -> void:
    events.append(simulation_event)


func get_recent_events(limit: int) -> Array[Dictionary]:
    var recent_events: Array[Dictionary] = []
    var safe_limit: int = maxi(0, limit)
    var start_index: int = maxi(0, events.size() - safe_limit)
    for event_index: int in range(start_index, events.size()):
        recent_events.append(events[event_index].to_dictionary())
    return recent_events


func to_dictionary_array() -> Array[Dictionary]:
    var event_dictionaries: Array[Dictionary] = []
    for simulation_event: RefCounted in events:
        event_dictionaries.append(simulation_event.to_dictionary())
    return event_dictionaries
