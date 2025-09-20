extends Control
class_name MapView

# Scene layout: ViewportContainer (MapView) -> SubViewport (own World3D) -> TerrainRoot (Node3D)

signal cities_changed(cities: Array)

const LAND_BASE_SCENE := preload("res://assets/gltf/tiles/base/hex_grass_bottom.gltf")

const LAND_SURFACE_SCENES: Dictionary = {
    "plains": {
        "A": preload("res://assets/gltf/tiles/base/hex_grass.gltf"),
    },
    "valley": {
        "A": preload("res://assets/gltf/tiles/base/hex_grass.gltf"),
    },
    "hills": {
        "A": preload("res://assets/gltf/decoration/nature/hills_A.gltf"),
        "B": preload("res://assets/gltf/decoration/nature/hills_B.gltf"),
        "C": preload("res://assets/gltf/decoration/nature/hills_C.gltf"),
    },
    "mountains": {
        "A": preload("res://assets/gltf/decoration/nature/mountain_A.gltf"),
        "B": preload("res://assets/gltf/decoration/nature/mountain_B.gltf"),
        "C": preload("res://assets/gltf/decoration/nature/mountain_C.gltf"),
    },
}

const LAND_REGION_ORDER := ["plains", "valley", "hills", "mountains"]

const LAND_SURFACE_VARIANT_ORDER: Dictionary = {
    "plains": ["A"],
    "valley": ["A"],
    "hills": ["A", "B", "C"],
    "mountains": ["A", "B", "C"],
}

const LAND_REFERENCE_LEVELS: Dictionary = {
    "sea": 0.0,
    "lake": 0.12,
    "valley": 0.2,
    "plains": 0.5,
    "hills": 0.68,
    "mountains": 0.9,
}

