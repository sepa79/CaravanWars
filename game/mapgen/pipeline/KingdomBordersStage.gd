extends RefCounted

func run(context: RefCounted) -> void:
    var params: Variant = context.params
    var rng: RandomNumberGenerator = context.get_stage_rng("kingdom_borders")
    var margin: float = 20.0
    var seeds: Array[Vector2] = []
    for i in range(params.kingdom_count):
        var pos := Vector2(
            rng.randf_range(margin, max(margin, params.width - margin)),
            rng.randf_range(margin, max(margin, params.height - margin))
        )
        seeds.append(pos)
    context.set_vector_layer("kingdom_seeds", seeds)
    var names: Dictionary = {}
    for i in range(params.kingdom_count):
        names[i + 1] = "Kingdom %d" % (i + 1)
    context.set_data("kingdom_names", names)
