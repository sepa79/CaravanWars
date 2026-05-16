class_name TestSimulationEventSink
extends RefCounted

var events: Array[Dictionary] = []


func handle_event(simulation_event: RefCounted) -> void:
    events.append(simulation_event.to_dictionary())


func event_types() -> Array[String]:
    var types: Array[String] = []
    for event_dictionary: Dictionary in events:
        types.append(str(event_dictionary.get("event_type", "")))
    return types