const LAND_LAYER_STACK: Dictionary = {
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

const REGION_SCENES: Dictionary = {
    "plains": {
        "base": LAND_BASE_SCENE,
        "surfaces": LAND_SURFACE_SCENES["plains"],
    },
    "hills": {
        "base": LAND_BASE_SCENE,
        "surfaces": LAND_SURFACE_SCENES["hills"],
    },
    "mountains": {
        "base": LAND_BASE_SCENE,
        "surfaces": LAND_SURFACE_SCENES["mountains"],
    },
    "valley": {
        "base": LAND_BASE_SCENE,
        "surfaces": LAND_SURFACE_SCENES["valley"],
    },
    "lake": preload("res://assets/gltf/tiles/base/hex_water.gltf"),
    "sea": preload("res://assets/gltf/tiles/base/hex_water.gltf"),
}

const SHORELINE_SCENES: Dictionary = {
    "A": preload("res://assets/gltf/tiles/coast/hex_coast_A.gltf"),
    "B": preload("res://assets/gltf/tiles/coast/hex_coast_B.gltf"),
    "C": preload("res://assets/gltf/tiles/coast/hex_coast_C.gltf"),
    "D": preload("res://assets/gltf/tiles/coast/hex_coast_D.gltf"),
    "E": preload("res://assets/gltf/tiles/coast/hex_coast_E.gltf"),
}

const RIVER_SCENES: Dictionary = {
    "straight": preload("res://assets/gltf/tiles/rivers/hex_river_A.gltf"),
    "source": preload("res://assets/gltf/tiles/rivers/hex_river_B.gltf"),
    "bend": preload("res://assets/gltf/tiles/rivers/hex_river_C.gltf"),
    "alternating": preload("res://assets/gltf/tiles/rivers/hex_river_D.gltf"),
    "fork_left": preload("res://assets/gltf/tiles/rivers/hex_river_E.gltf"),
    "fork_right": preload("res://assets/gltf/tiles/rivers/hex_river_F.gltf"),
    "tee": preload("res://assets/gltf/tiles/rivers/hex_river_G.gltf"),
    "quad_fan": preload("res://assets/gltf/tiles/rivers/hex_river_H.gltf"),
    "quad_split": preload("res://assets/gltf/tiles/rivers/hex_river_I.gltf"),
    "cross": preload("res://assets/gltf/tiles/rivers/hex_river_J.gltf"),
    "flood": preload("res://assets/gltf/tiles/rivers/hex_river_K.gltf"),
    "mouth": preload("res://assets/gltf/tiles/rivers/hex_river_L.gltf"),
}

const RIVER_VARIANT_DEFINITIONS: Array = [
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

const RIVER_MASK_BIT_COUNT := 6
const RIVER_ROTATION_STEP: float = PI / 3.0
const RIVER_Y_OFFSET: float = 0.05
const RIVER_CLASS_SCALE_STEP: float = 0.03
const RIVER_MARKER_HEIGHT: float = 0.4
const RIVER_MARKER_RADIUS: float = 0.18

const HEX_WORLD_SCALE: float = 1.0
const CAMERA_BASE_HEIGHT: float = 26.0
const CAMERA_HEIGHT_PER_UNIT: float = 0.45
const CAMERA_DISTANCE_FACTOR: float = 1.65
const CAMERA_MIN_DISTANCE: float = 32.0
const CAMERA_ORBIT_DIRECTION: Vector3 = Vector3(0.573462, 0.0, 0.819232)
const DEFAULT_CAMERA_ORIGIN: Vector3 = Vector3(0.0, 28.0, 36.0)
const DEFAULT_CAMERA_TARGET: Vector3 = Vector3.ZERO
const LIGHT_DIRECTION: Vector3 = Vector3(-0.45, -1.0, -0.35)
const LIGHT_ENERGY: float = 1.35
const LIGHT_INDIRECT_ENERGY: float = 0.85
const CAMERA_ZOOM_IN_FACTOR: float = 0.85
const CAMERA_ZOOM_OUT_FACTOR: float = 1.15
const CAMERA_MIN_ZOOM: float = 0.35
const CAMERA_MAX_ZOOM: float = 3.0
const CAMERA_PAN_BASE: float = 0.005
const CAMERA_ROTATE_SPEED: float = 0.01
const CAMERA_PAN_MARGIN_RATIO: float = 0.25
const CAMERA_PAN_MARGIN_MIN: float = 4.0

const LAND_DEFAULT_ELEVATION: float = 0.35
const LAND_ELEVATION_SCALE: float = 1.0
const LAND_BASE_MIN_HEIGHT: float = 0.05
const LAND_SURFACE_PIVOT_EPSILON: float = 0.0001
const LAND_LAYER_MIN_THICKNESS: float = 0.02
const LAND_LAYER_MIN_GAP: float = 0.01
const TERRAIN_TRANSPARENCY_VISIBLE: float = 0.0
const TERRAIN_TRANSPARENCY_DIMMED: float = 0.5

var map_data: Dictionary = {}

var _mesh_library: Dictionary = {}
var _region_layers: Dictionary = {}
var _river_layers: Dictionary = {}
var _river_marker_layer: MultiMeshInstance3D
var _river_tile_cache: Dictionary = {}
var _river_mask_lookup: Dictionary = _create_river_mask_lookup()
var _needs_refresh: bool = false
var _map_bounds: Dictionary = {}
var _camera_zoom: float = 1.0
var _camera_orbit_yaw: float = 0.0
var _camera_pan_offset: Vector2 = Vector2.ZERO
var _camera_pan_bounds_min: Vector2 = Vector2.ZERO
var _camera_pan_bounds_max: Vector2 = Vector2.ZERO
var _map_extent_radius: float = 1.0
var _is_panning: bool = false
var _is_rotating: bool = false
var _show_rivers: bool = true
var _region_transparency: Dictionary = {}
var _land_base_transparency: float = TERRAIN_TRANSPARENCY_VISIBLE
var _land_grass_top: float = 0.0
var _land_grass_height: float = LAND_BASE_MIN_HEIGHT

var _viewport: SubViewport
var _terrain_root: Node3D
var _viewport_container: Control
var _input_capture: Control
var _camera_rig: Node3D
var _camera: Camera3D
var _sun_light: DirectionalLight3D

func _ready() -> void:
    _ensure_viewport_structure()
    _configure_viewport()
    _build_mesh_library()
    _ensure_region_layers()
    call_deferred("_complete_preview_setup")
    _update_camera_framing()
    _needs_refresh = true
    _refresh_layers_if_needed()

func _exit_tree() -> void:
    if _viewport != null:
        _viewport.world_3d = null

func set_map_data(data: Dictionary) -> void:
    map_data = data
    _cache_river_entries()
    if data.is_empty():
        _reset_camera_state()
    _needs_refresh = true
    _refresh_layers_if_needed()
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
    _update_river_visibility()

func set_region_visibility(region: String, fully_visible: bool) -> void:
    if region == "land_base":
        set_land_base_visibility(fully_visible)
        return
    var transparency := TERRAIN_TRANSPARENCY_VISIBLE if fully_visible else TERRAIN_TRANSPARENCY_DIMMED
    _region_transparency[region] = transparency
    _apply_region_transparency(region)

func set_land_base_visibility(fully_visible: bool) -> void:
    var transparency := TERRAIN_TRANSPARENCY_VISIBLE if fully_visible else TERRAIN_TRANSPARENCY_DIMMED
    if is_equal_approx(transparency, _land_base_transparency):
        return
    _land_base_transparency = transparency
    _apply_land_base_transparency()

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

func _configure_viewport() -> void:
    if _viewport == null:
        return
    if _viewport.world_3d == null:
        _viewport.world_3d = World3D.new()
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _ensure_viewport_structure() -> void:
    _viewport_container = _locate_container()
    if _viewport_container == null:
        _viewport_container = _create_container()
    if _viewport_container == null:
        return
    _viewport = _locate_viewport(_viewport_container)
    if _viewport == null:
        _viewport = SubViewport.new()
        _viewport.name = "TerrainViewport"
        _viewport.unique_name_in_owner = true
        _viewport.own_world_3d = true
        _viewport.world_3d = World3D.new()
        _viewport_container.add_child(_viewport)
    _terrain_root = _viewport.get_node_or_null("TerrainRoot") as Node3D
    if _terrain_root == null:
        _terrain_root = Node3D.new()
        _terrain_root.name = "TerrainRoot"
        _terrain_root.unique_name_in_owner = true
        _viewport.add_child(_terrain_root)
    _ensure_input_capture()
    _configure_input_capture()

func _locate_container() -> Control:
    if is_class("SubViewportContainer"):
        return self
    var named := get_node_or_null("%ViewportFrame")
    if named is SubViewportContainer:
        return named
    for child in get_children():
        if child is SubViewportContainer:
            return child
    return null

func _create_container() -> SubViewportContainer:
    if not (self is Control):
        return null
    var container := SubViewportContainer.new()
    container.name = "ViewportFrame"
    container.unique_name_in_owner = true
    container.stretch = true
    container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(container)
    container.owner = self.owner
    return container

func _locate_viewport(container: Node = null) -> SubViewport:
    if container == null:
        container = self
    if container.has_node("%TerrainViewport"):
        var named_viewport := container.get_node("%TerrainViewport")
        if named_viewport is SubViewport:
            return named_viewport as SubViewport
    for child in container.get_children():
        if child is SubViewport:
            return child as SubViewport
    return null

func _ensure_input_capture() -> void:
    if not (self is Control):
        return
    if _input_capture == null:
        _input_capture = Control.new()
        _input_capture.name = "InputCapture"
        _input_capture.unique_name_in_owner = true
        _input_capture.mouse_filter = Control.MOUSE_FILTER_STOP
        _input_capture.focus_mode = Control.FOCUS_ALL
        _input_capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(_input_capture)
        if self.owner != null:
            _input_capture.owner = self.owner
    else:
        _input_capture.mouse_filter = Control.MOUSE_FILTER_STOP
        _input_capture.focus_mode = Control.FOCUS_ALL
        _input_capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _input_capture.z_index = 1

func _build_mesh_library() -> void:
    _mesh_library = {
        "land_base": null,
        "land_surfaces": {},
        "water": {},
        "shorelines": {},
        "rivers": {},
        "river_marker": null,
    }
    for region in REGION_SCENES.keys():
        var definition: Variant = REGION_SCENES[region]
        if definition is PackedScene:
            var water_mesh: Mesh = _extract_mesh(definition)
            if water_mesh != null:
                _mesh_library["water"][region] = water_mesh
            continue
        if typeof(definition) != TYPE_DICTIONARY:
            continue
        var land_definition: Dictionary = definition
        if _mesh_library["land_base"] == null:
            var base_scene: Variant = land_definition.get("base")
            if base_scene is PackedScene:
                var base_mesh: Mesh = _extract_mesh(base_scene)
                if base_mesh != null:
                    _mesh_library["land_base"] = base_mesh
        var surface_definition: Variant = land_definition.get("surfaces")
        if typeof(surface_definition) != TYPE_DICTIONARY:
            continue
        var surface_meshes: Dictionary = {}
        for variant_key in (surface_definition as Dictionary).keys():
            var surface_scene: Variant = surface_definition[variant_key]
            if not (surface_scene is PackedScene):
                continue
            var surface_mesh: Mesh = _extract_mesh(surface_scene)
            if surface_mesh != null:
                surface_meshes[variant_key] = surface_mesh
        if not surface_meshes.is_empty():
            _mesh_library["land_surfaces"][region] = surface_meshes
    for case_key in SHORELINE_SCENES.keys():
        var coast_scene: PackedScene = SHORELINE_SCENES[case_key]
        var coast_mesh: Mesh = _extract_mesh(coast_scene)
        if coast_mesh != null:
            _mesh_library["shorelines"][case_key] = coast_mesh
    var river_meshes: Dictionary = {}
    for variant in RIVER_SCENES.keys():
        var river_scene: PackedScene = RIVER_SCENES[variant]
        var river_mesh: Mesh = _extract_mesh(river_scene)
        if river_mesh != null:
            river_meshes[variant] = river_mesh
    _mesh_library["rivers"] = river_meshes
    _mesh_library["river_marker"] = _build_river_marker_mesh()

func _extract_mesh(scene: PackedScene) -> Mesh:
    if scene == null:
        return null
    var root: Node = scene.instantiate()
    var mesh: Mesh = _find_first_mesh(root)
    root.free()
    return mesh

func _find_first_mesh(node: Node) -> Mesh:
    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        if instance.mesh != null:
            return instance.mesh
    for child in node.get_children():
        if child is Node:
            var mesh: Mesh = _find_first_mesh(child)
            if mesh != null:
                return mesh
    return null

func _build_river_marker_mesh() -> Mesh:
    var marker := CylinderMesh.new()
    marker.top_radius = RIVER_MARKER_RADIUS
    marker.bottom_radius = RIVER_MARKER_RADIUS
    marker.height = RIVER_MARKER_HEIGHT
    marker.radial_segments = 12
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.2, 0.6, 1.0, 0.85)
    material.metallic = 0.0
    material.roughness = 0.35
    marker.material = material
    return marker

func _ensure_region_layers() -> void:
    if _terrain_root == null:
        return
    var land_surfaces: Dictionary = _mesh_library.get("land_surfaces", {})
    var land_base_mesh: Mesh = _mesh_library.get("land_base")
    if land_base_mesh != null:
        if _region_layers.has("land_base") and typeof(_region_layers["land_base"]) != TYPE_DICTIONARY:
            var legacy_base: Variant = _region_layers["land_base"]
            if legacy_base is MultiMeshInstance3D and is_instance_valid(legacy_base):
                (legacy_base as MultiMeshInstance3D).queue_free()
            _region_layers.erase("land_base")
        if not _region_layers.has("land_base") or typeof(_region_layers["land_base"]) != TYPE_DICTIONARY:
            _region_layers["land_base"] = {}
        var base_layers_variant: Variant = _region_layers.get("land_base")
        var base_layers: Dictionary = {}
        if typeof(base_layers_variant) == TYPE_DICTIONARY:
            base_layers = base_layers_variant
        else:
            base_layers = {}
            _region_layers["land_base"] = base_layers
        for region in land_surfaces.keys():
            var base_instance: MultiMeshInstance3D = base_layers.get(region, null)
            if base_instance == null:
                base_instance = MultiMeshInstance3D.new()
                base_instance.name = "%sBaseLayer" % region.capitalize()
                base_instance.unique_name_in_owner = true
                _terrain_root.add_child(base_instance)
                base_layers[region] = base_instance
            if base_instance.multimesh == null:
                base_instance.multimesh = MultiMesh.new()
            base_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
            base_instance.multimesh.mesh = land_base_mesh
            var base_transparency: float = max(_get_region_transparency(region), _land_base_transparency)
            base_instance.transparency = base_transparency
    elif _region_layers.has("land_base") and typeof(_region_layers["land_base"]) == TYPE_DICTIONARY:
        var cleanup_base_layers: Variant = _region_layers.get("land_base")
        if typeof(cleanup_base_layers) == TYPE_DICTIONARY:
            var base_layers: Dictionary = cleanup_base_layers
            for instance_variant in base_layers.values():
                if instance_variant is MultiMeshInstance3D:
                    (instance_variant as MultiMeshInstance3D).queue_free()
        _region_layers.erase("land_base")
    if not _region_layers.has("land_surfaces") or typeof(_region_layers["land_surfaces"]) != TYPE_DICTIONARY:
        _region_layers["land_surfaces"] = {}
    var surface_layers_variant: Variant = _region_layers.get("land_surfaces")
    var surface_layers: Dictionary = {}
    if typeof(surface_layers_variant) == TYPE_DICTIONARY:
        surface_layers = surface_layers_variant
    else:
        surface_layers = {}
        _region_layers["land_surfaces"] = surface_layers
    for region in LAND_LAYER_STACK.keys():
        var layer_definitions_variant: Variant = LAND_LAYER_STACK.get(region, [])
        if typeof(layer_definitions_variant) != TYPE_ARRAY:
            continue
        var layer_definitions: Array = layer_definitions_variant
        if layer_definitions.is_empty():
            continue
        var region_layers_variant: Variant = surface_layers.get(region)
        var region_layers: Dictionary = {}
        if typeof(region_layers_variant) == TYPE_DICTIONARY:
            region_layers = region_layers_variant
        surface_layers[region] = region_layers
        for layer_definition_variant in layer_definitions:
            if typeof(layer_definition_variant) != TYPE_DICTIONARY:
                continue
            var layer_definition: Dictionary = layer_definition_variant
            var layer_id := String(layer_definition.get("id", ""))
            if layer_id.is_empty():
                continue
            var mesh_region := String(layer_definition.get("mesh_region", region))
            var mesh_map_variant: Variant = land_surfaces.get(mesh_region, {})
            if typeof(mesh_map_variant) != TYPE_DICTIONARY:
                continue
            var mesh_map: Dictionary = mesh_map_variant
            if mesh_map.is_empty():
                continue
            var variant_layers_variant: Variant = region_layers.get(layer_id)
            var variant_layers: Dictionary = {}
            if typeof(variant_layers_variant) == TYPE_DICTIONARY:
                variant_layers = variant_layers_variant
            region_layers[layer_id] = variant_layers
            var ordered_variants: Array = LAND_SURFACE_VARIANT_ORDER.get(mesh_region, [])
            var processed_variants: Array = []
            for variant_key in ordered_variants:
                if not mesh_map.has(variant_key):
                    continue
                var mesh: Mesh = mesh_map[variant_key]
                if mesh == null:
                    continue
                _ensure_surface_layer_instance(variant_layers, region, layer_id, variant_key, mesh)
                processed_variants.append(variant_key)
            for variant_key in mesh_map.keys():
                if processed_variants.has(variant_key):
                    continue
                var mesh: Mesh = mesh_map[variant_key]
                if mesh == null:
                    continue
                _ensure_surface_layer_instance(variant_layers, region, layer_id, variant_key, mesh)
    if not _region_layers.has("water") or typeof(_region_layers["water"]) != TYPE_DICTIONARY:
        _region_layers["water"] = {}
    var water_layers_variant: Variant = _region_layers.get("water")
    var water_layers: Dictionary = {}
    if typeof(water_layers_variant) == TYPE_DICTIONARY:
        water_layers = water_layers_variant
    else:
        water_layers = {}
        _region_layers["water"] = water_layers
    var water_meshes: Dictionary = _mesh_library.get("water", {})
    for region in water_meshes.keys():
        var mesh: Mesh = water_meshes[region]
        if mesh == null:
            continue
        var existing_instance: MultiMeshInstance3D = water_layers.get(region, null)
        if existing_instance == null:
            var multimesh := MultiMesh.new()
            multimesh.transform_format = MultiMesh.TRANSFORM_3D
            multimesh.mesh = mesh
            var instance := MultiMeshInstance3D.new()
            instance.name = "%sRegionLayer" % region.capitalize()
            instance.unique_name_in_owner = true
            instance.multimesh = multimesh
            _terrain_root.add_child(instance)
            water_layers[region] = instance
            existing_instance = instance
        else:
            if existing_instance.multimesh == null:
                existing_instance.multimesh = MultiMesh.new()
        existing_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        existing_instance.multimesh.mesh = mesh
        existing_instance.transparency = _get_region_transparency(region)
    _apply_all_region_transparency()

func _ensure_surface_layer_instance(region_layers: Dictionary, region: String, layer_id: String, variant_key: String, mesh: Mesh) -> void:
    if not region_layers.has(layer_id) or typeof(region_layers[layer_id]) != TYPE_DICTIONARY:
        region_layers[layer_id] = {}
    var layer_map: Dictionary = region_layers[layer_id]
    var instance: MultiMeshInstance3D = layer_map.get(variant_key, null)
    if instance == null:
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh
        instance = MultiMeshInstance3D.new()
        instance.name = _format_surface_layer_name(region, layer_id, variant_key)
        instance.unique_name_in_owner = true
        instance.multimesh = multimesh
        _terrain_root.add_child(instance)
        layer_map[variant_key] = instance
    else:
        if instance.multimesh == null:
            instance.multimesh = MultiMesh.new()
        instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        instance.multimesh.mesh = mesh
    instance.transparency = _get_region_transparency(region)
    region_layers[layer_id] = layer_map

func _format_surface_layer_name(region: String, layer_id: String, variant_key: String) -> String:
    var name_prefix := region.capitalize()
    var layer_suffix := layer_id.capitalize()
    var variant_suffix := variant_key.capitalize() if not variant_key.is_empty() else ""
    if variant_suffix.is_empty():
        return "%s%sLayer" % [name_prefix, layer_suffix]
    return "%s%sLayer%s" % [name_prefix, layer_suffix, variant_suffix]

func _merge_bounds_with_aabb(min_pos: Vector3, max_pos: Vector3, has_positions: bool, aabb: AABB) -> Dictionary:
    var start: Vector3 = aabb.position
    var end: Vector3 = aabb.position + aabb.size
    return _merge_bounds_with_points(min_pos, max_pos, has_positions, start, end)

func _merge_bounds_with_point(min_pos: Vector3, max_pos: Vector3, has_positions: bool, point: Vector3) -> Dictionary:
    return _merge_bounds_with_points(min_pos, max_pos, has_positions, point, point)

func _merge_bounds_with_points(min_pos: Vector3, max_pos: Vector3, has_positions: bool, start: Vector3, end: Vector3) -> Dictionary:
    if not has_positions:
        return {
            "min": start,
            "max": end,
            "has": true,
        }
    var updated_min := Vector3(
        min(min_pos.x, start.x),
        min(min_pos.y, start.y),
        min(min_pos.z, start.z)
    )
    var updated_max := Vector3(
        max(max_pos.x, end.x),
        max(max_pos.y, end.y),
        max(max_pos.z, end.z)
    )
    return {
        "min": updated_min,
        "max": updated_max,
        "has": true,
    }

func _transform_aabb(aabb: AABB, transform: Transform3D) -> AABB:
    var start: Vector3 = aabb.position
    var end: Vector3 = aabb.position + aabb.size
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    for xi in range(2):
        var x := start.x if xi == 0 else end.x
        for yi in range(2):
            var y := start.y if yi == 0 else end.y
            for zi in range(2):
                var z := start.z if zi == 0 else end.z
                var corner := transform * Vector3(x, y, z)
                min_corner.x = min(min_corner.x, corner.x)
                min_corner.y = min(min_corner.y, corner.y)
                min_corner.z = min(min_corner.z, corner.z)
                max_corner.x = max(max_corner.x, corner.x)
                max_corner.y = max(max_corner.y, corner.y)
                max_corner.z = max(max_corner.z, corner.z)
    return AABB(min_corner, max_corner - min_corner)

func _get_region_transparency(region: String) -> float:
    var stored: Variant = _region_transparency.get(region, TERRAIN_TRANSPARENCY_VISIBLE)
    if typeof(stored) == TYPE_FLOAT or typeof(stored) == TYPE_INT:
        return clampf(float(stored), 0.0, 1.0)
    return TERRAIN_TRANSPARENCY_VISIBLE

func _apply_region_transparency(region: String) -> void:
    var transparency := _get_region_transparency(region)
    if _region_layers.has("land_base") and typeof(_region_layers["land_base"]) == TYPE_DICTIONARY:
        var base_layers_variant: Variant = _region_layers.get("land_base")
        if typeof(base_layers_variant) == TYPE_DICTIONARY:
            var base_layers: Dictionary = base_layers_variant
            if base_layers.has(region):
                var base_instance: Variant = base_layers[region]
                if base_instance is MultiMeshInstance3D:
                    var combined: float = max(transparency, _land_base_transparency)
                    (base_instance as MultiMeshInstance3D).transparency = combined
    if _region_layers.has("land_surfaces") and typeof(_region_layers["land_surfaces"]) == TYPE_DICTIONARY:
        var surface_layers_variant: Variant = _region_layers.get("land_surfaces")
        if typeof(surface_layers_variant) == TYPE_DICTIONARY:
            var surface_layers: Dictionary = surface_layers_variant
            if surface_layers.has(region):
                var region_layers_variant: Variant = surface_layers[region]
                if typeof(region_layers_variant) == TYPE_DICTIONARY:
                    var region_layers: Dictionary = region_layers_variant
                    for layer_id in region_layers.keys():
                        var variant_layers_variant: Variant = region_layers[layer_id]
                        if typeof(variant_layers_variant) != TYPE_DICTIONARY:
                            continue
                        var variant_layers: Dictionary = variant_layers_variant
                        for variant_key in variant_layers.keys():
                            var instance_variant: Variant = variant_layers[variant_key]
                            if instance_variant is MultiMeshInstance3D:
                                (instance_variant as MultiMeshInstance3D).transparency = transparency
    if _region_layers.has("water") and typeof(_region_layers["water"]) == TYPE_DICTIONARY:
        var water_layers_variant: Variant = _region_layers.get("water")
        if typeof(water_layers_variant) == TYPE_DICTIONARY:
            var water_layers: Dictionary = water_layers_variant
            if water_layers.has(region):
                var water_instance: Variant = water_layers[region]
                if water_instance is MultiMeshInstance3D:
                    (water_instance as MultiMeshInstance3D).transparency = transparency

func _apply_all_region_transparency() -> void:
    for region in _region_transparency.keys():
        _apply_region_transparency(String(region))
    _apply_land_base_transparency()

func _apply_land_base_transparency() -> void:
    if not _region_layers.has("land_base"):
        return
    var base_layers_variant: Variant = _region_layers["land_base"]
    if typeof(base_layers_variant) != TYPE_DICTIONARY:
        return
    var base_layers: Dictionary = base_layers_variant
    for key in base_layers.keys():
        var base_instance: Variant = base_layers[key]
        if not (base_instance is MultiMeshInstance3D):
            continue
        var region := String(key)
        var region_transparency := _get_region_transparency(region)
        var combined: float = max(region_transparency, _land_base_transparency)
        (base_instance as MultiMeshInstance3D).transparency = combined

func _refresh_layers_if_needed() -> void:
    if not _needs_refresh:
        return
    if not is_inside_tree():
        return
    _needs_refresh = false
    _update_region_layers()
    _update_river_layers()

func _update_region_layers() -> void:
    var grouped_hexes := _group_hexes_by_region()
    var min_pos := Vector3(INF, INF, INF)
    var max_pos := Vector3(-INF, -INF, -INF)
    var has_positions := false
    var land_surfaces: Dictionary = _mesh_library.get("land_surfaces", {})
    var land_surface_layers: Dictionary = {}
    if _region_layers.has("land_surfaces") and typeof(_region_layers["land_surfaces"]) == TYPE_DICTIONARY:
        var surface_layers_variant: Variant = _region_layers.get("land_surfaces")
        if typeof(surface_layers_variant) == TYPE_DICTIONARY:
            land_surface_layers = surface_layers_variant
    var ordered_land_regions: Array = _ordered_land_regions(land_surfaces)
    var land_base_layers: Dictionary = {}
    if _region_layers.has("land_base") and typeof(_region_layers["land_base"]) == TYPE_DICTIONARY:
        var base_layers_variant: Variant = _region_layers.get("land_base")
        if typeof(base_layers_variant) == TYPE_DICTIONARY:
            land_base_layers = base_layers_variant
    var land_base_mesh: Mesh = _mesh_library.get("land_base")
    var land_base_aabb := AABB()
    if land_base_mesh != null:
        land_base_aabb = land_base_mesh.get_aabb()
    var grass_stack := _compute_grass_stack(grouped_hexes)
    _land_grass_top = float(grass_stack.get("top", 0.0))
    _land_grass_height = max(float(grass_stack.get("height", LAND_BASE_MIN_HEIGHT)), LAND_BASE_MIN_HEIGHT)
    var surface_counts: Dictionary = {}
    for region in ordered_land_regions:
        var hex_entries: Array = grouped_hexes.get(region, [])
        var layer_definitions_variant: Variant = LAND_LAYER_STACK.get(region, [])
        if typeof(layer_definitions_variant) != TYPE_ARRAY:
            surface_counts[region] = {}
            continue
        var layer_definitions: Array = layer_definitions_variant
        var region_counts: Dictionary = {}
        for layer_definition_variant in layer_definitions:
            if typeof(layer_definition_variant) != TYPE_DICTIONARY:
                continue
            var layer_definition: Dictionary = layer_definition_variant
            var layer_id := String(layer_definition.get("id", ""))
            if layer_id.is_empty():
                continue
            var mesh_region := String(layer_definition.get("mesh_region", region))
            var mesh_map_variant: Variant = land_surfaces.get(mesh_region, {})
            if typeof(mesh_map_variant) != TYPE_DICTIONARY:
                continue
            var mesh_map: Dictionary = mesh_map_variant
            if mesh_map.is_empty():
                continue
            var layer_counts: Dictionary = {}
            for entry_variant in hex_entries:
                if typeof(entry_variant) != TYPE_DICTIONARY:
                    continue
                var entry: Dictionary = entry_variant
                if _should_skip_layer_entry(region, layer_id, entry):
                    continue
                var axial := _coord_to_axial(entry.get("coord"))
                var variant_key := _select_land_surface_variant(mesh_region, axial)
                if variant_key.is_empty():
                    continue
                if not mesh_map.has(variant_key):
                    continue
                layer_counts[variant_key] = int(layer_counts.get(variant_key, 0)) + 1
            region_counts[layer_id] = layer_counts
        surface_counts[region] = region_counts
    var surface_indices: Dictionary = {}
    if typeof(land_surface_layers) == TYPE_DICTIONARY:
        for region in land_surface_layers.keys():
            var region_layers_variant: Variant = land_surface_layers[region]
            if typeof(region_layers_variant) != TYPE_DICTIONARY:
                continue
            var region_layers: Dictionary = region_layers_variant
            var region_counts_variant: Variant = surface_counts.get(region, {})
            var region_counts: Dictionary = {}
            if typeof(region_counts_variant) == TYPE_DICTIONARY:
                region_counts = region_counts_variant
            var layer_indices: Dictionary = {}
            for layer_id in region_layers.keys():
                var variant_layers_variant: Variant = region_layers[layer_id]
                if typeof(variant_layers_variant) != TYPE_DICTIONARY:
                    continue
                var variant_layers: Dictionary = variant_layers_variant
                var counts_variant: Variant = region_counts.get(layer_id, {})
                var counts: Dictionary = {}
                if typeof(counts_variant) == TYPE_DICTIONARY:
                    counts = counts_variant
                var variant_indices: Dictionary = {}
                for variant_key in variant_layers.keys():
                    var instance_variant: Variant = variant_layers[variant_key]
                    if not (instance_variant is MultiMeshInstance3D):
                        continue
                    var surface_instance := instance_variant as MultiMeshInstance3D
                    if surface_instance.multimesh == null:
                        continue
                    var target_count := int(counts.get(variant_key, 0))
                    surface_instance.multimesh.instance_count = target_count
                    variant_indices[variant_key] = 0
                layer_indices[layer_id] = variant_indices
            surface_indices[region] = layer_indices
    var base_indices: Dictionary = {}
    for region in ordered_land_regions:
        var hex_entries: Array = grouped_hexes.get(region, [])
        var base_instance_variant: Variant = land_base_layers.get(region)
        var base_multimesh: MultiMesh = null
        if base_instance_variant is MultiMeshInstance3D:
            var base_instance := base_instance_variant as MultiMeshInstance3D
            base_multimesh = base_instance.multimesh
            if base_multimesh != null:
                base_multimesh.instance_count = hex_entries.size()
        var base_index := 0
        var layer_definitions_variant: Variant = LAND_LAYER_STACK.get(region, [])
        var layer_definitions: Array = []
        if typeof(layer_definitions_variant) == TYPE_ARRAY:
            layer_definitions = layer_definitions_variant
        var layer_indices_variant: Variant = surface_indices.get(region, {})
        var layer_indices: Dictionary = {}
        if typeof(layer_indices_variant) == TYPE_DICTIONARY:
            layer_indices = layer_indices_variant
        for entry_variant in hex_entries:
            if typeof(entry_variant) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = entry_variant
            var axial := _coord_to_axial(entry.get("coord"))
            var world_center := _axial_to_world(axial)
            var world_height := _world_height_from_entry(entry)
            if base_multimesh != null and base_index < base_multimesh.instance_count:
                var base_transform := _make_land_base_transform(land_base_mesh, land_base_aabb, world_center, _land_grass_top, _land_grass_height)
                base_multimesh.set_instance_transform(base_index, base_transform)
                if land_base_mesh != null:
                    var transformed_base := _transform_aabb(land_base_aabb, base_transform)
                    var merged_base := _merge_bounds_with_aabb(min_pos, max_pos, has_positions, transformed_base)
                    min_pos = merged_base.get("min", min_pos)
                    max_pos = merged_base.get("max", max_pos)
                    has_positions = bool(merged_base.get("has", has_positions))
                else:
                    var merged_base_point := _merge_bounds_with_point(min_pos, max_pos, has_positions, base_transform.origin)
                    min_pos = merged_base_point.get("min", min_pos)
                    max_pos = merged_base_point.get("max", max_pos)
                    has_positions = bool(merged_base_point.get("has", has_positions))
                base_index += 1
            if layer_definitions.is_empty():
                continue
            var plain_top := _determine_plain_top(region, world_height, _land_grass_top)
            var valley_top := _determine_valley_top(world_height, _land_grass_top)
            for layer_definition_variant in layer_definitions:
                if typeof(layer_definition_variant) != TYPE_DICTIONARY:
                    continue
                var layer_definition: Dictionary = layer_definition_variant
                var layer_id := String(layer_definition.get("id", ""))
                if layer_id.is_empty():
                    continue
                if _should_skip_layer_entry(region, layer_id, entry):
                    continue
                var mesh_region := String(layer_definition.get("mesh_region", region))
                var variant_key := _select_land_surface_variant(mesh_region, axial)
                if variant_key.is_empty():
                    continue
                var region_layer_variant: Variant = land_surface_layers.get(region, {})
                if typeof(region_layer_variant) != TYPE_DICTIONARY:
                    continue
                var region_layer_map: Dictionary = region_layer_variant
                if not region_layer_map.has(layer_id):
                    continue
                var variant_layers_variant: Variant = region_layer_map.get(layer_id)
                if typeof(variant_layers_variant) != TYPE_DICTIONARY:
                    continue
                var variant_layers: Dictionary = variant_layers_variant
                if not variant_layers.has(variant_key):
                    continue
                var surface_instance_variant: Variant = variant_layers[variant_key]
                if not (surface_instance_variant is MultiMeshInstance3D):
                    continue
                var surface_instance := surface_instance_variant as MultiMeshInstance3D
                var surface_multimesh := surface_instance.multimesh
                if surface_multimesh == null:
                    continue
                var variant_index_variant: Variant = layer_indices.get(layer_id, {})
                var variant_index_map: Dictionary = {}
                if typeof(variant_index_variant) == TYPE_DICTIONARY:
                    variant_index_map = variant_index_variant
                var variant_index := int(variant_index_map.get(variant_key, 0))
                if variant_index >= surface_multimesh.instance_count:
                    continue
                var surface_mesh: Mesh = surface_multimesh.mesh
                if surface_mesh == null:
                    var mesh_map_variant: Variant = land_surfaces.get(mesh_region, {})
                    if typeof(mesh_map_variant) == TYPE_DICTIONARY and mesh_map_variant.has(variant_key):
                        var mapped_mesh_variant: Variant = mesh_map_variant[variant_key]
                        if mapped_mesh_variant is Mesh:
                            surface_mesh = mapped_mesh_variant
                var top_height := world_height
                var bottom_height := _land_grass_top
                if layer_id == "plain":
                    top_height = plain_top
                    bottom_height = _land_grass_top
                elif layer_id == "valley":
                    top_height = valley_top
                    bottom_height = _land_grass_top
                elif layer_id == "hills" or layer_id == "mountains":
                    bottom_height = plain_top
                var surface_transform := _make_land_surface_transform(surface_mesh, world_center, top_height, bottom_height)
                surface_multimesh.set_instance_transform(variant_index, surface_transform)
                if surface_mesh != null:
                    var surface_aabb := surface_mesh.get_aabb()
                    var transformed_surface := _transform_aabb(surface_aabb, surface_transform)
                    var merged_surface := _merge_bounds_with_aabb(min_pos, max_pos, has_positions, transformed_surface)
                    min_pos = merged_surface.get("min", min_pos)
                    max_pos = merged_surface.get("max", max_pos)
                    has_positions = bool(merged_surface.get("has", has_positions))
                else:
                    var merged_surface_point := _merge_bounds_with_point(min_pos, max_pos, has_positions, surface_transform.origin)
                    min_pos = merged_surface_point.get("min", min_pos)
                    max_pos = merged_surface_point.get("max", max_pos)
                    has_positions = bool(merged_surface_point.get("has", has_positions))
                variant_index_map[variant_key] = variant_index + 1
                layer_indices[layer_id] = variant_index_map
            surface_indices[region] = layer_indices
        base_indices[region] = base_index
    for region in land_base_layers.keys():
        var base_instance_variant: Variant = land_base_layers[region]
        if not (base_instance_variant is MultiMeshInstance3D):
            continue
        var base_instance := base_instance_variant as MultiMeshInstance3D
        if base_instance.multimesh == null:
            continue
        var final_count_variant: Variant = base_indices.get(region, 0)
        base_instance.multimesh.instance_count = int(final_count_variant)
    for region in surface_indices.keys():
        var region_layers_variant: Variant = land_surface_layers.get(region, {})
        if typeof(region_layers_variant) != TYPE_DICTIONARY:
            continue
        var region_layers: Dictionary = region_layers_variant
        var layer_indices_variant: Variant = surface_indices.get(region, {})
        if typeof(layer_indices_variant) != TYPE_DICTIONARY:
            continue
        var layer_indices: Dictionary = layer_indices_variant
        for layer_id in layer_indices.keys():
            if not region_layers.has(layer_id):
                continue
            var variant_layers_variant: Variant = region_layers.get(layer_id)
            if typeof(variant_layers_variant) != TYPE_DICTIONARY:
                continue
            var variant_layers: Dictionary = variant_layers_variant
            var variant_index_variant: Variant = layer_indices.get(layer_id, {})
            if typeof(variant_index_variant) != TYPE_DICTIONARY:
                continue
            var variant_index_map: Dictionary = variant_index_variant
            for variant_key in variant_index_map.keys():
                if not variant_layers.has(variant_key):
                    continue
                var surface_instance_variant: Variant = variant_layers[variant_key]
                if not (surface_instance_variant is MultiMeshInstance3D):
                    continue
                var surface_instance := surface_instance_variant as MultiMeshInstance3D
                if surface_instance.multimesh == null:
                    continue
                surface_instance.multimesh.instance_count = int(variant_index_map.get(variant_key, 0))
    if _region_layers.has("water") and typeof(_region_layers["water"]) == TYPE_DICTIONARY:
        var water_layers_variant: Variant = _region_layers.get("water")
        if typeof(water_layers_variant) == TYPE_DICTIONARY:
            var water_layers: Dictionary = water_layers_variant
            for region in water_layers.keys():
                var water_instance: MultiMeshInstance3D = water_layers[region]
                if water_instance == null or water_instance.multimesh == null:
                    continue
                var hex_entries: Array = grouped_hexes.get(region, [])
                var water_multimesh := water_instance.multimesh
                water_multimesh.instance_count = hex_entries.size()
                var water_mesh: Mesh = water_multimesh.mesh
                var index: int = 0
                for entry_variant in hex_entries:
                    if typeof(entry_variant) != TYPE_DICTIONARY:
                        continue
                    var entry: Dictionary = entry_variant
                    var axial := _coord_to_axial(entry.get("coord"))
                    var world_position := _axial_to_world(axial)
                    var water_transform := Transform3D(Basis.IDENTITY, world_position)
                    if index < water_multimesh.instance_count:
                        water_multimesh.set_instance_transform(index, water_transform)
                        if water_mesh != null:
                            var water_aabb := water_mesh.get_aabb()
                            var transformed_water := _transform_aabb(water_aabb, water_transform)
                            var merged_water := _merge_bounds_with_aabb(min_pos, max_pos, has_positions, transformed_water)
                            min_pos = merged_water.get("min", min_pos)
                            max_pos = merged_water.get("max", max_pos)
                            has_positions = bool(merged_water.get("has", has_positions))
                        else:
                            var merged_water_point := _merge_bounds_with_point(min_pos, max_pos, has_positions, world_position)
                            min_pos = merged_water_point.get("min", min_pos)
                            max_pos = merged_water_point.get("max", max_pos)
                            has_positions = bool(merged_water_point.get("has", has_positions))
                        index += 1
                water_multimesh.instance_count = index
    if has_positions:
        _map_bounds = {
            "min": min_pos,
            "max": max_pos,
        }
        var span_x: float = abs(max_pos.x - min_pos.x)
        var span_z: float = abs(max_pos.z - min_pos.z)
        _map_extent_radius = max(max(span_x, span_z) * 0.5, 1.0)
        _update_pan_bounds(min_pos, max_pos)
    else:
        _map_bounds = {}
        _map_extent_radius = 1.0
        _camera_pan_bounds_min = Vector2.ZERO
        _camera_pan_bounds_max = Vector2.ZERO
    _update_camera_framing()
    _apply_all_region_transparency()

func _group_hexes_by_region() -> Dictionary:
    if not map_data.has("hexes"):
        return {}
    var grouped: Dictionary = {}
    var entries: Variant = map_data["hexes"]
    if typeof(entries) != TYPE_ARRAY:
        return grouped
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var region := String(entry.get("region", ""))
        if region.is_empty():
            region = "plains"
        if not grouped.has(region):
            grouped[region] = []
        grouped[region].append(entry)
    return grouped

func _world_height_from_entry(entry: Dictionary) -> float:
    var raw_value: Variant = entry.get("elev", LAND_DEFAULT_ELEVATION)
    var elevation := _sanitize_elevation(raw_value)
    return _elevation_to_world_height(elevation)

func _sanitize_elevation(value: Variant) -> float:
    var elevation := LAND_DEFAULT_ELEVATION
    var value_type := typeof(value)
    if value_type == TYPE_FLOAT or value_type == TYPE_INT:
        elevation = float(value)
    elif value_type == TYPE_STRING:
        var parsed := String(value).to_float()
        if not is_nan(parsed) and not is_inf(parsed):
            elevation = parsed
    if is_nan(elevation) or is_inf(elevation):
        elevation = LAND_DEFAULT_ELEVATION
    elevation = clampf(elevation, 0.0, 1.0)
    return elevation

func _elevation_to_world_height(elevation: float) -> float:
    var scaled := elevation * LAND_ELEVATION_SCALE
    if scaled < 0.0:
        return 0.0
    return scaled

func _resolve_reference_height(region: String) -> float:
    var value_variant: Variant = LAND_REFERENCE_LEVELS.get(region, 0.0)
    if typeof(value_variant) == TYPE_FLOAT or typeof(value_variant) == TYPE_INT:
        return float(value_variant)
    return 0.0

func _resolve_region_reference_height(grouped_hexes: Dictionary, region: String, fallback: float) -> float:
    var entries_variant: Variant = grouped_hexes.get(region, [])
    if typeof(entries_variant) == TYPE_ARRAY:
        for entry_variant in entries_variant:
            if typeof(entry_variant) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = entry_variant
            return _world_height_from_entry(entry)
    return fallback

func _compute_grass_stack(grouped_hexes: Dictionary) -> Dictionary:
    var default_sea := _resolve_reference_height("sea")
    var sea_height := _resolve_region_reference_height(grouped_hexes, "sea", default_sea)
    var water_meshes: Dictionary = _mesh_library.get("water", {})
    var sea_mesh: Mesh = null
    if water_meshes.has("sea"):
        sea_mesh = water_meshes["sea"]
    elif water_meshes.has("lake"):
        sea_mesh = water_meshes["lake"]
    var sea_aabb := AABB()
    if sea_mesh != null:
        sea_aabb = sea_mesh.get_aabb()
    var sea_height_extent := sea_aabb.size.y
    if sea_height_extent <= LAND_SURFACE_PIVOT_EPSILON:
        sea_height_extent = LAND_REFERENCE_LEVELS.get("lake", 0.12) * 0.5
    var grass_height: float = max(sea_height_extent * 0.5, LAND_BASE_MIN_HEIGHT)
    var grass_top: float = sea_height - sea_height_extent * 0.5
    return {
        "top": grass_top,
        "height": grass_height,
    }

func _determine_plain_top(region: String, world_height: float, grass_top: float) -> float:
    var min_top := grass_top + LAND_LAYER_MIN_THICKNESS
    var max_top: float = max(world_height - LAND_LAYER_MIN_GAP, min_top)
    if region == "plains":
        return max(world_height, min_top)
    var reference := _resolve_reference_height("plains")
    return clampf(reference, min_top, max_top)

func _determine_valley_top(world_height: float, grass_top: float) -> float:
    var min_top := grass_top + LAND_LAYER_MIN_THICKNESS
    return max(world_height, min_top)

func _should_skip_layer_entry(region: String, layer_id: String, entry: Dictionary) -> bool:
    if layer_id == "valley":
        var mask := int(entry.get("river_mask", 0))
        if mask != 0:
            return true
    return false

func _make_land_base_transform(base_mesh: Mesh, base_aabb: AABB, world_center: Vector3, world_height: float, base_height: float) -> Transform3D:
    var origin := Vector3(world_center.x, world_height, world_center.z)
    var basis := Basis.IDENTITY
    if base_mesh == null:
        basis = basis.scaled(Vector3(1.0, base_height, 1.0))
        return Transform3D(basis, origin)
    var min_y: float = base_aabb.position.y
    var height: float = base_aabb.size.y
    var max_y: float = min_y + height
    var safe_height: float = max(height, LAND_SURFACE_PIVOT_EPSILON)
    var y_scale: float = base_height / safe_height
    basis = basis.scaled(Vector3(1.0, y_scale, 1.0))
    origin.y = world_height - max_y * y_scale
    return Transform3D(basis, origin)

func _make_land_surface_transform(surface_mesh: Mesh, world_center: Vector3, layer_top: float, layer_bottom: float) -> Transform3D:
    var origin := Vector3(world_center.x, layer_top, world_center.z)
    var basis := Basis.IDENTITY
    if surface_mesh == null:
        return Transform3D(basis, origin)
    var surface_aabb := surface_mesh.get_aabb()
    var min_y: float = surface_aabb.position.y
    var height: float = surface_aabb.size.y
    var max_y: float = min_y + height
    var desired_height: float = max(layer_top - layer_bottom, LAND_SURFACE_PIVOT_EPSILON)
    if max_y <= LAND_SURFACE_PIVOT_EPSILON:
        var safe_height: float = max(height, LAND_SURFACE_PIVOT_EPSILON)
        var y_scale: float = desired_height / safe_height
        basis = basis.scaled(Vector3(1.0, y_scale, 1.0))
        origin.y = layer_top - max_y * y_scale
    else:
        origin.y = layer_bottom - min_y
    return Transform3D(basis, origin)

func _select_land_surface_variant(mesh_region: String, axial: Vector2i) -> String:
    var variant_list: Array = []
    var defined_variants: Variant = LAND_SURFACE_VARIANT_ORDER.get(mesh_region, [])
    if defined_variants is Array:
        variant_list = (defined_variants as Array).duplicate()
    var surface_meshes: Dictionary = _mesh_library.get("land_surfaces", {}).get(mesh_region, {})
    if variant_list.is_empty():
        variant_list = surface_meshes.keys()
        variant_list.sort()
    if variant_list.is_empty():
        return ""
    if variant_list.size() == 1:
        return String(variant_list[0])
    var hashed := _hash_axial_coord(axial)
    if hashed < 0:
        hashed = -hashed
    var index := hashed % variant_list.size()
    return String(variant_list[index])

func _hash_axial_coord(coord: Vector2i) -> int:
    var hash := int(coord.x) * 92837111
    hash ^= int(coord.y) * 689287499
    hash ^= hash >> 13
    hash &= 0x7fffffff
    return hash

func _ordered_land_regions(land_surfaces: Dictionary) -> Array:
    var ordered: Array = []
    for region in LAND_REGION_ORDER:
        if land_surfaces.has(region):
            ordered.append(region)
    for region in land_surfaces.keys():
        if ordered.has(region):
            continue
        ordered.append(region)
    return ordered

func _cache_river_entries() -> void:
    _river_tile_cache.clear()
    if not map_data.has("hexes"):
        return
    var entries: Variant = map_data["hexes"]
    if typeof(entries) != TYPE_ARRAY:
        return
    for entry_variant in entries:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_variant
        var raw_mask := int(entry.get("river_mask", 0))
        var is_mouth := bool(entry.get("is_mouth", false))
        if raw_mask == 0 and not is_mouth:
            continue
        var axial := _coord_to_axial(entry.get("coord"))
        var variant_info := _resolve_river_variant(raw_mask, is_mouth)
        var variant := String(variant_info.get("variant", ""))
        if variant.is_empty():
            continue
        var rotation := int(variant_info.get("rotation", 0))
        var class_value := int(entry.get("river_class", 1))
        if class_value <= 0:
            class_value = 1
        var cached_entry := {
            "coord": axial,
            "mask": raw_mask & ((1 << RIVER_MASK_BIT_COUNT) - 1),
            "river_class": class_value,
            "is_mouth": is_mouth,
            "variant": variant,
            "rotation": rotation,
        }
        _river_tile_cache[axial] = cached_entry

func _count_bits(value: int) -> int:
    var count := 0
    var working := value
    while working != 0:
        working &= working - 1
        count += 1
    return count

func _resolve_river_variant(mask: int, is_mouth: bool) -> Dictionary:
    if is_mouth:
        return {
            "variant": "mouth",
            "rotation": 0,
        }
    var sanitized_mask := mask & ((1 << RIVER_MASK_BIT_COUNT) - 1)
    if sanitized_mask == 0:
        return {}
    var lookup_value: Variant = _river_mask_lookup.get(sanitized_mask)
    if typeof(lookup_value) == TYPE_DICTIONARY:
        return (lookup_value as Dictionary).duplicate()
    return _find_best_river_variant(sanitized_mask)

func _rotate_mask(mask: int, steps: int) -> int:
    var rotated := 0
    for i in range(RIVER_MASK_BIT_COUNT):
        if (mask & (1 << i)) == 0:
            continue
        var new_index := (i + steps) % RIVER_MASK_BIT_COUNT
        rotated |= 1 << new_index
    return rotated

func _create_river_mask_lookup() -> Dictionary:
    var lookup: Dictionary = {}
    for definition_variant in RIVER_VARIANT_DEFINITIONS:
        if typeof(definition_variant) != TYPE_DICTIONARY:
            continue
        var definition: Dictionary = definition_variant
        var key := String(definition.get("key", ""))
        if key.is_empty():
            continue
        var canonical := int(definition.get("mask", 0))
        if canonical <= 0:
            continue
        for rotation in range(RIVER_MASK_BIT_COUNT):
            var rotated := _rotate_mask(canonical, rotation)
            if rotated == 0:
                continue
            if lookup.has(rotated):
                continue
            lookup[rotated] = {
                "variant": key,
                "rotation": rotation,
            }
    return lookup

func _find_best_river_variant(mask: int) -> Dictionary:
    var best_variant := ""
    var best_rotation := 0
    var best_overlap := -1
    for definition_variant in RIVER_VARIANT_DEFINITIONS:
        if typeof(definition_variant) != TYPE_DICTIONARY:
            continue
        var definition: Dictionary = definition_variant
        var key := String(definition.get("key", ""))
        if key.is_empty():
            continue
        var canonical := int(definition.get("mask", 0))
        if canonical <= 0:
            continue
        for rotation in range(RIVER_MASK_BIT_COUNT):
            var rotated := _rotate_mask(canonical, rotation)
            if rotated == mask:
                return {
                    "variant": key,
                    "rotation": rotation,
                }
            var overlap := _count_bits(mask & rotated)
            if overlap > best_overlap:
                best_overlap = overlap
                best_variant = key
                best_rotation = rotation
    if best_variant.is_empty():
        return {}
    return {
        "variant": best_variant,
        "rotation": best_rotation,
    }

func _scale_vector_for_class(class_value: int) -> Vector3:
    var factor := 1.0 + float(max(class_value - 1, 0)) * RIVER_CLASS_SCALE_STEP
    return Vector3(factor, 1.0, factor)

func _get_or_create_river_layer(class_value: int, variant: String) -> MultiMeshInstance3D:
    if _terrain_root == null:
        return null
    if not _river_layers.has(class_value):
        _river_layers[class_value] = {}
    var variant_layers: Dictionary = _river_layers[class_value]
    if variant_layers.has(variant):
        var existing: Variant = variant_layers[variant]
        if existing is MultiMeshInstance3D:
            return existing
    var river_meshes: Dictionary = _mesh_library.get("rivers", {})
    var mesh: Mesh = river_meshes.get(variant)
    if mesh == null:
        return null
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    var instance := MultiMeshInstance3D.new()
    instance.name = "River%sClass%d" % [variant.capitalize(), class_value]
    instance.multimesh = multimesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.visible = _show_rivers
    _terrain_root.add_child(instance)
    variant_layers[variant] = instance
    _river_layers[class_value] = variant_layers
    return instance

func _ensure_river_marker_layer() -> MultiMeshInstance3D:
    if _terrain_root == null:
        return null
    if _river_marker_layer != null and _river_marker_layer.multimesh != null:
        return _river_marker_layer
    var marker_mesh: Mesh = _mesh_library.get("river_marker")
    if marker_mesh == null:
        return null
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = marker_mesh
    var instance := MultiMeshInstance3D.new()
    instance.name = "RiverMouthMarkers"
    instance.multimesh = multimesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.visible = _show_rivers
    _terrain_root.add_child(instance)
    _river_marker_layer = instance
    return instance

func _update_river_layers() -> void:
    if _terrain_root == null:
        return
    var grouped: Dictionary = {}
    var mouth_entries: Array = []
    for info_variant in _river_tile_cache.values():
        if typeof(info_variant) != TYPE_DICTIONARY:
            continue
        var info: Dictionary = info_variant
        var variant := String(info.get("variant", ""))
        if variant.is_empty():
            continue
        var class_value := int(info.get("river_class", 1))
        if class_value <= 0:
            class_value = 1
        if not grouped.has(class_value):
            grouped[class_value] = {}
        var variant_map: Dictionary = grouped[class_value]
        if not variant_map.has(variant):
            variant_map[variant] = []
        var list: Array = variant_map[variant]
        list.append(info)
        variant_map[variant] = list
        grouped[class_value] = variant_map
        if bool(info.get("is_mouth", false)):
            mouth_entries.append(info)
    var used_keys: Dictionary = {}
    for class_value in grouped.keys():
        var variant_map: Dictionary = grouped[class_value]
        for variant in variant_map.keys():
            var entries: Array = variant_map[variant]
            var instance := _get_or_create_river_layer(class_value, variant)
            if instance == null:
                continue
            var multimesh := instance.multimesh
            if multimesh == null:
                continue
            instance.visible = _show_rivers
            var count := entries.size()
            multimesh.instance_count = count
            for index in range(count):
                var entry: Dictionary = entries[index]
                var axial: Vector2i = entry.get("coord", Vector2i.ZERO)
                var world_position := _axial_to_world(axial)
                world_position.y = _land_grass_top + RIVER_Y_OFFSET
                var rotation_steps := int(entry.get("rotation", 0)) % 6
                var rotation_basis := Basis(Vector3.UP, float(rotation_steps) * RIVER_ROTATION_STEP)
                var basis := rotation_basis.scaled(_scale_vector_for_class(class_value))
                var transform := Transform3D(basis, world_position)
                multimesh.set_instance_transform(index, transform)
            used_keys["%d:%s" % [class_value, variant]] = true
    _cleanup_unused_river_layers(used_keys)
    _update_river_markers(mouth_entries)

func _cleanup_unused_river_layers(used_keys: Dictionary) -> void:
    var classes_to_remove: Array[int] = []
    for class_value in _river_layers.keys():
        var variant_map: Dictionary = _river_layers[class_value]
        var variants_to_remove: Array[String] = []
        for variant in variant_map.keys():
            var key := "%d:%s" % [class_value, variant]
            if used_keys.has(key):
                continue
            var instance: Variant = variant_map[variant]
            if instance is MultiMeshInstance3D:
                var node := instance as MultiMeshInstance3D
                if not node.is_queued_for_deletion():
                    node.queue_free()
            variants_to_remove.append(variant)
        for variant in variants_to_remove:
            variant_map.erase(variant)
        if variant_map.is_empty():
            classes_to_remove.append(class_value)
        else:
            _river_layers[class_value] = variant_map
    for class_value in classes_to_remove:
        _river_layers.erase(class_value)

func _update_river_markers(entries: Array) -> void:
    if entries.is_empty():
        if _river_marker_layer != null and _river_marker_layer.multimesh != null:
            _river_marker_layer.multimesh.instance_count = 0
        return
    var instance := _ensure_river_marker_layer()
    if instance == null:
        return
    var multimesh := instance.multimesh
    if multimesh == null:
        return
    instance.visible = _show_rivers
    multimesh.instance_count = entries.size()
    for index in range(entries.size()):
        var entry: Dictionary = entries[index]
        var axial: Vector2i = entry.get("coord", Vector2i.ZERO)
        var world_position := _axial_to_world(axial)
        world_position.y = _land_grass_top + RIVER_Y_OFFSET + (RIVER_MARKER_HEIGHT * 0.5)
        var transform := Transform3D(Basis.IDENTITY, world_position)
        multimesh.set_instance_transform(index, transform)

func _update_river_visibility() -> void:
    for class_value in _river_layers.keys():
        var variant_map: Dictionary = _river_layers[class_value]
        for variant in variant_map.keys():
            var instance: Variant = variant_map[variant]
            if instance is MultiMeshInstance3D:
                (instance as MultiMeshInstance3D).visible = _show_rivers
    if _river_marker_layer != null:
        _river_marker_layer.visible = _show_rivers

func _coord_to_axial(value: Variant) -> Vector2i:
    if value is Vector2i:
        return value
    if value is Vector2:
        var vec2 := value as Vector2
        return Vector2i(int(round(vec2.x)), int(round(vec2.y)))
    if value is Array and value.size() >= 2:
        return Vector2i(int(value[0]), int(value[1]))
    if value is PackedInt32Array and value.size() >= 2:
        return Vector2i(value[0], value[1])
    return Vector2i.ZERO

func _axial_to_world(coord: Vector2i) -> Vector3:
    var q := float(coord.x)
    var r := float(coord.y)
    var x := HEX_WORLD_SCALE * ((sqrt(3.0) * q) + (sqrt(3.0) * 0.5 * r))
    var z := HEX_WORLD_SCALE * (1.5 * r)
    return Vector3(x, 0.0, z)

func _draw() -> void:
    _refresh_layers_if_needed()

func _complete_preview_setup() -> void:
    _ensure_camera_rig()
    _ensure_preview_light()
    _update_camera_framing()

func _ensure_camera_rig() -> void:
    if _viewport == null:
        return
    _camera_rig = _viewport.get_node_or_null("%CameraRig") as Node3D
    if _camera_rig == null:
        _camera_rig = Node3D.new()
        _camera_rig.name = "CameraRig"
        _camera_rig.unique_name_in_owner = true
        _viewport.add_child(_camera_rig)
    _camera = _camera_rig.get_node_or_null("PreviewCamera") as Camera3D
    if _camera == null:
        _camera = Camera3D.new()
        _camera.name = "PreviewCamera"
        _camera_rig.add_child(_camera)
    _configure_camera()

func _configure_camera() -> void:
    if _camera == null:
        return
    _camera.set_deferred("current", true)
    _camera.near = 0.1
    _camera.far = 1024.0
    _camera.fov = 40.0
    if _map_bounds.is_empty():
        _apply_default_camera_frame()

func _apply_default_camera_frame() -> void:
    if _camera == null:
        return
    var origin := DEFAULT_CAMERA_ORIGIN
    var target := DEFAULT_CAMERA_TARGET
    var direction := target - origin
    if direction.length_squared() < 0.001:
        direction = Vector3.FORWARD
    var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
    _camera.transform = Transform3D(basis, origin)

func _update_camera_framing() -> void:
    if _camera == null:
        return
    if _map_bounds.is_empty():
        _apply_default_camera_frame()
        return
    var min_pos: Vector3 = _map_bounds.get("min", Vector3.ZERO)
    var max_pos: Vector3 = _map_bounds.get("max", Vector3.ZERO)
    var base_center: Vector3 = (min_pos + max_pos) * 0.5
    var span_x: float = abs(max_pos.x - min_pos.x)
    var span_z: float = abs(max_pos.z - min_pos.z)
    var extent: float = max(max(span_x, span_z) * 0.5, 1.0)
    var zoom_factor: float = clampf(_camera_zoom, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    var distance: float = max(CAMERA_MIN_DISTANCE, extent * CAMERA_DISTANCE_FACTOR) * zoom_factor
    var height: float = max(CAMERA_BASE_HEIGHT, (extent * CAMERA_HEIGHT_PER_UNIT) + CAMERA_BASE_HEIGHT) * zoom_factor
    height = max(height, 4.0)
    var center_2d: Vector2 = Vector2(base_center.x, base_center.z) + _camera_pan_offset
    if _camera_pan_bounds_max.x > _camera_pan_bounds_min.x:
        center_2d.x = clampf(center_2d.x, _camera_pan_bounds_min.x, _camera_pan_bounds_max.x)
    if _camera_pan_bounds_max.y > _camera_pan_bounds_min.y:
        center_2d.y = clampf(center_2d.y, _camera_pan_bounds_min.y, _camera_pan_bounds_max.y)
    _camera_pan_offset = center_2d - Vector2(base_center.x, base_center.z)
    var center: Vector3 = Vector3(center_2d.x, base_center.y, center_2d.y)
    var offset_dir: Vector3 = CAMERA_ORBIT_DIRECTION.normalized().rotated(Vector3.UP, _camera_orbit_yaw)
    var horizontal_offset: Vector3 = offset_dir * distance
    var origin: Vector3 = Vector3(center.x + horizontal_offset.x, height, center.z + horizontal_offset.z)
    var target: Vector3 = Vector3(center.x, center.y, center.z)
    var direction: Vector3 = target - origin
    if direction.length_squared() < 0.001:
        direction = Vector3.FORWARD
    var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
    _camera.transform = Transform3D(basis, origin)
    if _sun_light != null:
        _sun_light.transform.origin = center

func _ensure_preview_light() -> void:
    if _viewport == null:
        return
    _sun_light = _viewport.get_node_or_null("%SunLight") as DirectionalLight3D
    if _sun_light == null:
        _sun_light = DirectionalLight3D.new()
        _sun_light.name = "SunLight"
        _sun_light.unique_name_in_owner = true
        _viewport.add_child(_sun_light)
    _configure_preview_light()

func _configure_preview_light() -> void:
    if _sun_light == null:
        return
    _sun_light.light_energy = LIGHT_ENERGY
    _sun_light.light_indirect_energy = LIGHT_INDIRECT_ENERGY
    _sun_light.shadow_enabled = false
    var direction := LIGHT_DIRECTION
    if direction.length_squared() < 0.001:
        direction = Vector3(-0.5, -1.0, -0.5)
    direction = direction.normalized()
    var basis := Basis.looking_at(direction, Vector3.UP)
    _sun_light.transform = Transform3D(basis, _sun_light.transform.origin)

func _configure_input_capture() -> void:
    if self is Control:
        var control := self as Control
        control.mouse_filter = Control.MOUSE_FILTER_STOP
        control.focus_mode = Control.FOCUS_ALL
    if _viewport_container != null:
        _viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
        _viewport_container.focus_mode = Control.FOCUS_ALL
        if not _viewport_container.gui_input.is_connected(_on_viewport_container_gui_input):
            _viewport_container.gui_input.connect(_on_viewport_container_gui_input)
    if _input_capture != null:
        _input_capture.mouse_filter = Control.MOUSE_FILTER_STOP
        _input_capture.focus_mode = Control.FOCUS_ALL
        _input_capture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        if not _input_capture.gui_input.is_connected(_on_input_capture_gui_input):
            _input_capture.gui_input.connect(_on_input_capture_gui_input)
    if _viewport != null:
        _viewport.gui_disable_input = true
        _viewport.handle_input_locally = false
        if _viewport.has_signal("gui_input") and not _viewport.gui_input.is_connected(_on_subviewport_gui_input):
            _viewport.gui_input.connect(_on_subviewport_gui_input)

func _gui_input(event: InputEvent) -> void:
    if _handle_pointer_event(event):
        accept_event()

func _on_input_capture_gui_input(event: InputEvent) -> void:
    if _handle_pointer_event(event) and _input_capture != null:
        _input_capture.accept_event()

func _on_viewport_container_gui_input(event: InputEvent) -> void:
    if _handle_pointer_event(event) and _viewport_container != null:
        _viewport_container.accept_event()

func _on_subviewport_gui_input(event: InputEvent) -> void:
    if _handle_pointer_event(event):
        var root_viewport := get_viewport()
        if root_viewport != null:
            root_viewport.set_input_as_handled()

func _handle_pointer_event(event: InputEvent) -> bool:
    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            _change_camera_zoom(CAMERA_ZOOM_IN_FACTOR)
            return true
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            _change_camera_zoom(CAMERA_ZOOM_OUT_FACTOR)
            return true
        if mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
            _is_panning = mouse_button.pressed
            return true
        if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
            _is_rotating = mouse_button.pressed
            return true
        return false
    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        var handled: bool = false
        if _is_rotating or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            if not _is_rotating and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
                _is_rotating = true
            if absf(motion.relative.x) > 0.0:
                _apply_camera_rotation(motion.relative.x)
            handled = true
        if not handled:
            var wants_pan: bool = _is_panning or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
            if wants_pan and not motion.relative.is_zero_approx():
                if not _is_panning:
                    _is_panning = true
                _apply_camera_pan(motion.relative)
            if wants_pan:
                handled = true
        return handled
    return false

func _change_camera_zoom(factor: float) -> void:
    var new_zoom: float = clampf(_camera_zoom * factor, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    if absf(new_zoom - _camera_zoom) < 0.0001:
        return
    _camera_zoom = new_zoom
    _update_camera_framing()

func _apply_camera_rotation(delta_x: float) -> void:
    _camera_orbit_yaw = wrapf(_camera_orbit_yaw - (delta_x * CAMERA_ROTATE_SPEED), -TAU, TAU)
    _update_camera_framing()

func _apply_camera_pan(relative: Vector2) -> void:
    if _camera == null:
        return
    if relative.is_zero_approx():
        return
    var right: Vector3 = _camera.transform.basis.x
    var forward: Vector3 = -_camera.transform.basis.z
    right.y = 0.0
    forward.y = 0.0
    if right.length_squared() < 0.001 or forward.length_squared() < 0.001:
        return
    right = right.normalized()
    forward = forward.normalized()
    var pan_scale: float = _compute_pan_scale()
    var movement: Vector3 = (-right * relative.x + forward * relative.y) * pan_scale
    _camera_pan_offset += Vector2(movement.x, movement.z)
    _update_camera_framing()

func _compute_pan_scale() -> float:
    var extent: float = max(_map_extent_radius, 1.0)
    var viewport_size: Vector2 = Vector2(1.0, 1.0)
    if _viewport != null:
        viewport_size = _viewport.size
        viewport_size.x = max(viewport_size.x, 1.0)
        viewport_size.y = max(viewport_size.y, 1.0)
    var reference: float = 600.0
    var pan_scale: float = extent * CAMERA_PAN_BASE * _camera_zoom
    pan_scale *= reference / viewport_size.y
    return pan_scale

func _update_pan_bounds(min_pos: Vector3, max_pos: Vector3) -> void:
    var margin: float = max(_map_extent_radius * CAMERA_PAN_MARGIN_RATIO, CAMERA_PAN_MARGIN_MIN)
    _camera_pan_bounds_min = Vector2(min_pos.x - margin, min_pos.z - margin)
    _camera_pan_bounds_max = Vector2(max_pos.x + margin, max_pos.z + margin)

func _reset_camera_state() -> void:
    _camera_zoom = 1.0
    _camera_orbit_yaw = 0.0
    _camera_pan_offset = Vector2.ZERO
    _is_panning = false
    _is_rotating = false
