extends Resource
class_name TerrainSettings

const DEFAULT_SUPPORTED_REGIONS: Array[String] = [
    "plains",
    "valley",
    "hills",
    "mountains",
    "sea",
    "lake",
]

const DEFAULT_REFERENCE_LEVELS: Dictionary = {
    "sea": 0.0,
    "lake": 0.12,
    "valley": 0.2,
    "plains": 0.5,
    "hills": 0.68,
    "mountains": 0.9,
}

const DEFAULT_ELEVATION_JITTER: Dictionary = {
    "sea": 0.02,
    "lake": 0.04,
    "valley": 0.03,
    "plains": 0.05,
    "hills": 0.04,
    "mountains": 0.03,
}

const DEFAULT_RANDOM_FEATURE_TYPES: Array[String] = [
    "mountains",
    "hills",
    "lake",
]

const DEFAULT_RIVER_PREFERENCE_BIAS: Dictionary = {
    "water": {
        "lake": -0.35,
        "sea": -0.25,
    },
    "terrain": {
        "lake": -0.3,
        "valley": -0.2,
        "plains": -0.1,
        "hills": -0.05,
    },
}

const DEFAULT_LAND_REGION_ORDER: Array[String] = [
    "plains",
    "valley",
    "hills",
    "mountains",
]

const DEFAULT_LAND_LAYER_STACK: Dictionary = {
    "plains": [
        {"id": "plain", "mesh_region": "plains"},
    ],
    "valley": [
        {"id": "valley", "mesh_region": "valley"},
    ],
    "hills": [
        {"id": "plain", "mesh_region": "plains"},
        {"id": "hills", "mesh_region": "hills"},
    ],
    "mountains": [
        {"id": "plain", "mesh_region": "plains"},
        {"id": "mountains", "mesh_region": "mountains"},
    ],
}

const DEFAULT_LAND_SURFACE_VARIANT_ORDER: Dictionary = {
    "plains": ["A"],
    "valley": ["A"],
    "hills": ["A", "B", "C"],
    "mountains": ["A", "B", "C"],
}

const DEFAULT_LAND_SURFACE_PATHS: Dictionary = {
    "plains": {
        "A": "res://assets/gltf/tiles/base/hex_grass.gltf",
    },
    "valley": {
        "A": "res://assets/gltf/tiles/base/hex_grass.gltf",
    },
    "hills": {
        "A": "res://assets/gltf/decoration/nature/hills_A.gltf",
        "B": "res://assets/gltf/decoration/nature/hills_B.gltf",
        "C": "res://assets/gltf/decoration/nature/hills_C.gltf",
    },
    "mountains": {
        "A": "res://assets/gltf/decoration/nature/mountain_A.gltf",
        "B": "res://assets/gltf/decoration/nature/mountain_B.gltf",
        "C": "res://assets/gltf/decoration/nature/mountain_C.gltf",
    },
}

const DEFAULT_LAND_BASE_SCENE_PATH := "res://assets/gltf/tiles/base/hex_grass_bottom.gltf"

const DEFAULT_WATER_SCENE_PATHS: Dictionary = {
    "lake": "res://assets/gltf/tiles/base/hex_water.gltf",
    "sea": "res://assets/gltf/tiles/base/hex_water.gltf",
}

const DEFAULT_SHORELINE_SCENE_PATHS: Dictionary = {
    "A": "res://assets/gltf/tiles/coast/hex_coast_A.gltf",
    "B": "res://assets/gltf/tiles/coast/hex_coast_B.gltf",
    "C": "res://assets/gltf/tiles/coast/hex_coast_C.gltf",
    "D": "res://assets/gltf/tiles/coast/hex_coast_D.gltf",
    "E": "res://assets/gltf/tiles/coast/hex_coast_E.gltf",
}

