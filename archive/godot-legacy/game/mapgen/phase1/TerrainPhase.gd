extends RefCounted
class_name TerrainPhase

const ScopedRngScript: GDScript = preload("res://mapgen/phase1/ScopedRng.gd")
var BaseHeightGeneratorScript: GDScript = load("res://mapgen/phase1/BaseHeightGenerator.gd")
var RandomFeatureGeneratorScript: GDScript = load("res://mapgen/phase1/RandomFeatureGenerator.gd")
var EdgeShaperScript: GDScript = load("res://mapgen/phase1/EdgeShaper.gd")
const AssetCatalogScript: GDScript = preload("res://mapgen/data/AssetCatalog.gd")
const TileScript: GDScript = preload("res://mapgen/data/Tile.gd")
const HexCoordScript: GDScript = preload("res://mapgen/HexCoord.gd")

const SEA_THRESHOLD: float = 0.20
const PLAINS_THRESHOLD: float = 0.55
const HILLS_THRESHOLD: float = 0.75
const ELEVATION_BAND_STEP: float = 0.08
const MAX_ELEVATION_BAND: int = 12
const NEIGHBOR_OFFSETS: Array[Vector2i] = HexCoord.DIRECTIONS
const ROUGHNESS_FLAT_THRESHOLD: float = 0.03
const ROUGHNESS_HILLY_THRESHOLD: float = 0.10
const BAND_MOUNTAIN_MIN: int = 7
const MOUNTAIN_TREELINE_HEIGHT: float = 0.88
const BARE_MOUNTAIN_EXTRA_BIAS: float = 0.0
const HEIGHT_QUANTUM: float = 0.0

const VISUAL_BIAS: Dictionary = {
    AssetCatalogScript.TERRAIN_SEA: -0.20,
    AssetCatalogScript.TERRAIN_PLAINS: 0.0,
    AssetCatalogScript.TERRAIN_HILLS: 0.0,
    AssetCatalogScript.TERRAIN_MOUNTAINS: 0.0,
}

const TREE_PROBABILITY: Dictionary = {
    AssetCatalogScript.TERRAIN_SEA: 0.0,
    AssetCatalogScript.TERRAIN_PLAINS: 0.45,
    AssetCatalogScript.TERRAIN_HILLS: 0.65,
    AssetCatalogScript.TERRAIN_MOUNTAINS: 0.35,
}

var config: HexMapConfig
var data: HexMapData

func _init(p_config: HexMapConfig, p_data: HexMapData) -> void:
    config = p_config
    data = p_data
    if BaseHeightGeneratorScript == null or RandomFeatureGeneratorScript == null or EdgeShaperScript == null:
        push_warning("[TerrainPhase] Missing generator scripts for phase 1 terrain pipeline")

func run(map_data: MapData) -> Dictionary:
    if map_data == null:
        return {}
    var width: int = config.map_width
    var height: int = config.map_height
    var rng_state: int = config.map_seed
    var base_generator: RefCounted = BaseHeightGeneratorScript.new()
    var base_heights: Dictionary = base_generator.generate(width, height, rng_state, config)
    var feature_generator: RefCounted = RandomFeatureGeneratorScript.new()
    var feature_heights: Dictionary = feature_generator.apply(rng_state, width, height, base_heights, config)
    var edge_shaper: RefCounted = EdgeShaperScript.new()
    var shaped_heights: Dictionary = edge_shaper.apply(width, height, feature_heights, config)
    var final_heights: Dictionary = _quantize_heights(shaped_heights)
    var elevation_metadata: Dictionary = _analyze_elevation(width, height, final_heights)
    if map_data != null:
        map_data.add_terrain_metadata_entry("elevation_analysis", elevation_metadata)
    _log_elevation_stats(elevation_metadata)
    data.clear_tiles()
    var payload: Dictionary = _populate_tiles(map_data, final_heights, rng_state, elevation_metadata)
    data.set_phase_payload(HexMapData.PHASE_TERRAIN, payload)
    return payload

