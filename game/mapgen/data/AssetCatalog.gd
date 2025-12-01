extends RefCounted
class_name AssetCatalog

enum AssetRole { BASE, TERRAIN, DECOR }

const TERRAIN_SEA := StringName("SEA")
const TERRAIN_PLAINS := StringName("PLAINS")
const TERRAIN_HILLS := StringName("HILLS")
const TERRAIN_MOUNTAINS := StringName("MOUNTAINS")

const ALL_TERRAINS: Array[StringName] = [
    TERRAIN_SEA,
    TERRAIN_PLAINS,
    TERRAIN_HILLS,
    TERRAIN_MOUNTAINS,
]

const VARIANT_A := StringName("A")
const VARIANT_B := StringName("B")
const VARIANT_C := StringName("C")

const VARIANT_IDS: Array[StringName] = [
    VARIANT_A,
    VARIANT_B,
    VARIANT_C,
]

const BASE_ASSET_SCENE_PATH := "res://assets/gltf/tiles/base/hex_grass_bottom.gltf"

const TERRAIN_BASE_SCENE_PATHS: Dictionary = {
    TERRAIN_SEA: "res://assets/gltf/tiles/base/hex_water.gltf",
    TERRAIN_PLAINS: "res://assets/gltf/tiles/base/hex_grass.gltf",
    TERRAIN_HILLS: "res://assets/gltf/tiles/base/hex_grass.gltf",
    TERRAIN_MOUNTAINS: "res://assets/gltf/tiles/base/hex_grass.gltf",
}

const TERRAIN_OVERLAY_SCENE_PATHS: Dictionary = {
    TERRAIN_SEA: {
        VARIANT_A: "res://assets/gltf/tiles/base/hex_water.gltf",
        VARIANT_B: "res://assets/gltf/tiles/base/hex_water.gltf",
        VARIANT_C: "res://assets/gltf/tiles/base/hex_water.gltf",
    },
    TERRAIN_PLAINS: {
        VARIANT_A: "res://assets/gltf/tiles/base/hex_grass.gltf",
        VARIANT_B: "res://assets/gltf/tiles/base/hex_grass.gltf",
        VARIANT_C: "res://assets/gltf/tiles/base/hex_grass.gltf",
    },
    TERRAIN_HILLS: {
        VARIANT_A: "res://assets/gltf/decoration/nature/hills_A.gltf",
        VARIANT_B: "res://assets/gltf/decoration/nature/hills_B.gltf",
        VARIANT_C: "res://assets/gltf/decoration/nature/hills_C.gltf",
    },
    TERRAIN_MOUNTAINS: {
        VARIANT_A: "res://assets/gltf/decoration/nature/mountain_A_grass.gltf",
        VARIANT_B: "res://assets/gltf/decoration/nature/mountain_B_grass.gltf",
        VARIANT_C: "res://assets/gltf/decoration/nature/mountain_C_grass.gltf",
    },
}

const TERRAIN_DECOR_SCENE_PATHS: Dictionary = {
    TERRAIN_PLAINS: {
        VARIANT_A: "res://assets/gltf/decoration/nature/trees_A_small.gltf",
        VARIANT_B: "res://assets/gltf/decoration/nature/trees_A_medium.gltf",
        VARIANT_C: "res://assets/gltf/decoration/nature/trees_A_large.gltf",
    },
    TERRAIN_HILLS: {
        VARIANT_A: "res://assets/gltf/decoration/nature/hills_A_trees.gltf",
        VARIANT_B: "res://assets/gltf/decoration/nature/hills_B_trees.gltf",
        VARIANT_C: "res://assets/gltf/decoration/nature/hills_C_trees.gltf",
    },
    TERRAIN_MOUNTAINS: {
        VARIANT_A: "res://assets/gltf/decoration/nature/mountain_A_grass_trees.gltf",
        VARIANT_B: "res://assets/gltf/decoration/nature/mountain_B_grass_trees.gltf",
        VARIANT_C: "res://assets/gltf/decoration/nature/mountain_C_grass_trees.gltf",
    },
}

