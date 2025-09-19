extends Control
class_name MapView

# Scene layout: ViewportContainer (MapView) -> SubViewport (own World3D) -> TerrainRoot (Node3D)

signal cities_changed(cities: Array)

const REGION_SCENES: Dictionary = {
    "plains": preload("res://assets/gltf/tiles/base/hex_grass.gltf"),
    "hills": preload("res://assets/gltf/tiles/base/hex_grass_sloped_low.gltf"),
    "mountains": preload("res://assets/gltf/tiles/base/hex_grass_sloped_high.gltf"),
    "valley": preload("res://assets/gltf/tiles/base/hex_grass_bottom.gltf"),
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
        "regions": {},
        "shorelines": {},
        "rivers": {},
        "river_marker": null,
    }
    for region in REGION_SCENES.keys():
        var scene: PackedScene = REGION_SCENES[region]
        var mesh: Mesh = _extract_mesh(scene)
        if mesh != null:
            _mesh_library["regions"][region] = mesh
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
    var region_meshes: Dictionary = _mesh_library.get("regions", {})
    for region in REGION_SCENES.keys():
        if _region_layers.has(region):
            continue
        var mesh: Mesh = region_meshes.get(region)
        if mesh == null:
            continue
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh
        var instance := MultiMeshInstance3D.new()
        instance.name = "%sRegionLayer" % region.capitalize()
        instance.multimesh = multimesh
        _terrain_root.add_child(instance)
        _region_layers[region] = instance

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
    for region in _region_layers.keys():
        var instance: MultiMeshInstance3D = _region_layers[region]
        if instance == null or instance.multimesh == null:
            continue
        var hex_entries: Array = grouped_hexes.get(region, [])
        var multimesh := instance.multimesh
        multimesh.instance_count = hex_entries.size()
        var index: int = 0
        for entry in hex_entries:
            if typeof(entry) != TYPE_DICTIONARY:
                continue
            var axial := _coord_to_axial(entry.get("coord"))
            var world_position := _axial_to_world(axial)
            multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, world_position))
            index += 1
            min_pos.x = min(min_pos.x, world_position.x)
            min_pos.y = min(min_pos.y, world_position.y)
            min_pos.z = min(min_pos.z, world_position.z)
            max_pos.x = max(max_pos.x, world_position.x)
            max_pos.y = max(max_pos.y, world_position.y)
            max_pos.z = max(max_pos.z, world_position.z)
            has_positions = true
        multimesh.instance_count = index
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
                world_position.y += RIVER_Y_OFFSET
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
        world_position.y += RIVER_Y_OFFSET + (RIVER_MARKER_HEIGHT * 0.5)
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
