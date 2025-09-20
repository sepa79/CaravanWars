extends RefCounted
class_name MapData

const AssetCatalog := preload("res://mapgen/data/AssetCatalog.gd")
const Tile := preload("res://mapgen/data/Tile.gd")

var map_seed: int
var width: int
var height: int
var tiles: Dictionary = {}
var phase_payloads: Dictionary = {}
var meta: Dictionary = {}
var terrain_settings: Dictionary = {}
var terrain_metadata: Dictionary = {}
var asset_catalog: AssetCatalog

func _init(
    p_seed: int = 0,
    p_width: int = 0,
    p_height: int = 0,
    p_catalog: AssetCatalog = null
) -> void:
    map_seed = p_seed
    width = max(0, p_width)
    height = max(0, p_height)
    tiles = {}
    phase_payloads = {}
    meta = {}
    terrain_settings = {}
    terrain_metadata = {}
    asset_catalog = p_catalog

func set_catalog(catalog: AssetCatalog) -> void:
    asset_catalog = catalog

func set_dimensions(p_width: int, p_height: int) -> void:
    width = max(0, p_width)
    height = max(0, p_height)

func clear_tiles() -> void:
    tiles.clear()

func set_tile(tile: Tile) -> void:
    if tile == null:
        return
    tiles[tile.axial()] = tile

func get_tile(axial: Vector2i) -> Tile:
    var stored: Variant = tiles.get(axial)
    return stored if stored is Tile else null

func get_tile_at(q: int, r: int) -> Tile:
    return get_tile(Vector2i(q, r))

func set_phase_payload(phase: StringName, payload: Variant) -> void:
    phase_payloads[phase] = payload

func get_phase_payload(phase: StringName) -> Variant:
    return phase_payloads.get(phase)

func clear_phase_payloads() -> void:
    phase_payloads.clear()

func apply_meta(meta_dict: Dictionary) -> void:
    meta = meta_dict.duplicate(true)
    if meta.has("seed"):
        map_seed = int(meta.get("seed", map_seed))

func set_terrain_settings(settings: Dictionary) -> void:
    terrain_settings = settings.duplicate(true)

func set_terrain_metadata(metadata: Dictionary) -> void:
    terrain_metadata = metadata.duplicate(true)

func add_terrain_metadata_entry(key: String, value: Variant) -> void:
    terrain_metadata[key] = value

func get_tiles() -> Array[Tile]:
    var result: Array[Tile] = []
    for value in tiles.values():
        if value is Tile:
            result.append(value)
    return result

func to_dictionary() -> Dictionary:
    var tile_list: Array[Tile] = get_tiles()
    tile_list.sort_custom(Callable(self, "_compare_tiles"))
    var serialized_tiles: Array[Dictionary] = []
    for tile in tile_list:
        serialized_tiles.append(tile.to_serializable(asset_catalog))
    var serialized_meta: Dictionary = meta.duplicate(true)
    if not serialized_meta.has("seed"):
        serialized_meta["seed"] = map_seed
    return {
        "meta": serialized_meta,
        "hexes": serialized_tiles,
        "edges": [],
        "points": [],
        "labels": {},
        "terrain": terrain_metadata.duplicate(true),
        "terrain_settings": terrain_settings.duplicate(true),
    }

func _compare_tiles(a: Tile, b: Tile) -> bool:
    if a == null or b == null:
        return false
    if a.r == b.r:
        return a.q < b.q
    return a.r < b.r
