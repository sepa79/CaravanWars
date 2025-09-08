extends RefCounted
class_name MapNode

var id: int
var type: String
var pos2d: Vector2
var attrs: Dictionary

func _init(_id: int, _type: String, _pos2d: Vector2, _attrs: Dictionary = {}) -> void:
    id = _id
    type = _type
    pos2d = _pos2d
    attrs = _attrs

func to_dict() -> Dictionary:
    return {
        "id": id,
        "type": type,
        "pos2d": [pos2d.x, pos2d.y],
        "attrs": attrs,
    }
