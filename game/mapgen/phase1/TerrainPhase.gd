extends RefCounted
class_name TerrainPhase

const ScopedRngScript: GDScript = preload("res://mapgen/phase1/ScopedRng.gd")
var BaseHeightGeneratorScript: GDScript = load("res://mapgen/phase1/BaseHeightGenerator.gd")
var RandomFeatureGeneratorScript: GDScript = load("res://mapgen/phase1/RandomFeatureGenerator.gd")
var EdgeShaperScript: GDScript = load("res://mapgen/phase1/EdgeShaper.gd")
const AssetCatalogScript: GDScript = preload("res://mapgen/data/AssetCatalog.gd")
const TileScript: GDScript = preload("res://mapgen/data/Tile.gd")

const SEA_THRESHOLD: float = 0.20
const PLAINS_THRESHOLD: float = 0.55
const HILLS_THRESHOLD: float = 0.75

const VISUAL_BIAS: Dictionary = {
    AssetCatalogScript.TERRAIN_SEA: -0.20,
    AssetCatalogScript.TERRAIN_PLAINS: 0.0,
    AssetCatalogScript.TERRAIN_HILLS: 0.15,
    AssetCatalogScript.TERRAIN_MOUNTAINS: 0.35,
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
    var final_heights: Dictionary = edge_shaper.apply(width, height, feature_heights, config)
    data.clear_tiles()
    var payload: Dictionary = _populate_tiles(map_data, final_heights, rng_state)
    data.set_phase_payload(HexMapData.PHASE_TERRAIN, payload)
    return payload

func _populate_tiles(map_data: MapData, heights: Dictionary, rng_state: int) -> Dictionary:
    var tile_count: int = 0
    for r in range(config.map_height):
        for q in range(config.map_width):
            var axial := Vector2i(q, r)
            var base_height: float = float(heights.get(axial, 0.5))
            var terrain_type: StringName = _classify_height(base_height)
            var visual_height: float = _compute_visual_height(base_height, terrain_type)
            var variant: StringName = _choose_variant(rng_state, q, r, terrain_type)
            var rotation: int = _choose_rotation(rng_state, q, r, terrain_type)
            var with_trees: bool = _should_have_trees(rng_state, q, r, terrain_type, variant)
            var tile: Tile = data.create_tile(q, r, terrain_type, visual_height, rotation, variant, with_trees)
            data.store_tile(tile)
            tile_count += 1
    map_data.set_dimensions(config.map_width, config.map_height)
    return {
        "tiles": tile_count,
        "width": config.map_width,
        "height": config.map_height,
    }

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

func _choose_variant(rng_state: int, q: int, r: int, terrain_type: StringName) -> StringName:
    var catalog: AssetCatalog = data.asset_catalog
    if catalog == null:
        return TileScript.VARIANT_A
    var variants: Array[StringName] = catalog.get_variants_for_terrain(terrain_type)
    if variants.is_empty():
        return TileScript.VARIANT_A
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
    variant: StringName
) -> bool:
    var catalog: AssetCatalog = data.asset_catalog
    if catalog == null:
        return false
    var decor_asset: StringName = catalog.get_terrain_decor_asset(terrain_type, variant)
    if decor_asset == StringName():
        return false
    var probability: float = float(TREE_PROBABILITY.get(terrain_type, 0.0))
    return ScopedRngScript.rand_bool(rng_state, q, r, "trees", probability)