const DEFAULT_RIVER_SCENE_PATHS: Dictionary = {
    "straight": "res://assets/gltf/tiles/rivers/hex_river_A.gltf",
    "source": "res://assets/gltf/tiles/rivers/hex_river_B.gltf",
    "bend": "res://assets/gltf/tiles/rivers/hex_river_C.gltf",
    "alternating": "res://assets/gltf/tiles/rivers/hex_river_D.gltf",
    "fork_left": "res://assets/gltf/tiles/rivers/hex_river_E.gltf",
    "fork_right": "res://assets/gltf/tiles/rivers/hex_river_F.gltf",
    "tee": "res://assets/gltf/tiles/rivers/hex_river_G.gltf",
    "quad_fan": "res://assets/gltf/tiles/rivers/hex_river_H.gltf",
    "quad_split": "res://assets/gltf/tiles/rivers/hex_river_I.gltf",
    "cross": "res://assets/gltf/tiles/rivers/hex_river_J.gltf",
    "flood": "res://assets/gltf/tiles/rivers/hex_river_K.gltf",
    "mouth": "res://assets/gltf/tiles/rivers/hex_river_L.gltf",
}

const DEFAULT_RIVER_VARIANT_DEFINITIONS: Array = [
    {"key": "straight", "mask": 9},
    {"key": "source", "mask": 10},
    {"key": "bend", "mask": 12},
    {"key": "alternating", "mask": 42},
    {"key": "fork_left", "mask": 11},
    {"key": "fork_right", "mask": 41},
    {"key": "tee", "mask": 28},
    {"key": "quad_fan", "mask": 29},
    {"key": "quad_split", "mask": 54},
    {"key": "cross", "mask": 57},
    {"key": "flood", "mask": 62},
    {"key": "mouth", "mask": 63, "is_mouth": true},
]

const DEFAULT_LAND_DEFAULT_ELEVATION: float = 0.35

var supported_regions: Array[String] = []
var reference_levels: Dictionary = {}
var elevation_jitter: Dictionary = {}
var random_feature_types: Array[String] = []
var river_preference_bias: Dictionary = {}
var land_region_order: Array[String] = []
var land_layer_stack: Dictionary = {}
var land_surface_variant_order: Dictionary = {}
var land_surface_paths: Dictionary = {}
var land_base_scene_path: String = ""
var water_scene_paths: Dictionary = {}
var shoreline_scene_paths: Dictionary = {}
var river_scene_paths: Dictionary = {}
var river_variant_definitions: Array = []
var default_land_elevation: float = DEFAULT_LAND_DEFAULT_ELEVATION

func _init(overrides: Dictionary = {}) -> void:
    reset_to_defaults()
    if not overrides.is_empty():
        apply_overrides(overrides)

func reset_to_defaults() -> void:
    supported_regions = DEFAULT_SUPPORTED_REGIONS.duplicate()
    reference_levels = _duplicate_dictionary(DEFAULT_REFERENCE_LEVELS)
    elevation_jitter = _duplicate_dictionary(DEFAULT_ELEVATION_JITTER)
    random_feature_types = DEFAULT_RANDOM_FEATURE_TYPES.duplicate()
    river_preference_bias = _duplicate_dictionary(DEFAULT_RIVER_PREFERENCE_BIAS)
    land_region_order = DEFAULT_LAND_REGION_ORDER.duplicate()
    land_layer_stack = _duplicate_dictionary(DEFAULT_LAND_LAYER_STACK)
    land_surface_variant_order = _duplicate_dictionary(DEFAULT_LAND_SURFACE_VARIANT_ORDER)
    land_surface_paths = _duplicate_dictionary(DEFAULT_LAND_SURFACE_PATHS)
    land_base_scene_path = DEFAULT_LAND_BASE_SCENE_PATH
    water_scene_paths = _duplicate_dictionary(DEFAULT_WATER_SCENE_PATHS)
    shoreline_scene_paths = _duplicate_dictionary(DEFAULT_SHORELINE_SCENE_PATHS)
    river_scene_paths = _duplicate_dictionary(DEFAULT_RIVER_SCENE_PATHS)
    river_variant_definitions = _duplicate_array(DEFAULT_RIVER_VARIANT_DEFINITIONS)
    default_land_elevation = DEFAULT_LAND_DEFAULT_ELEVATION

