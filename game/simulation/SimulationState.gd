class_name SimulationState
extends RefCounted

const REGION_GRAPH_SCRIPT: GDScript = preload("res://world/RegionGraph.gd")

var region_graph: RefCounted = REGION_GRAPH_SCRIPT.new()
var parties_by_id: Dictionary[String, RefCounted] = {}
var locations_by_id: Dictionary[String, RefCounted] = {}


func add_party(party: RefCounted) -> void:
    parties_by_id[party.party_id] = party


func has_party(party_id: String) -> bool:
    return parties_by_id.has(party_id)


func get_party(party_id: String) -> RefCounted:
    return parties_by_id.get(party_id)


func add_location(location: RefCounted) -> void:
    locations_by_id[location.location_id] = location


func has_location(location_id: String) -> bool:
    return locations_by_id.has(location_id)


func get_location(location_id: String) -> RefCounted:
    return locations_by_id.get(location_id)


func get_locations_at_node(node_id: String) -> Array[RefCounted]:
    var locations: Array[RefCounted] = []
    for location: RefCounted in locations_by_id.values():
        if location.node_id == node_id:
            locations.append(location)
    return locations


func to_snapshot_dictionary() -> Dictionary:
    var parties: Array[Dictionary] = []
    for party: RefCounted in parties_by_id.values():
        parties.append(party.to_dictionary())

    var locations: Array[Dictionary] = []
    for location: RefCounted in locations_by_id.values():
        locations.append(location.to_dictionary())

    return {
        "region_graph_id": region_graph.id,
        "parties": parties,
        "locations": locations
    }
