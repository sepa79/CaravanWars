extends RefCounted

const RiverGeneratorModule: Script = preload("res://mapgen/RiverGenerator.gd")

func run(context: RefCounted) -> void:
    var params: Variant = context.params
    var rng: RandomNumberGenerator = context.get_stage_rng("rivers")
    var generator = RiverGeneratorModule.new(rng)
    var placeholder_roads: Dictionary = {
        "nodes": {},
        "edges": {},
        "next_node_id": 1,
        "next_edge_id": 1,
    }
    var rivers: Array = generator.generate_rivers(placeholder_roads, params.max_river_count, params.width, params.height)
    context.set_vector_layer("rivers", rivers)
