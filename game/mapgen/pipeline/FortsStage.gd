extends RefCounted

const RoadNetworkModule: Script = preload("res://mapview/RoadNetwork.gd")
const MapNodeModule: Script = preload("res://mapview/MapNode.gd")

func run(context: RefCounted) -> void:
    var roads: Dictionary = context.get_vector_layer("roads", {})
    var regions: Dictionary = context.get_vector_layer("regions", {})
    if roads.is_empty() or regions.is_empty():
        return
    var params: Variant = context.params
    var rng: RandomNumberGenerator = context.get_stage_rng("forts")
    var helper = RoadNetworkModule.new(rng)
    helper.insert_border_forts(
        roads,
        regions,
        10.0,
        params.max_forts_per_kingdom,
        params.width,
        params.height
    )
    context.set_vector_layer("roads", roads)
    context.set_vector_layer("forts", _collect_forts(roads))

func _collect_forts(roads: Dictionary) -> Array[Vector2]:
    var forts: Array[Vector2] = []
    var nodes: Dictionary = roads.get("nodes", {})
    for node in nodes.values():
        if node.type == MapNodeModule.TYPE_FORT:
            forts.append(node.pos2d)
    return forts