func _populate_tiles(
    map_data: MapData,
    heights: Dictionary,
    rng_state: int,
    elevation_metadata: Dictionary
) -> Dictionary:
    var classes: Dictionary = {}
    if typeof(elevation_metadata.get("classes")) == TYPE_DICTIONARY:
        classes = elevation_metadata.get("classes")
    var tile_count: int = 0
    for r in range(config.map_height):
        for q in range(config.map_width):
            var axial := Vector2i(q, r)
            var base_height: float = float(heights.get(axial, 0.5))
            var terrain_type: StringName = AssetCatalogScript.TERRAIN_PLAINS
            if not classes.is_empty():
                var class_value: Variant = classes.get(axial, AssetCatalogScript.TERRAIN_PLAINS)
                if class_value is StringName:
                    terrain_type = class_value
                else:
                    terrain_type = StringName(String(class_value))
            else:
                terrain_type = _classify_height(base_height)
            var visual_height: float = _compute_visual_height(base_height, terrain_type)
            var variant: StringName = _choose_variant(rng_state, q, r, terrain_type, base_height)
            var rotation: int = _choose_rotation(rng_state, q, r, terrain_type)
            var with_trees: bool = _should_have_trees(rng_state, q, r, terrain_type, variant, base_height)
            var tile: Tile = data.create_tile(q, r, terrain_type, visual_height, rotation, variant, with_trees)
            data.store_tile(tile)
            tile_count += 1
    map_data.set_dimensions(config.map_width, config.map_height)
    return {
        "tiles": tile_count,
        "width": config.map_width,
        "height": config.map_height,
    }

func _analyze_elevation(width: int, height: int, heights: Dictionary) -> Dictionary:
    var roughness_scale: float = 1.0
    if config != null:
        var random_settings: Dictionary = config.get_random_feature_settings()
        var scale_variant: Variant = random_settings.get("roughness_scale", 1.0)
        match typeof(scale_variant):
            TYPE_FLOAT, TYPE_INT:
                roughness_scale = clampf(float(scale_variant), 0.25, 4.0)
            _:
                roughness_scale = 1.0
    var flat_threshold: float = ROUGHNESS_FLAT_THRESHOLD * roughness_scale
    var hilly_threshold: float = ROUGHNESS_HILLY_THRESHOLD * roughness_scale
    var band_mountain_min: int = BAND_MOUNTAIN_MIN
    var bands: Dictionary = {}
    var roughness: Dictionary = {}
    var classes: Dictionary = {}
    for r in range(height):
        for q in range(width):
            var axial := Vector2i(q, r)
            var h: float = float(heights.get(axial, 0.5))
            var band: int = int(floor(h / ELEVATION_BAND_STEP))
            if band < 0:
                band = 0
            elif band > MAX_ELEVATION_BAND:
                band = MAX_ELEVATION_BAND
            bands[axial] = band
    for r in range(height):
        for q in range(width):
            var axial := Vector2i(q, r)
            var center_height: float = float(heights.get(axial, 0.5))
            var max_diff: float = 0.0
            for offset in NEIGHBOR_OFFSETS:
                var nq: int = q + offset.x
                var nr: int = r + offset.y
                if nq < 0 or nr < 0 or nq >= width or nr >= height:
                    continue
                var neighbor_axial := Vector2i(nq, nr)
                var neighbor_height: float = float(heights.get(neighbor_axial, center_height))
                var diff: float = abs(neighbor_height - center_height)
                if diff > max_diff:
                    max_diff = diff
            roughness[axial] = max_diff
    for r in range(height):
        for q in range(width):
            var axial := Vector2i(q, r)
            var height_value: float = float(heights.get(axial, 0.5))
            var band_value: int = int(bands.get(axial, 0))
            var rough_value: float = float(roughness.get(axial, 0.0))
            classes[axial] = _classify_elevation_point(
                height_value,
                band_value,
                rough_value,
                flat_threshold,
                hilly_threshold,
                band_mountain_min
            )
    return {
        "band_step": ELEVATION_BAND_STEP,
        "bands": bands,
        "roughness": roughness,
        "classes": classes,
        "roughness_flat_threshold": flat_threshold,
        "roughness_hilly_threshold": hilly_threshold,
        "band_mountain_min": band_mountain_min,
    }

func _quantize_heights(source: Dictionary) -> Dictionary:
    if HEIGHT_QUANTUM <= 0.0:
        return source
    var result: Dictionary = {}
    for key in source.keys():
        var raw_value: float = float(source.get(key, 0.0))
        var quantized: float = HEIGHT_QUANTUM * round(raw_value / HEIGHT_QUANTUM)
        result[key] = clampf(quantized, 0.0, 1.0)
    return result

