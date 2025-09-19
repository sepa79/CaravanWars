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

var _viewport: SubViewport
var _terrain_root: Node3D
var _viewport_container: Control
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

func set_show_rivers(_value: bool) -> void:
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

func _configure_viewport() -> void:
    if _viewport == null:
        return
    _viewport.own_world_3d = true
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
        _viewport_container.add_child(_viewport)
    _terrain_root = _viewport.get_node_or_null("TerrainRoot") as Node3D
    if _terrain_root == null:
        _terrain_root = Node3D.new()
        _terrain_root.name = "TerrainRoot"
        _terrain_root.unique_name_in_owner = true
        _viewport.add_child(_terrain_root)
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

func _build_mesh_library() -> void:
    _mesh_library = {
        "regions": {},
        "shorelines": {},
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
            var position := _axial_to_world(axial)
            multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))
            index += 1
            min_pos.x = min(min_pos.x, position.x)
            min_pos.y = min(min_pos.y, position.y)
            min_pos.z = min(min_pos.z, position.z)
            max_pos.x = max(max_pos.x, position.x)
            max_pos.y = max(max_pos.y, position.y)
            max_pos.z = max(max_pos.z, position.z)
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
    var basis := Basis().looking_at(direction.normalized(), Vector3.UP)
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
    var basis := Basis().looking_at(direction.normalized(), Vector3.UP)
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
    var basis := Basis().looking_at(direction, Vector3.UP)
    _sun_light.transform = Transform3D(basis, _sun_light.transform.origin)

func _configure_input_capture() -> void:
    if self is Control:
        var control := self as Control
        control.mouse_filter = Control.MOUSE_FILTER_STOP
        control.focus_mode = Control.FOCUS_ALL
    if _viewport_container != null:
        _viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
        _viewport_container.focus_mode = Control.FOCUS_ALL

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            _change_camera_zoom(CAMERA_ZOOM_IN_FACTOR)
            accept_event()
            return
        if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            _change_camera_zoom(CAMERA_ZOOM_OUT_FACTOR)
            accept_event()
            return
        if mouse_button.button_index == MOUSE_BUTTON_LEFT or mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
            _is_panning = mouse_button.pressed
            if not mouse_button.pressed:
                _is_panning = false
            else:
                accept_event()
            return
        if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
            _is_rotating = mouse_button.pressed
            if not mouse_button.pressed:
                _is_rotating = false
            else:
                accept_event()
            return
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        var handled: bool = false
        if _is_rotating and (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
            _apply_camera_rotation(motion.relative.x)
            handled = true
        elif (_is_panning and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0) or ((motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0):
            _apply_camera_pan(motion.relative)
            _is_panning = true
            handled = true
        if handled:
            accept_event()

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
    var scale: float = _compute_pan_scale()
    var movement: Vector3 = (-right * relative.x + forward * relative.y) * scale
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
    var scale: float = extent * CAMERA_PAN_BASE * _camera_zoom
    scale *= reference / viewport_size.y
    return scale

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
