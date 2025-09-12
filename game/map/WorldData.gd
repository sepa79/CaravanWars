extends RefCounted
class_name WorldData

var width: float
var height: float
var rasters: Dictionary = {}
var vectors: Dictionary = {}
var _guid_counters: Dictionary = {}

func _init(_width: float = 100.0, _height: float = 100.0) -> void:
    width = _width
    height = _height

func _next_guid(scope: String) -> String:
    var idx: int = _guid_counters.get(scope, 1)
    _guid_counters[scope] = idx + 1
    return "%s:%d" % [scope, idx]

func add_raster(name: String, data) -> void:
    rasters[name] = data

func add_vector(name: String, feature: Dictionary, derived_from: String = "") -> String:
    feature["id"] = _next_guid(name)
    feature["derived_from"] = derived_from
    if not vectors.has(name):
        vectors[name] = []
    vectors[name].append(feature)
    return feature["id"]

func add_graph(name: String, graph: Dictionary) -> void:
    var nodes: Dictionary = graph.get("nodes", {})
    for node in nodes.values():
        if not node.attrs.has("guid"):
            node.attrs["guid"] = _next_guid(name + "_node")
    var edges: Dictionary = graph.get("edges", {})
    for edge in edges.values():
        if not edge.attrs.has("guid"):
            edge.attrs["guid"] = _next_guid(name + "_edge")
    vectors[name] = graph

func get_raster(name: String):
    return rasters.get(name)

func get_vector(name: String):
    return vectors.get(name)
