extends Control
class_name MapView

signal cities_changed(cities: Array)

const TerrainSettingsResource := preload("res://map/TerrainSettings.gd")
const RIVER_MASK_BIT_COUNT := 6

class RiverTileInfo:
    var axial_coord: Vector2i
    var mask_bits: int
    var variant_key: String
    var rotation_steps: int
    var river_class: int
    var is_mouth: bool

    func _init(
        axial_coord_value: Vector2i = Vector2i.ZERO,
        mask_bits_value: int = 0,
        variant_key_value: String = "",
        rotation_steps_value: int = 0,
        river_class_value: int = 1,
        is_mouth_value: bool = false
    ) -> void:
        axial_coord = axial_coord_value
        mask_bits = mask_bits_value
        variant_key = variant_key_value
        rotation_steps = rotation_steps_value
        river_class = river_class_value
        is_mouth = is_mouth_value

    func to_dictionary() -> Dictionary:
        return {
            "coord": axial_coord,
            "mask_bits": mask_bits,
            "variant": variant_key,
            "rotation_steps": rotation_steps,
            "river_class": river_class,
            "is_mouth": is_mouth,
        }

var map_data: Dictionary = {}

var _terrain_settings = TerrainSettingsResource.new()
var _terrain_asset_map: Dictionary = {}
var _river_tiles: Dictionary[Vector2i, RiverTileInfo] = {}
var _show_rivers: bool = true

func _ready() -> void:
    _rebuild_assets()

func set_map_data(data: Dictionary) -> void:
    map_data = _duplicate_dictionary(data)
    _load_terrain_settings_from_data(map_data)
    _cache_river_entries()
    _rebuild_assets()
    cities_changed.emit([])

func set_edit_mode(_value: bool) -> void:
    pass

func set_road_mode(_mode: String) -> void:
    pass

func set_road_class(_cls: String) -> void:
    pass

func set_show_roads(_value: bool) -> void:
    pass

func set_show_rivers(value: bool) -> void:
    _show_rivers = value

func set_region_visibility(_region_id: String, _fully_visible: bool) -> void:
    pass

func set_land_base_visibility(_fully_visible: bool) -> void:
    pass

func set_show_cities(_value: bool) -> void:
    pass

func set_show_villages(_value: bool) -> void:
    pass

func set_show_crossroads(_value: bool) -> void:
    pass

func set_show_bridges(_value: bool) -> void:
    pass

func set_show_fords(_value: bool) -> void:
    pass

func set_show_regions(_value: bool) -> void:
    pass

func set_show_forts(_value: bool) -> void:
    pass

func set_show_fertility(_value: bool) -> void:
    pass

func set_show_roughness(_value: bool) -> void:
    pass

func get_kingdom_colors() -> Dictionary:
    return {}

func get_terrain_asset_map() -> Dictionary:
    return _duplicate_dictionary(_terrain_asset_map)

func get_river_tiles() -> Dictionary:
    var result: Dictionary = {}
    for axial in _river_tiles.keys():
        var info: RiverTileInfo = _river_tiles[axial]
        if info == null:
            continue
        result[axial] = info.to_dictionary()
    return result

func _load_terrain_settings_from_data(data: Dictionary) -> void:
    var settings_data: Variant = data.get("terrain_settings")
    _terrain_settings = TerrainSettingsResource.new()
    if typeof(settings_data) == TYPE_DICTIONARY:
        _terrain_settings.apply_overrides(settings_data)

func _rebuild_assets() -> void:
    _terrain_asset_map = _build_asset_map()

func _build_asset_map() -> Dictionary:
    return {
        "land_base": _terrain_settings.land_base_scene_path,
        "land_surfaces": _duplicate_dictionary(_terrain_settings.land_surface_paths),
        "water": _duplicate_dictionary(_terrain_settings.water_scene_paths),
        "shorelines": _duplicate_dictionary(_terrain_settings.shoreline_scene_paths),
        "rivers": _duplicate_dictionary(_terrain_settings.river_scene_paths),
        "river_variants": _duplicate_array(_terrain_settings.river_variant_definitions),
    }

func _cache_river_entries() -> void:
    _river_tiles.clear()
    var hex_list: Array = map_data.get("hexes", [])
    for entry_variant in hex_list:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_variant
        var axial_coord: Variant = _extract_axial(entry.get("coord"))
        if axial_coord == null:
            continue
        var raw_mask := int(entry.get("river_mask", 0))
        var mask_bits := raw_mask & ((1 << RIVER_MASK_BIT_COUNT) - 1)
        var is_mouth := bool(entry.get("is_mouth", false))
        var variant_key := String(entry.get("river_variant", ""))
        if mask_bits == 0 and not is_mouth:
            continue
        if variant_key.is_empty():
            continue
        var rotation_steps := int(entry.get("river_rotation", 0))
        var class_value: int = max(int(entry.get("river_class", 1)), 1)
        var info := RiverTileInfo.new(axial_coord, mask_bits, variant_key, rotation_steps, class_value, is_mouth)
        _river_tiles[axial_coord] = info

func _extract_axial(coord_variant: Variant) -> Variant:
    if coord_variant is Vector2i:
        return coord_variant
    if coord_variant is Vector2:
        var vector := coord_variant as Vector2
        return Vector2i(int(round(vector.x)), int(round(vector.y)))
    if coord_variant is Array and coord_variant.size() >= 2:
        var array := coord_variant as Array
        return Vector2i(int(array[0]), int(array[1]))
    return null

func _duplicate_dictionary(source: Variant) -> Dictionary:
    var copy: Dictionary = {}
    if typeof(source) != TYPE_DICTIONARY:
        return copy
    for key in (source as Dictionary).keys():
        var value: Variant = (source as Dictionary)[key]
        match typeof(value):
            TYPE_DICTIONARY:
                copy[key] = _duplicate_dictionary(value)
            TYPE_ARRAY:
                copy[key] = _duplicate_array(value)
            _:
                copy[key] = value
    return copy

func _duplicate_array(source: Variant) -> Array:
    var copy: Array = []
    if typeof(source) != TYPE_ARRAY:
        return copy
    for value in source:
        match typeof(value):
            TYPE_DICTIONARY:
                copy.append(_duplicate_dictionary(value))
            TYPE_ARRAY:
                copy.append(_duplicate_array(value))
            _:
                copy.append(value)
    return copy
