extends RefCounted

func run(context: RefCounted) -> void:
    var fertility: Array = context.get_raster_layer("fertility", [])
    var roughness: Array = context.get_raster_layer("roughness", [])
    if fertility.is_empty():
        context.set_raster_layer("biomes", [])
        return
    var biome_rows: Array = []
    for y in range(fertility.size()):
        var fert_row: Array = fertility[y]
        var rough_row: Array = [] if y >= roughness.size() else roughness[y]
        var biome_row: Array[String] = []
        for x in range(fert_row.size()):
            var f_val: float = fert_row[x]
            var r_val: float = 0.0
            if x < rough_row.size():
                r_val = rough_row[x]
            var biome: String = _classify_cell(f_val, r_val)
            biome_row.append(biome)
        biome_rows.append(biome_row)
    context.set_raster_layer("biomes", biome_rows)

func _classify_cell(fertility_value: float, roughness_value: float) -> String:
    if fertility_value >= 0.66:
        if roughness_value <= 0.33:
            return "lush_plains"
        return "dense_forest"
    if fertility_value >= 0.33:
        if roughness_value <= 0.33:
            return "rolling_hills"
        return "highlands"
    if roughness_value <= 0.25:
        return "dry_steppe"
    return "barren"
