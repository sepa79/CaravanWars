extends RefCounted
class_name Edge

var id: int
var type: String
var polyline: Array[Vector2]
var endpoints: Array[int]
var attrs: Dictionary

func _init(_id: int, _type: String, _polyline: Array, _endpoints: Array, _attrs: Dictionary = {}) -> void:
    id = _id
    type = _type
    polyline = _polyline
    endpoints = _endpoints
    attrs = _attrs

func to_dict() -> Dictionary:
    var pts: Array = []
    for p in polyline:
        pts.append([p.x, p.y])
    return {
        "id": id,
        "type": type,
        "polyline": pts,
        "endpoints": endpoints,
        "attrs": attrs,
    }
