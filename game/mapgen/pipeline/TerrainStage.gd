extends RefCounted

const NoiseUtilModule: Script = preload("res://mapgen/NoiseUtil.gd")

func run(context: RefCounted) -> void:
    var params: Variant = context.params
    var width_i: int = int(params.width)
    var height_i: int = int(params.height)
    var rng: RandomNumberGenerator = context.get_stage_rng("terrain")
    var noise_seed: int = rng.randi()
    var noise_util = NoiseUtilModule.new()
    var fertility_field: Array = noise_util.generate_field(
        noise_util.create_simplex(noise_seed, 3),
        width_i,
        height_i,
        0.1
    )
    var roughness_field: Array = noise_util.compute_roughness(fertility_field)
    context.set_raster_layer("fertility", fertility_field)
    context.set_raster_layer("roughness", roughness_field)
    context.set_data("terrain_seed", noise_seed)
