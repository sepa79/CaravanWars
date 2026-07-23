extends MainLoop

const REGION_GRAPH_NODE_SCRIPT: GDScript = preload("res://world/RegionGraphNode.gd")
const REGION_GRAPH_EDGE_SCRIPT: GDScript = preload("res://world/RegionGraphEdge.gd")
const REGION_ROUTE_WAYPOINT_SCRIPT: GDScript = preload("res://world/RegionRouteWaypoint.gd")
const REGION_TERRAIN_AREA_SCRIPT: GDScript = preload("res://world/RegionTerrainArea.gd")
const REGION_LANDMARK_SCRIPT: GDScript = preload("res://world/RegionLandmark.gd")
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

    if graph.terrain_areas_by_id.size() != 3:
        push_error("Expected 3 terrain areas, got %d." % graph.terrain_areas_by_id.size())
        _failed = true
        _is_finished = true
        return

    if graph.landmarks_by_id.size() != 4:
        push_error("Expected 4 landmarks, got %d." % graph.landmarks_by_id.size())
        _failed = true
        _is_finished = true
        return

    var odra_valley: RefCounted = graph.get_terrain_area("odra_valley")
    if odra_valley == null or odra_valley.polygon.size() < 3:
        push_error("Expected Odra valley terrain polygon.")
        _failed = true
        _is_finished = true
        return

    var sleza_massif: RefCounted = graph.get_landmark("sleza_massif")
    if sleza_massif == null or sleza_massif.visibility_class != "major":
        push_error("Expected major Sleza landmark.")
        _failed = true
        _is_finished = true
        return

    var wroclaw_opole: RefCounted = graph.get_edge_between("wroclaw", "opole")
    if wroclaw_opole == null or wroclaw_opole.route_waypoints.size() != 3:
        push_error("Expected Wroclaw-Opole route geometry with 3 waypoints.")
        _failed = true
        _is_finished = true
        return

    var old_willow_ford: RefCounted = wroclaw_opole.route_waypoints[0]
    if not old_willow_ford.terrain_area_ids.has("odra_valley") or not old_willow_ford.landmark_ids.has("old_willow_ford"):
        push_error("Expected Wroclaw-Opole ford waypoint to reference Odra valley and Old Willow Ford.")
        _failed = true
        _is_finished = true
        return

    var great_forest_opole: RefCounted = graph.get_edge_between("great_forest", "opole")
    if great_forest_opole == null or great_forest_opole.route_waypoints.size() != 2:
        push_error("Expected Great Forest-Opole route geometry with 2 waypoints.")
        _failed = true
        _is_finished = true
        return

    var nysa_sudety_pass: RefCounted = graph.get_edge_between("nysa", "sudety_pass")
    if nysa_sudety_pass == null or nysa_sudety_pass.route_waypoints.size() != 2:
        push_error("Expected Nysa-Sudety Pass route geometry with 2 waypoints.")
        _failed = true
        _is_finished = true
        return

    if not graph.get_neighbors("wroclaw").has("opole"):
        push_error("Expected Wroclaw to connect to Opole.")
        _failed = true
        _is_finished = true
        return

    var route_waypoint_count: int = 0
    for edge: RefCounted in graph.edges_by_id.values():
        route_waypoint_count += edge.route_waypoints.size()

    print("[GraphSmokeTest] OK: %s nodes=%d edges=%d terrain=%d landmarks=%d route_waypoints=%d" % [graph.display_name, graph.nodes_by_id.size(), graph.edges_by_id.size(), graph.terrain_areas_by_id.size(), graph.landmarks_by_id.size(), route_waypoint_count])
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Graph smoke test failed.")
    return _is_finished
