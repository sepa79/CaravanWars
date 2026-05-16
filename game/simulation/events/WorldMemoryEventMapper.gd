class_name WorldMemoryEventMapper
extends RefCounted

const SIMULATION_EVENT_SCRIPT: GDScript = preload("res://simulation/SimulationEvent.gd")

const EXPORT_KIND_WORLD_EVENT: String = "world_event"

const EXPORTABLE_EVENT_TYPES: Array[String] = [
    "party_travel_started",
    "party_arrived",
    "party_local_routes_inspected",
    "party_travel_intent_started",
    "party_travel_intent_completed",
    "party_travel_intent_failed",
    "party_order_assigned",
    "party_order_started",
    "party_order_completed",
    "party_order_failed",
    "goods_transferred",
    "location_economy_ticked",
    "location_need_declared",
    "worldsim_location_observed",
    "worldsim_party_observed"
]


static func map_event(simulation_event: RefCounted) -> Dictionary:
    if not EXPORTABLE_EVENT_TYPES.has(simulation_event.event_type):
        return {}

    var location_id: String = _location_id_for_event(simulation_event)
    return {
        "export_kind": EXPORT_KIND_WORLD_EVENT,
        "world_event": {
            "id": _world_event_id_for_event(simulation_event),
            "event_type": simulation_event.event_type,
            "text": simulation_event.summary,
            "location_id": location_id,
            "occurred_at": "day:%0.3f" % simulation_event.day,
            "importance": _importance_for_event(simulation_event.event_type),
            "reliability": 1.0,
            "tags": _tags_for_event(simulation_event),
            "metadata": _metadata_for_event(simulation_event)
        }
    }


static func map_events(simulation_events: Array[Dictionary]) -> Array[Dictionary]:
    var export_payloads: Array[Dictionary] = []
    for event_dictionary: Dictionary in simulation_events:
        var simulation_event: RefCounted = SIMULATION_EVENT_SCRIPT.from_dictionary(event_dictionary)
        var export_payload: Dictionary = map_event(simulation_event)
        if not export_payload.is_empty():
            export_payloads.append(export_payload)
    return export_payloads


static func _world_event_id_for_event(simulation_event: RefCounted) -> String:
    var subject_id: String = simulation_event.party_id
    if subject_id.is_empty():
        subject_id = _location_id_for_event(simulation_event)
    if subject_id.is_empty():
        subject_id = simulation_event.event_type
    return "%s:%s:%0.3f" % [simulation_event.event_type, subject_id, simulation_event.day]


static func _location_id_for_event(simulation_event: RefCounted) -> String:
    var details: Dictionary = simulation_event.details
    if details.has("location_id"):
        return str(details.get("location_id", ""))
    if details.has("target_location_id"):
        return str(details.get("target_location_id", ""))
    if details.has("node_id"):
        return str(details.get("node_id", ""))
    if details.has("to_node_id"):
        return str(details.get("to_node_id", ""))
    if details.has("destination_node_id"):
        return str(details.get("destination_node_id", ""))
    return ""


static func _importance_for_event(event_type: String) -> float:
    if event_type == "party_arrived" or event_type == "party_travel_intent_completed":
        return 0.7
    if event_type == "party_travel_intent_failed":
        return 0.8
    return 0.5


static func _tags_for_event(simulation_event: RefCounted) -> Array[String]:
    var tags: Array[String] = ["simulation", simulation_event.event_type]
    if not simulation_event.party_id.is_empty():
        tags.append(simulation_event.party_id)

    var location_id: String = _location_id_for_event(simulation_event)
    if not location_id.is_empty():
        tags.append(location_id)
    return tags


static func _metadata_for_event(simulation_event: RefCounted) -> Dictionary:
    var metadata: Dictionary = {
        "party_id": simulation_event.party_id,
        "occurred_day": simulation_event.day
    }

    var details: Dictionary = simulation_event.details
    for key: Variant in details.keys():
        if str(key) == "distance_km" or str(key) == "speed_km_per_day":
            metadata[str(key)] = details.get(key)
        elif str(key).ends_with("_node_id") or str(key).ends_with("_location_id") or str(key) == "node_id" or str(key) == "edge_id" or str(key).ends_with("_actor_id") or str(key) == "order_type" or str(key) == "location_id" or str(key) == "goods_id" or str(key) == "direction" or str(key) == "reason" or str(key).begins_with("owner_") or str(key).begins_with("observer_") or str(key).begins_with("observed_"):
            metadata[str(key)] = str(details.get(key))
        elif str(key).ends_with("_count") or str(key) == "amount" or str(key).ends_with("_amount"):
            metadata[str(key)] = int(details.get(key))
        elif str(key) == "resource_changes" and typeof(details.get(key)) == TYPE_DICTIONARY:
            metadata[str(key)] = details.get(key).duplicate(true)
        elif str(key) == "observed_resources" and typeof(details.get(key)) == TYPE_DICTIONARY:
            metadata[str(key)] = details.get(key).duplicate(true)
        elif str(key) == "observation_score":
            metadata[str(key)] = int(details.get(key))

    return metadata
