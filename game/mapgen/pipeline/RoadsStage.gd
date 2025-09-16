extends RefCounted

const RoadNetworkModule: Script = preload("res://mapview/RoadNetwork.gd")
const MapNodeModule: Script = preload("res://mapview/MapNode.gd")
const RiverGeneratorModule: Script = preload("res://mapgen/RiverGenerator.gd")

func run(context: RefCounted) -> void:
    var params: Variant = context.params
    var cities: Array[Vector2] = context.get_vector_layer("cities", [])
    if cities.is_empty():
        context.set_vector_layer("roads", {})
        return
    var rng: RandomNumberGenerator = context.get_stage_rng("roads")
    var road_stage = RoadNetworkModule.new(rng)
    var roads: Dictionary = road_stage.build_roads(
        cities,
        params.min_connections,
        params.max_connections,
        params.crossroad_detour_margin,
        "roman"
    )
    var villages: Array[Vector2] = context.get_vector_layer("villages", [])
    if villages.size() > 0:
        road_stage.insert_villages(roads, villages)
    var regions: Dictionary = context.get_vector_layer("regions", {})
    if not regions.is_empty():
        _assign_kingdoms_to_cities(roads, regions)
    var rivers: Array = context.get_vector_layer("rivers", [])
    if rivers.size() > 0:
        RiverGeneratorModule.apply_intersections(rivers, roads)
    context.set_vector_layer("roads", roads)

func _assign_kingdoms_to_cities(roads: Dictionary, regions: Dictionary) -> void:
    var nodes: Dictionary = roads.get("nodes", {})
    for node in nodes.values():
        if node.type != MapNodeModule.TYPE_CITY:
            continue
        var region := _region_for_point(node.pos2d, regions)
        if region != null:
            node.attrs["kingdom_id"] = region.kingdom_id

func _region_for_point(point: Vector2, regions: Dictionary) -> RefCounted:
    for region in regions.values():
        var pts := PackedVector2Array()
        for vertex in region.boundary_nodes:
            pts.append(vertex)
        if Geometry2D.is_point_in_polygon(point, pts):
            return region
    return null