func _log_elevation_stats(elevation_metadata: Dictionary) -> void:
    if elevation_metadata.is_empty():
        return
    var bands: Dictionary = elevation_metadata.get("bands", {})
    var roughness: Dictionary = elevation_metadata.get("roughness", {})
    var classes: Dictionary = elevation_metadata.get("classes", {})
    if bands.is_empty():
        return
    var min_band: int = MAX_ELEVATION_BAND
    var max_band: int = 0
    var band_counts: Dictionary = {}
    for axial in bands.keys():
        var band_value: int = int(bands[axial])
        if band_value < min_band:
            min_band = band_value
        if band_value > max_band:
            max_band = band_value
        band_counts[band_value] = int(band_counts.get(band_value, 0)) + 1
    var min_rough: float = 1e9
    var max_rough: float = 0.0
    if not roughness.is_empty():
        for value in roughness.values():
            var v: float = float(value)
            if v < min_rough:
                min_rough = v
            if v > max_rough:
                max_rough = v
    var class_counts: Dictionary = {}
    if not classes.is_empty():
        for class_value in classes.values():
            var key := String(class_value)
            class_counts[key] = int(class_counts.get(key, 0)) + 1
    print("[TerrainPhase] Elevation bands %d..%d, roughness %.3f..%.3f" % [min_band, max_band, min_rough, max_rough])
    if not class_counts.is_empty():
        print("[TerrainPhase] Elevation classes: %s" % [str(class_counts)])

func _classify_elevation_point(
    height_value: float,
    band_value: int,
    rough_value: float,
    flat_threshold: float,
    hilly_threshold: float,
    band_mountain_min: int
) -> StringName:
    return _classify_height(height_value)

func _classify_height(height_value: float) -> StringName:
    if height_value < SEA_THRESHOLD:
        return AssetCatalogScript.TERRAIN_SEA
    if height_value < PLAINS_THRESHOLD:
        return AssetCatalogScript.TERRAIN_PLAINS
    if height_value < HILLS_THRESHOLD:
        return AssetCatalogScript.TERRAIN_HILLS
    return AssetCatalogScript.TERRAIN_MOUNTAINS

func _compute_visual_height(base_height: float, terrain_type: StringName) -> float:
    var bias: float = float(VISUAL_BIAS.get(terrain_type, 0.0))
    return clampf(base_height + bias, 0.0, 1.0)

func _choose_variant(
    rng_state: int,
    q: int,
    r: int,
    terrain_type: StringName,
    base_height: float
) -> StringName:
    var catalog: AssetCatalog = data.asset_catalog
    if catalog == null:
        return TileScript.VARIANT_A
    var variants: Array[StringName] = catalog.get_variants_for_terrain(terrain_type)
    if variants.is_empty():
        return TileScript.VARIANT_A
    if terrain_type == AssetCatalogScript.TERRAIN_HILLS:
        var t: float = 0.0
        var denom_hills: float = max(HILLS_THRESHOLD - PLAINS_THRESHOLD, 0.0001)
        t = clampf((base_height - PLAINS_THRESHOLD) / denom_hills, 0.0, 1.0)
        if t < 0.33:
            return TileScript.VARIANT_C
        if t < 0.66:
            return TileScript.VARIANT_B
        return TileScript.VARIANT_A
    if terrain_type == AssetCatalogScript.TERRAIN_MOUNTAINS:
        var denom_mountains: float = max(1.0 - HILLS_THRESHOLD, 0.0001)
        var tm: float = clampf((base_height - HILLS_THRESHOLD) / denom_mountains, 0.0, 1.0)
        if tm < 0.33:
            return TileScript.VARIANT_A
        if tm < 0.66:
            return TileScript.VARIANT_C
        return TileScript.VARIANT_B
    return ScopedRngScript.rand_variant(rng_state, q, r, "variant", variants)

func _choose_rotation(rng_state: int, q: int, r: int, terrain_type: StringName) -> int:
    var catalog: AssetCatalog = data.asset_catalog
    if catalog == null:
        return 0
    var steps: int = catalog.get_rotation_steps_for_terrain(terrain_type)
    return ScopedRngScript.rand_rotation(rng_state, q, r, "rotation", steps)

func _should_have_trees(
    rng_state: int,
    q: int,
    r: int,
    terrain_type: StringName,
    variant: StringName,
    base_height: float
) -> bool:
    var catalog: AssetCatalog = data.asset_catalog
    if catalog == null:
        return false
    var decor_asset: StringName = catalog.get_terrain_decor_asset(terrain_type, variant)
    if decor_asset == StringName():
        return false
    if terrain_type == AssetCatalogScript.TERRAIN_MOUNTAINS:
        if base_height >= MOUNTAIN_TREELINE_HEIGHT:
            return false
    var probability: float = float(TREE_PROBABILITY.get(terrain_type, 0.0))
    return ScopedRngScript.rand_bool(rng_state, q, r, "trees", probability)
