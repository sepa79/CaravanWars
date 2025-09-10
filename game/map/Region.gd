extends RefCounted
class_name Region

var id: int
# Boundary of the region represented as a list of Vector2 points.
var boundary_nodes: Array[Vector2]
var narrator: String
var kingdom_id: int

func _init(
    _id: int,
    _boundary_nodes: Array = [],
    _narrator: String = "",
    _kingdom_id: int = 0
) -> void:
    id = _id
    boundary_nodes = _boundary_nodes
    narrator = _narrator
    kingdom_id = _kingdom_id

func to_dict() -> Dictionary:
    var pts: Array = []
    for p in boundary_nodes:
        pts.append([p.x, p.y])
    return {
        "id": id,
        "boundary_nodes": pts,
        "narrator": narrator,
        "kingdom_id": kingdom_id,
    }
