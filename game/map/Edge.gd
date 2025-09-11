extends RefCounted
class_name Edge

var id: int
var type: String
var polyline: Array[Vector2]
var endpoints: Array[int]
var road_class: String
var attrs: Dictionary

func _init(
    _id: int,
    _type: String,
    _polyline: Array[Vector2],
    _endpoints: Array[int],
    _road_class: String,
    _attrs: Dictionary = {}
) -> void:
    id = _id
    type = _type
    polyline = _polyline
    endpoints = _endpoints
    road_class = _road_class
    attrs = _attrs

func to_dict() -> Dictionary:
    var pts: Array = []
    for p in polyline:
        pts.append([p.x, p.y])
    return {
        "id": id,
        "type": type,
        "class": road_class,
        "polyline": pts,
        "endpoints": endpoints,
        "attrs": attrs,
    }
