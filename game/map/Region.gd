extends RefCounted
class_name Region

var id: int
var boundary_nodes: Array[int]
var narrator: String

func _init(_id: int, _boundary_nodes: Array = [], _narrator: String = "") -> void:
    id = _id
    boundary_nodes = _boundary_nodes
    narrator = _narrator

func to_dict() -> Dictionary:
    return {
        "id": id,
        "boundary_nodes": boundary_nodes,
        "narrator": narrator,
    }