var base_asset_id: StringName = StringName("base_grass")
var _asset_roles: Dictionary = {}
var _asset_rotation_steps: Dictionary = {}
var _asset_resource_paths: Dictionary = {}
var _terrain_base_assets: Dictionary = {}
var _terrain_overlay_assets: Dictionary = {}
var _terrain_decor_assets: Dictionary = {}
var _terrain_rotation_steps: Dictionary = {}

func _init() -> void:
    _register_default_assets()

func get_base_asset_id() -> StringName:
    return base_asset_id

func get_terrain_base_asset(terrain_type: StringName) -> StringName:
    return _terrain_base_assets.get(terrain_type, StringName())

func get_terrain_overlay_asset(terrain_type: StringName, variant: StringName) -> StringName:
    var variant_map: Dictionary = _terrain_overlay_assets.get(terrain_type, {})
    if variant_map.has(variant):
        return variant_map[variant]
    if variant_map.size() == 0:
        return StringName()
    var first_key: StringName = variant_map.keys()[0]
    return variant_map[first_key]

func get_terrain_decor_asset(terrain_type: StringName, variant: StringName) -> StringName:
    var variant_map: Dictionary = _terrain_decor_assets.get(terrain_type, {})
    if variant_map.has(variant):
        return variant_map[variant]
    if variant_map.has(StringName("default")):
        return variant_map[StringName("default")]
    if variant_map.size() == 0:
        return StringName()
    var first_key: StringName = variant_map.keys()[0]
    return variant_map[first_key]

func get_variants_for_terrain(terrain_type: StringName) -> Array[StringName]:
    var variant_map: Dictionary = _terrain_overlay_assets.get(terrain_type, {})
    if variant_map.size() == 0:
        return VARIANT_IDS.duplicate()
    var variants: Array[StringName] = []
    for variant in variant_map.keys():
        if variant is StringName:
            variants.append(variant)
        else:
            variants.append(StringName(String(variant)))
    variants.sort()
    return variants

func get_rotation_steps(asset_id: StringName) -> int:
    return int(_asset_rotation_steps.get(asset_id, 1))

func get_rotation_steps_for_terrain(terrain_type: StringName) -> int:
    return int(_terrain_rotation_steps.get(terrain_type, 1))

func is_rotatable_terrain(terrain_type: StringName) -> bool:
    return get_rotation_steps_for_terrain(terrain_type) > 1

func get_role(asset_id: StringName) -> AssetRole:
    var stored: int = int(_asset_roles.get(asset_id, AssetRole.BASE))
    match stored:
        AssetRole.BASE:
            return AssetRole.BASE
        AssetRole.TERRAIN:
            return AssetRole.TERRAIN
        AssetRole.DECOR:
            return AssetRole.DECOR
    return AssetRole.BASE

func get_asset_path(asset_id: StringName) -> String:
    return String(_asset_resource_paths.get(asset_id, ""))

func describe_asset(asset_id: StringName) -> Dictionary:
    return {
        "asset_id": String(asset_id),
        "role": role_to_string(get_role(asset_id)),
        "rotation_steps": get_rotation_steps(asset_id),
        "scene_path": get_asset_path(asset_id),
    }

static func role_to_string(role: AssetRole) -> String:
    match role:
        AssetRole.BASE:
            return "BASE"
        AssetRole.TERRAIN:
            return "TERRAIN"
        AssetRole.DECOR:
            return "DECOR"
    return "UNKNOWN"

