extends MainLoop

const REGION_GRAPH_NODE_SCRIPT: GDScript = preload("res://world/RegionGraphNode.gd")
const REGION_GRAPH_EDGE_SCRIPT: GDScript = preload("res://world/RegionGraphEdge.gd")
const REGION_GRAPH_SCRIPT: GDScript = preload("res://world/RegionGraph.gd")
const REGION_GRAPH_LOADER_SCRIPT: GDScript = preload("res://world/RegionGraphLoader.gd")


var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    var graph: RefCounted = REGION_GRAPH_LOADER_SCRIPT.load_from_file("res://data/regions/silesia.json")
    var validation_errors: Array[String] = graph.validate()

    if not validation_errors.is_empty():
        for validation_error: String in validation_errors:
            push_error(validation_error)
        _failed = true
        _is_finished = true
        return

    if graph.nodes_by_id.size() != 11:
        push_error("Expected 11 graph nodes, got %d." % graph.nodes_by_id.size())
        _failed = true
        _is_finished = true
        return

    if graph.edges_by_id.size() != 18:
        push_error("Expected 18 graph edges, got %d." % graph.edges_by_id.size())
        _failed = true
        _is_finished = true
        return

    if not graph.get_neighbors("wroclaw").has("opole"):
        push_error("Expected Wroclaw to connect to Opole.")
        _failed = true
        _is_finished = true
        return

    print("[GraphSmokeTest] OK: %s nodes=%d edges=%d" % [graph.display_name, graph.nodes_by_id.size(), graph.edges_by_id.size()])
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Graph smoke test failed.")
    return _is_finished
