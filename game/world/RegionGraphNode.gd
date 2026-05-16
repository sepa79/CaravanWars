class_name RegionGraphNode
extends RefCounted

var id: String = ""
var display_name: String = ""
var kind: String = ""
var notes: String = ""
var position: Vector2 = Vector2.ZERO


static func from_dictionary(node_dictionary: Dictionary) -> RefCounted:
    var node: RefCounted = new()
    node.id = str(node_dictionary.get("id", ""))
    node.display_name = str(node_dictionary.get("display_name", node.id))
    node.kind = str(node_dictionary.get("kind", "unknown"))
    node.notes = str(node_dictionary.get("notes", ""))

    var raw_position: Variant = node_dictionary.get("position", [0.0, 0.0])
    if typeof(raw_position) == TYPE_ARRAY and raw_position.size() >= 2:
        node.position = Vector2(float(raw_position[0]), float(raw_position[1]))

    return node