func apply_overrides(overrides: Dictionary) -> void:
    if overrides.has("supported_regions"):
        supported_regions = _duplicate_string_array(overrides["supported_regions"])
    if overrides.has("reference_levels"):
        reference_levels = _duplicate_dictionary(overrides["reference_levels"])
    if overrides.has("elevation_jitter"):
        elevation_jitter = _duplicate_dictionary(overrides["elevation_jitter"])
    if overrides.has("random_feature_types"):
        random_feature_types = _duplicate_string_array(overrides["random_feature_types"])
    if overrides.has("river_preference_bias"):
        river_preference_bias = _duplicate_dictionary(overrides["river_preference_bias"])
    if overrides.has("land_region_order"):
        land_region_order = _duplicate_string_array(overrides["land_region_order"])
    if overrides.has("land_layer_stack"):
        land_layer_stack = _duplicate_dictionary(overrides["land_layer_stack"])
    if overrides.has("land_surface_variant_order"):
        land_surface_variant_order = _duplicate_dictionary(overrides["land_surface_variant_order"])
    if overrides.has("land_surface_paths"):
        land_surface_paths = _duplicate_dictionary(overrides["land_surface_paths"])
    if overrides.has("land_base_scene_path"):
        land_base_scene_path = String(overrides["land_base_scene_path"])
    if overrides.has("water_scene_paths"):
        water_scene_paths = _duplicate_dictionary(overrides["water_scene_paths"])
    if overrides.has("shoreline_scene_paths"):
        shoreline_scene_paths = _duplicate_dictionary(overrides["shoreline_scene_paths"])
    if overrides.has("river_scene_paths"):
        river_scene_paths = _duplicate_dictionary(overrides["river_scene_paths"])
    if overrides.has("river_variant_definitions"):
        river_variant_definitions = _duplicate_array(overrides["river_variant_definitions"])
    if overrides.has("default_land_elevation"):
        default_land_elevation = float(overrides["default_land_elevation"])

func duplicate_settings():
    var script: Script = get_script()
    var clone = script.new()
    if clone != null and clone.has_method("apply_overrides"):
        clone.apply_overrides(to_dictionary())
    return clone

func to_dictionary() -> Dictionary:
    return {
        "supported_regions": supported_regions.duplicate(),
        "reference_levels": _duplicate_dictionary(reference_levels),
        "elevation_jitter": _duplicate_dictionary(elevation_jitter),
        "random_feature_types": random_feature_types.duplicate(),
        "river_preference_bias": _duplicate_dictionary(river_preference_bias),
        "land_region_order": land_region_order.duplicate(),
        "land_layer_stack": _duplicate_dictionary(land_layer_stack),
        "land_surface_variant_order": _duplicate_dictionary(land_surface_variant_order),
        "land_surface_paths": _duplicate_dictionary(land_surface_paths),
        "land_base_scene_path": land_base_scene_path,
        "water_scene_paths": _duplicate_dictionary(water_scene_paths),
        "shoreline_scene_paths": _duplicate_dictionary(shoreline_scene_paths),
        "river_scene_paths": _duplicate_dictionary(river_scene_paths),
        "river_variant_definitions": _duplicate_array(river_variant_definitions),
        "default_land_elevation": default_land_elevation,
    }

func _duplicate_dictionary(source: Variant) -> Dictionary:
    var duplicated: Dictionary = {}
    if typeof(source) != TYPE_DICTIONARY:
        return duplicated
    for key in (source as Dictionary).keys():
        var value: Variant = source[key]
        match typeof(value):
            TYPE_DICTIONARY:
                duplicated[key] = _duplicate_dictionary(value)
            TYPE_ARRAY:
                duplicated[key] = _duplicate_array(value)
            TYPE_STRING:
                duplicated[key] = String(value)
            TYPE_FLOAT, TYPE_INT:
                duplicated[key] = float(value)
            TYPE_BOOL:
                duplicated[key] = bool(value)
            _:
                duplicated[key] = value
    return duplicated

func _duplicate_array(source: Variant) -> Array:
    var duplicated: Array = []
    if typeof(source) != TYPE_ARRAY:
        return duplicated
    for value in source:
        match typeof(value):
            TYPE_DICTIONARY:
                duplicated.append(_duplicate_dictionary(value))
            TYPE_ARRAY:
                duplicated.append(_duplicate_array(value))
            TYPE_STRING:
                duplicated.append(String(value))
            TYPE_FLOAT, TYPE_INT:
                duplicated.append(float(value))
            TYPE_BOOL:
                duplicated.append(bool(value))
            _:
                duplicated.append(value)
    return duplicated

func _duplicate_string_array(source: Variant) -> Array[String]:
    var duplicated: Array[String] = []
    if typeof(source) != TYPE_ARRAY:
        return duplicated
    for value in source:
        duplicated.append(String(value))
    return duplicated