func _register_default_assets() -> void:
    _clear_registrations()
    _register_asset(base_asset_id, AssetRole.BASE, 1, BASE_ASSET_SCENE_PATH)
    for terrain in ALL_TERRAINS:
        var terrain_key: String = String(terrain).to_lower()
        var base_id: StringName = StringName("terrain_%s_base" % terrain_key)
        _terrain_base_assets[terrain] = base_id
        _register_asset(base_id, AssetRole.TERRAIN, 1, _resolve_scene_path(TERRAIN_BASE_SCENE_PATHS, terrain))
    _terrain_rotation_steps = {
        TERRAIN_SEA: 1,
        TERRAIN_PLAINS: 1,
        TERRAIN_HILLS: 6,
        TERRAIN_MOUNTAINS: 6,
    }
    # Overlay variants are only used for hills and mountains.
    # Plains and sea rely on the terrain base layer plus optional decor.
    _register_terrain_variants(TERRAIN_HILLS, 6, _get_scene_path_map(TERRAIN_OVERLAY_SCENE_PATHS, TERRAIN_HILLS))
    _register_terrain_variants(TERRAIN_MOUNTAINS, 6, _get_scene_path_map(TERRAIN_OVERLAY_SCENE_PATHS, TERRAIN_MOUNTAINS))
    _register_decor_variants(TERRAIN_PLAINS, 1, _get_scene_path_map(TERRAIN_DECOR_SCENE_PATHS, TERRAIN_PLAINS))
    _register_decor_variants(TERRAIN_HILLS, 6, _get_scene_path_map(TERRAIN_DECOR_SCENE_PATHS, TERRAIN_HILLS))
    _register_decor_variants(TERRAIN_MOUNTAINS, 6, _get_scene_path_map(TERRAIN_DECOR_SCENE_PATHS, TERRAIN_MOUNTAINS))

func _clear_registrations() -> void:
    _asset_roles.clear()
    _asset_rotation_steps.clear()
    _asset_resource_paths.clear()
    _terrain_base_assets.clear()
    _terrain_overlay_assets.clear()
    _terrain_decor_assets.clear()
    _terrain_rotation_steps.clear()

func _register_asset(asset_id: StringName, role: AssetRole, rotation_steps: int, scene_path: String) -> void:
    _asset_roles[asset_id] = int(role)
    _asset_rotation_steps[asset_id] = max(1, rotation_steps)
    _asset_resource_paths[asset_id] = scene_path

func _register_terrain_variants(terrain_type: StringName, rotation_steps: int, scene_paths: Dictionary) -> void:
    var variant_map: Dictionary = {}
    var terrain_key: String = String(terrain_type).to_lower()
    for variant in VARIANT_IDS:
        var overlay_id: StringName = StringName("terrain_%s_%s" % [terrain_key, String(variant)])
        variant_map[variant] = overlay_id
        _register_asset(overlay_id, AssetRole.TERRAIN, rotation_steps, _resolve_scene_path(scene_paths, variant))
    _terrain_overlay_assets[terrain_type] = variant_map

func _register_decor_variants(terrain_type: StringName, rotation_steps: int, scene_paths: Dictionary) -> void:
    var variant_map: Dictionary = {}
    if scene_paths.is_empty():
        _terrain_decor_assets[terrain_type] = variant_map
        return
    var terrain_key: String = String(terrain_type).to_lower()
    for variant in VARIANT_IDS:
        var scene_path: String = _resolve_scene_path(scene_paths, variant)
        if scene_path.is_empty():
            continue
        var decor_id: StringName = StringName("decor_%s_trees_%s" % [terrain_key, String(variant)])
        variant_map[variant] = decor_id
        _register_asset(decor_id, AssetRole.DECOR, rotation_steps, scene_path)
    _terrain_decor_assets[terrain_type] = variant_map

func _get_scene_path_map(source: Dictionary, terrain_type: StringName) -> Dictionary:
    var entry: Variant = source.get(terrain_type)
    if typeof(entry) == TYPE_DICTIONARY:
        return entry as Dictionary
    var key: String = String(terrain_type)
    entry = source.get(key)
    if typeof(entry) == TYPE_DICTIONARY:
        return entry as Dictionary
    entry = source.get(key.to_lower())
    if typeof(entry) == TYPE_DICTIONARY:
        return entry as Dictionary
    return {}

func _resolve_scene_path(scene_paths: Dictionary, key: Variant) -> String:
    if scene_paths.has(key):
        return String(scene_paths[key])
    if key is StringName:
        var string_key: String = String(key)
        if scene_paths.has(string_key):
            return String(scene_paths[string_key])
        var lower: String = string_key.to_lower()
        if scene_paths.has(lower):
            return String(scene_paths[lower])
    elif key is String:
        var string_value: String = key
        var name_key: StringName = StringName(string_value)
        if scene_paths.has(name_key):
            return String(scene_paths[name_key])
        var lower_case: String = string_value.to_lower()
        if scene_paths.has(lower_case):
            return String(scene_paths[lower_case])
    return ""
