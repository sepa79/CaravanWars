class_name PartyKnowledgeState
extends RefCounted

var known_node_ids: Array[String] = []
var known_edge_ids: Array[String] = []


func add_known_node(node_id: String) -> void:
    if not known_node_ids.has(node_id):
        known_node_ids.append(node_id)


func add_known_edge(edge_id: String) -> void:
    if not known_edge_ids.has(edge_id):
        known_edge_ids.append(edge_id)


func knows_node(node_id: String) -> bool:
    return known_node_ids.has(node_id)


func knows_edge(edge_id: String) -> bool:
    return known_edge_ids.has(edge_id)


func learn_route(edge: RefCounted) -> void:
    add_known_edge(edge.id)
    add_known_node(edge.origin_node_id)
    add_known_node(edge.target_node_id)


func to_dictionary() -> Dictionary:
    return {
        "known_node_ids": known_node_ids.duplicate(),
        "known_edge_ids": known_edge_ids.duplicate()
    }


static func from_dictionary(knowledge_dictionary: Dictionary) -> RefCounted:
    var knowledge: RefCounted = new()
    knowledge.known_node_ids = _string_array_from_variant(knowledge_dictionary.get("known_node_ids", []))
    knowledge.known_edge_ids = _string_array_from_variant(knowledge_dictionary.get("known_edge_ids", []))
    return knowledge


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
