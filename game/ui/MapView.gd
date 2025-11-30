extends Control
class_name MapView

signal cities_changed(cities: Array)

const TerrainSettingsResource := preload("res://map/TerrainSettings.gd")
const HexCoordScript: GDScript = preload("res://mapgen/HexCoord.gd")
const HexGridScript: GDScript = preload("res://mapgen/HexGrid.gd")

const RIVER_MASK_BIT_COUNT := 6
const HEX_WORLD_SIZE: float = 2.0 / sqrt(3.0)
const LAYER_HEIGHT_STEP: float = 0.05
const CAMERA_MIN_DISTANCE: float = 6.0
const CAMERA_MIN_ALTITUDE: float = 8.0
const CAMERA_DISTANCE_SCALE: float = 0.9
const CAMERA_ALTITUDE_SCALE: float = 0.6
const CAMERA_MIN_PITCH: float = deg_to_rad(20.0)
const CAMERA_MAX_PITCH: float = deg_to_rad(80.0)
const CAMERA_BASE_YAW: float = deg_to_rad(45.0)
const CAMERA_DISTANCE_MIN_FACTOR: float = 0.2
const CAMERA_DISTANCE_MAX_FACTOR: float = 8.0
const CAMERA_ROTATE_SPEED: float = 0.01
const CAMERA_TILT_SPEED: float = 0.01
const CAMERA_PAN_SPEED: float = 0.015
const CAMERA_ZOOM_STEP: float = 0.12
const SQRT_TWO: float = sqrt(2.0)
const LIGHT_ROTATION := Vector3(-55.0, -45.0, 0.0)
const LIGHT_ENERGY: float = 1.35
const AMBIENT_COLOR := Color(0.65, 0.7, 0.8)
const AMBIENT_ENERGY: float = 0.9
const CORNER_MARKER_SIZE := Vector2(16.0, 16.0)
const CORNER_MARKER_MARGIN: float = 8.0
const CORNER_MARKER_TOP_LEFT_COLOR := Color(0.95, 0.35, 0.35)
const CORNER_MARKER_TOP_RIGHT_COLOR := Color(0.35, 0.85, 0.45)
const CORNER_MARKER_BOTTOM_LEFT_COLOR := Color(0.35, 0.55, 0.95)
const CORNER_MARKER_BOTTOM_RIGHT_COLOR := Color(0.9, 0.8, 0.35)
const MAP_VIEW_DEBUG_TAG := "[MapView]"
const MAP_VIEW_DEBUG_MEASURE: bool = false
const MAP_VIEW_MAX_LAYERS: int = 0

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

var _terrain_settings: Object = TerrainSettingsResource.new()
var _terrain_asset_map: Dictionary = {}
var _river_tiles: Dictionary[Vector2i, RiverTileInfo] = {}
var _show_rivers: bool = true
var _hex_grid: HexGrid = HexGridScript.new(1)
var _terrain_viewport: SubViewport
var _terrain_root: Node3D
var _map_container: Node3D
var _camera: Camera3D
var _directional_light: DirectionalLight3D
var _environment_node: WorldEnvironment
var _scene_cache: Dictionary = {}
var _camera_target: Vector3 = Vector3.ZERO
var _camera_distance: float = 12.0
var _camera_base_distance: float = 12.0
var _camera_min_distance: float = 2.0
var _camera_max_distance: float = 120.0
var _camera_yaw: float = CAMERA_BASE_YAW
var _camera_pitch: float = deg_to_rad(45.0)
var _camera_pan_scale: float = 1.0
var _camera_user_override: bool = false
var _panning_camera: bool = false
var _rotating_camera: bool = false
var _observed_viewport: Viewport
var _pending_viewport_resize: bool = false
var _debug_measure_done: bool = false

func _enter_tree() -> void:
    _ensure_viewport_subscription()

func _exit_tree() -> void:
    _disconnect_observed_viewport()

func _ready() -> void:
    print("%s ready; HEX_WORLD_SIZE=%f" % [MAP_VIEW_DEBUG_TAG, HEX_WORLD_SIZE])
    mouse_filter = Control.MOUSE_FILTER_STOP
    _configure_container_stretch()
    _ensure_viewport_nodes()
    _ensure_corner_markers()
    _ensure_viewport_subscription()
    if not resized.is_connected(_on_control_resized):
        resized.connect(_on_control_resized)
    _queue_viewport_resize()
    _ensure_environment()
    _ensure_camera()
    _ensure_lighting()
    _rebuild_assets()
    _rebuild_map()

func set_map_data(data: Dictionary) -> void:
    map_data = _duplicate_dictionary(data)
    _load_terrain_settings_from_data(map_data)
    _cache_river_entries()
    _rebuild_assets()
    _camera_user_override = false
    _panning_camera = false
    _rotating_camera = false
    _rebuild_map()
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
    _rebuild_map()

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

func _ensure_viewport_nodes() -> void:
    if _terrain_viewport != null and _terrain_root != null and _map_container != null:
        return
    _terrain_viewport = _find_viewport(self)
    if _terrain_viewport == null:
        if not is_class("SubViewportContainer"):
            return
        var created_viewport: SubViewport = SubViewport.new()
        created_viewport.name = "TerrainViewport"
        created_viewport.own_world_3d = true
        created_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        add_child(created_viewport)
        _terrain_viewport = created_viewport
    _queue_viewport_resize()
    if not _terrain_viewport.own_world_3d:
        _terrain_viewport.own_world_3d = true
    _terrain_root = _terrain_viewport.get_node_or_null("TerrainRoot") as Node3D
    if _terrain_root == null:
        _terrain_root = Node3D.new()
        _terrain_root.name = "TerrainRoot"
        _terrain_viewport.add_child(_terrain_root)
    _map_container = _terrain_root.get_node_or_null("MapContainer") as Node3D
    if _map_container == null:
        _map_container = Node3D.new()
        _map_container.name = "MapContainer"
        _terrain_root.add_child(_map_container)

func _ensure_environment() -> void:
    if _terrain_root == null:
        return
    if _environment_node != null and is_instance_valid(_environment_node):
        return
    var environment: Environment = Environment.new()
    environment.ambient_light_color = AMBIENT_COLOR
    environment.ambient_light_energy = AMBIENT_ENERGY
    environment.ambient_light_sky_contribution = 1.0
    var world_environment: WorldEnvironment = WorldEnvironment.new()
    world_environment.name = "WorldEnvironment"
    world_environment.environment = environment
    _terrain_root.add_child(world_environment)
    _environment_node = world_environment

func _ensure_camera() -> void:
    if _terrain_viewport == null:
        return
    if _camera != null and is_instance_valid(_camera):
        return
    for child in _terrain_viewport.get_children():
        if child is Camera3D:
            _camera = child as Camera3D
            if _camera != null and is_instance_valid(_camera):
                _camera.current = true
                return
    _camera = Camera3D.new()
    _camera.name = "DebugCamera"
    var initial_position := Vector3(0.0, CAMERA_MIN_ALTITUDE, CAMERA_MIN_DISTANCE)
    _camera.look_at_from_position(initial_position, Vector3.ZERO, Vector3.UP)
    _camera.near = 0.1
    _camera.far = 500.0
    _camera.current = true
    _terrain_viewport.add_child(_camera)

func _ensure_lighting() -> void:
    if _terrain_root == null:
        return
    for child in _terrain_root.get_children():
        if child is DirectionalLight3D:
            _directional_light = child as DirectionalLight3D
            break
    if _directional_light == null:
        _directional_light = DirectionalLight3D.new()
        _directional_light.name = "SunLight"
        _directional_light.rotation_degrees = LIGHT_ROTATION
        _directional_light.light_energy = LIGHT_ENERGY
        _terrain_root.add_child(_directional_light)

func _load_terrain_settings_from_data(data: Dictionary) -> void:
    var settings_data: Variant = data.get("terrain_settings")
    var new_settings: Object = TerrainSettingsResource.new()
    if typeof(settings_data) == TYPE_DICTIONARY:
        if new_settings is Resource and new_settings.has_method("apply_overrides"):
            new_settings.call("apply_overrides", settings_data)
    _terrain_settings = new_settings

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
        var axial_coord_variant: Variant = _extract_axial(entry.get("coord"))
        if axial_coord_variant == null:
            continue
        var axial_coord: Vector2i = axial_coord_variant as Vector2i
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

func _rebuild_map() -> void:
    _ensure_viewport_nodes()
    if _map_container == null:
        return
    _clear_map_container()
    var hex_list_variant: Variant = map_data.get("hexes", [])
    if typeof(hex_list_variant) != TYPE_ARRAY:
        _update_camera_focus(Vector3.ZERO, 1.0)
        return
    var hex_list: Array = hex_list_variant
    if hex_list.is_empty():
        _update_camera_focus(Vector3.ZERO, 1.0)
        return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for entry_variant in hex_list:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_variant
        var axial: Variant = _extract_axial(entry.get("coord"))
        if axial == null:
            continue
        var axial_coord: Vector2i = axial as Vector2i
        var world_2d: Vector2 = _axial_to_world(axial_coord)
        var world_position := Vector3(world_2d.x, 0.0, world_2d.y)
        var tile_node := Node3D.new()
        tile_node.name = "Tile_%d_%d" % [axial_coord.x, axial_coord.y]
        tile_node.position = world_position
        _map_container.add_child(tile_node)
        var draw_stack_variant: Variant = entry.get("draw_stack", [])
        _populate_tile_layers(tile_node, draw_stack_variant)
        min_x = min(min_x, world_position.x)
        max_x = max(max_x, world_position.x)
        min_z = min(min_z, world_position.z)
        max_z = max(max_z, world_position.z)
    var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
    var extent_x: float = max_x - min_x
    var extent_z: float = max_z - min_z
    var extent: float = max(max(extent_x, extent_z), 1.0)
    _update_camera_focus(center, extent)
    if MAP_VIEW_DEBUG_MEASURE and not _debug_measure_done:
        _debug_measure_done = true
        _debug_measure_first_tile()

func _clear_map_container() -> void:
    if _map_container == null:
        return
    for child in _map_container.get_children():
        child.queue_free()

func _debug_measure_first_tile() -> void:
    if _map_container == null:
        return
    if _map_container.get_child_count() == 0:
        return
    var tile_node := _map_container.get_child(0) as Node3D
    if tile_node == null:
        return
    print("%s Measuring tile '%s'" % [MAP_VIEW_DEBUG_TAG, tile_node.name])
    _debug_log_layer_bounds(tile_node, "Layer0")
    _debug_log_layer_bounds(tile_node, "Layer1")
    _debug_log_layer_bounds(tile_node, "Layer2")

func _debug_log_layer_bounds(tile_node: Node3D, layer_name: String) -> void:
    var layer := tile_node.get_node_or_null(layer_name) as Node3D
    if layer == null:
        print("%s %s: not found" % [MAP_VIEW_DEBUG_TAG, layer_name])
        return
    var bounds: AABB = _collect_layer_aabb(layer)
    print(
        "%s %s AABB origin=%s size=%s" % [
            MAP_VIEW_DEBUG_TAG,
            layer_name,
            str(bounds.position),
            str(bounds.size),
        ]
    )

func _collect_layer_aabb(root: Node3D) -> AABB:
    var has_bounds: bool = false
    var combined := AABB()
    if root is MeshInstance3D:
        var mesh_instance := root as MeshInstance3D
        var mesh_aabb: AABB = mesh_instance.get_aabb()
        combined = mesh_aabb
        has_bounds = true
    for child in root.get_children():
        if child is Node3D:
            var child_node := child as Node3D
            var child_aabb: AABB = _collect_layer_aabb(child_node)
            if child_aabb.size != Vector3.ZERO:
                if not has_bounds:
                    combined = child_aabb
                    has_bounds = true
                else:
                    combined = combined.merge(child_aabb)
    if has_bounds:
        return combined
    return AABB()

func _populate_tile_layers(tile_node: Node3D, draw_stack_variant: Variant) -> void:
    if tile_node == null:
        return
    if typeof(draw_stack_variant) != TYPE_ARRAY:
        return
    var draw_stack: Array = draw_stack_variant
    var layer_offset_index: int = 0
    for layer_variant in draw_stack:
        if MAP_VIEW_MAX_LAYERS > 0 and layer_offset_index >= MAP_VIEW_MAX_LAYERS:
            break
        if typeof(layer_variant) != TYPE_DICTIONARY:
            continue
        var layer_dict: Dictionary = layer_variant
        if not _should_render_layer(layer_dict):
            continue
        var scene_path: String = _resolve_scene_path(layer_dict)
        if scene_path.is_empty():
            continue
        var packed_scene: PackedScene = _load_scene(scene_path)
        if packed_scene == null:
            continue
        var instance: Node = packed_scene.instantiate()
        var layer_node: Node3D = _ensure_node3d(instance)
        layer_node.name = "Layer%d" % layer_offset_index
        var scale_value: float = float(layer_dict.get("scale", 1.0))
        var role: String = String(layer_dict.get("role", ""))
        if role == "BASE":
            layer_node.scale = Vector3(1.0, scale_value, 1.0)
        else:
            layer_node.scale = Vector3(scale_value, scale_value, scale_value)
        var rotation_steps: int = max(int(layer_dict.get("rotation_steps", 0)), 1)
        var rotation_index: int = int(layer_dict.get("rotation", 0))
        var angle_radians: float = TAU * float(rotation_index) / float(rotation_steps)
        layer_node.rotation = Vector3(0.0, angle_radians, 0.0)
        var offset_2d: Vector2 = _to_vector2(layer_dict.get("offset", Vector2.ZERO))
        var height_offset: float = 0.0
        if role != "BASE":
            height_offset = float(layer_offset_index) * LAYER_HEIGHT_STEP
        layer_node.position = Vector3(offset_2d.x, height_offset, offset_2d.y)
        tile_node.add_child(layer_node)
        layer_offset_index += 1

func _should_render_layer(layer_dict: Dictionary) -> bool:
    var role: String = String(layer_dict.get("role", ""))
    if role == "BASE":
        return false
    if not _show_rivers and role == "RIVER":
        return false
    return true

func _update_camera_focus(center: Vector3, extent: float) -> void:
    if _camera == null:
        return
    var horizontal_span: float = max(extent * CAMERA_DISTANCE_SCALE, CAMERA_MIN_DISTANCE)
    var altitude: float = max(extent * CAMERA_ALTITUDE_SCALE, CAMERA_MIN_ALTITUDE)
    var plane_distance: float = horizontal_span * SQRT_TWO
    var new_pitch: float = atan2(altitude, plane_distance)
    var new_distance: float = sqrt(plane_distance * plane_distance + altitude * altitude)
    _camera_target = center
    _camera_base_distance = new_distance
    _camera_min_distance = max(new_distance * CAMERA_DISTANCE_MIN_FACTOR, 1.0)
    _camera_max_distance = max(new_distance * CAMERA_DISTANCE_MAX_FACTOR, _camera_min_distance + 1.0)
    _camera_pan_scale = max(extent, 1.0)
    if not _camera_user_override:
        _camera_yaw = CAMERA_BASE_YAW
        _camera_pitch = clamp(new_pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
        _camera_distance = new_distance
    _apply_camera_transform()

func _apply_camera_transform() -> void:
    if _camera == null:
        return
    var pitch_sin := sin(_camera_pitch)
    var pitch_cos := cos(_camera_pitch)
    var altitude_limit: float = CAMERA_MIN_ALTITUDE / max(pitch_sin, 0.01)
    var horizontal_limit: float = (CAMERA_MIN_DISTANCE * SQRT_TWO) / max(pitch_cos, 0.01)
    var min_distance: float = max(_camera_min_distance, altitude_limit, horizontal_limit)
    var max_distance: float = max(_camera_max_distance, min_distance + 0.01)
    _camera_distance = clamp(_camera_distance, min_distance, max_distance)
    _camera_pitch = clamp(_camera_pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
    _camera_yaw = fposmod(_camera_yaw, TAU)
    var horizontal_distance: float = pitch_cos * _camera_distance
    var offset := Vector3(
        sin(_camera_yaw) * horizontal_distance,
        pitch_sin * _camera_distance,
        cos(_camera_yaw) * horizontal_distance
    )
    _camera.look_at_from_position(_camera_target + offset, _camera_target, Vector3.UP)

func _gui_input(event: InputEvent) -> void:
    if _camera == null:
        return
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        match button.button_index:
            MOUSE_BUTTON_MIDDLE:
                if button.pressed and _is_pointer_over_viewport(button.position):
                    _panning_camera = true
                    _camera_user_override = true
                    accept_event()
                elif not button.pressed:
                    _panning_camera = false
            MOUSE_BUTTON_RIGHT:
                if button.pressed and _is_pointer_over_viewport(button.position):
                    _rotating_camera = true
                    _camera_user_override = true
                    accept_event()
                elif not button.pressed:
                    _rotating_camera = false
            MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
                if button.pressed and _is_pointer_over_viewport(button.position):
                    var direction := -1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
                    _camera_user_override = true
                    _apply_zoom_step(direction)
                    accept_event()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if _panning_camera:
            _camera_user_override = true
            _apply_pan(motion.relative)
            accept_event()
        elif _rotating_camera:
            _camera_user_override = true
            _apply_rotation(motion.relative)
            accept_event()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if button.button_index == MOUSE_BUTTON_MIDDLE and not button.pressed:
            _panning_camera = false
        elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
            _rotating_camera = false

func _is_pointer_over_viewport(pointer_position: Vector2) -> bool:
    var local_rect := Rect2(Vector2.ZERO, size)
    return local_rect.has_point(pointer_position)

func _apply_zoom_step(direction: float) -> void:
    var multiplier: float = 1.0
    if direction < 0.0:
        multiplier = 1.0 - CAMERA_ZOOM_STEP
    else:
        multiplier = 1.0 + CAMERA_ZOOM_STEP
    _camera_distance *= multiplier
    _apply_camera_transform()

func _apply_pan(relative: Vector2) -> void:
    if relative == Vector2.ZERO:
        return
    var right := Vector3(cos(_camera_yaw), 0.0, -sin(_camera_yaw))
    var forward := Vector3(-sin(_camera_yaw), 0.0, -cos(_camera_yaw))
    var pan_scale_factor: float = CAMERA_PAN_SPEED * max(_camera_distance, 1.0) / max(_camera_pan_scale, 1.0)
    var delta := (-right * relative.x + forward * relative.y) * pan_scale_factor
    _camera_target += delta
    _apply_camera_transform()

func _apply_rotation(relative: Vector2) -> void:
    if relative == Vector2.ZERO:
        return
    _camera_yaw -= relative.x * CAMERA_ROTATE_SPEED
    _camera_pitch = clamp(_camera_pitch + relative.y * CAMERA_TILT_SPEED, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
    _apply_camera_transform()

func _load_scene(scene_path: String) -> PackedScene:
    if _scene_cache.has(scene_path):
        var cached: Variant = _scene_cache[scene_path]
        return cached if cached is PackedScene else null
    var resource: Resource = load(scene_path)
    if resource is PackedScene:
        _scene_cache[scene_path] = resource
        return resource
    _scene_cache[scene_path] = null
    push_warning("[MapView] Unable to load scene at %s" % scene_path)
    return null

func _ensure_node3d(node: Node) -> Node3D:
    if node is Node3D:
        return node as Node3D
    var holder := Node3D.new()
    holder.name = node.name
    holder.add_child(node)
    return holder

func _resolve_scene_path(layer_dict: Dictionary) -> String:
    var direct: String = String(layer_dict.get("scene_path", ""))
    if not direct.is_empty():
        return direct
    return String(layer_dict.get("resource", ""))

func _axial_to_world(axial: Vector2i) -> Vector2:
    var coord: HexCoord = HexCoordScript.new(axial.x, axial.y) as HexCoord
    return _hex_grid.axial_to_world(coord, HEX_WORLD_SIZE)

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

func _to_vector2(value: Variant) -> Vector2:
    if value is Vector2:
        return value as Vector2
    if value is Vector2i:
        var vector := value as Vector2i
        return Vector2(vector.x, vector.y)
    if value is Array and value.size() >= 2:
        var array := value as Array
        return Vector2(float(array[0]), float(array[1]))
    return Vector2.ZERO

func _find_viewport(root: Node) -> SubViewport:
    if root == null:
        return null
    if root is SubViewport:
        return root as SubViewport
    for child in root.get_children():
        var candidate := _find_viewport(child)
        if candidate != null:
            return candidate
    return null

func _ensure_corner_markers() -> void:
    var marker_configs: Array[Dictionary] = [
        {
            "name": "CornerTopLeft",
            "preset": Control.PRESET_TOP_LEFT,
            "offset_left": CORNER_MARKER_MARGIN,
            "offset_top": CORNER_MARKER_MARGIN,
            "offset_right": CORNER_MARKER_MARGIN + CORNER_MARKER_SIZE.x,
            "offset_bottom": CORNER_MARKER_MARGIN + CORNER_MARKER_SIZE.y,
            "color": CORNER_MARKER_TOP_LEFT_COLOR,
        },
        {
            "name": "CornerTopRight",
            "preset": Control.PRESET_TOP_RIGHT,
            "offset_left": -CORNER_MARKER_MARGIN - CORNER_MARKER_SIZE.x,
            "offset_top": CORNER_MARKER_MARGIN,
            "offset_right": -CORNER_MARKER_MARGIN,
            "offset_bottom": CORNER_MARKER_MARGIN + CORNER_MARKER_SIZE.y,
            "color": CORNER_MARKER_TOP_RIGHT_COLOR,
        },
        {
            "name": "CornerBottomLeft",
            "preset": Control.PRESET_BOTTOM_LEFT,
            "offset_left": CORNER_MARKER_MARGIN,
            "offset_top": -CORNER_MARKER_MARGIN - CORNER_MARKER_SIZE.y,
            "offset_right": CORNER_MARKER_MARGIN + CORNER_MARKER_SIZE.x,
            "offset_bottom": -CORNER_MARKER_MARGIN,
            "color": CORNER_MARKER_BOTTOM_LEFT_COLOR,
        },
        {
            "name": "CornerBottomRight",
            "preset": Control.PRESET_BOTTOM_RIGHT,
            "offset_left": -CORNER_MARKER_MARGIN - CORNER_MARKER_SIZE.x,
            "offset_top": -CORNER_MARKER_MARGIN - CORNER_MARKER_SIZE.y,
            "offset_right": -CORNER_MARKER_MARGIN,
            "offset_bottom": -CORNER_MARKER_MARGIN,
            "color": CORNER_MARKER_BOTTOM_RIGHT_COLOR,
        },
    ]
    for config in marker_configs:
        var marker_name := String(config.get("name", ""))
        if marker_name.is_empty():
            continue
        var marker := get_node_or_null(NodePath(marker_name)) as ColorRect
        if marker == null:
            marker = ColorRect.new()
            marker.name = marker_name
            add_child(marker)
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        marker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        marker.focus_mode = Control.FOCUS_NONE
        marker.z_index = 100
        marker.color = config.get("color", Color.WHITE)
        marker.set_anchors_preset(int(config.get("preset", Control.PRESET_TOP_LEFT)))
        marker.offset_left = float(config.get("offset_left", 0.0))
        marker.offset_top = float(config.get("offset_top", 0.0))
        marker.offset_right = float(config.get("offset_right", CORNER_MARKER_SIZE.x))
        marker.offset_bottom = float(config.get("offset_bottom", CORNER_MARKER_SIZE.y))
        if marker.get_parent() == self:
            move_child(marker, get_child_count() - 1)

func _configure_container_stretch() -> void:
    if not is_class("SubViewportContainer"):
        return
    var current_stretch := bool(get("stretch"))
    var current_shrink := float(get("stretch_shrink"))
    if current_stretch and is_equal_approx(current_shrink, 1.0):
        return
    set("stretch", true)
    set("stretch_shrink", 1.0)

func _on_control_resized() -> void:
    _queue_viewport_resize()

func _ensure_viewport_subscription() -> void:
    var host_viewport: Viewport = get_viewport()
    if host_viewport == _observed_viewport:
        return
    _disconnect_observed_viewport()
    _observed_viewport = host_viewport
    if _observed_viewport != null and not _observed_viewport.size_changed.is_connected(_on_viewport_size_changed):
        _observed_viewport.size_changed.connect(_on_viewport_size_changed)
    _queue_viewport_resize()

func _disconnect_observed_viewport() -> void:
    if _observed_viewport == null:
        return
    if _observed_viewport.size_changed.is_connected(_on_viewport_size_changed):
        _observed_viewport.size_changed.disconnect(_on_viewport_size_changed)
    _observed_viewport = null

func _on_viewport_size_changed() -> void:
    _queue_viewport_resize()

func _queue_viewport_resize() -> void:
    if _pending_viewport_resize:
        return
    _pending_viewport_resize = true
    call_deferred("_flush_pending_viewport_resize")

func _flush_pending_viewport_resize() -> void:
    _pending_viewport_resize = false
    _update_viewport_size()

func _update_viewport_size() -> void:
    if _terrain_viewport == null:
        return
    var rect_size: Vector2 = size
    var desired_width := int(max(1.0, round(rect_size.x)))
    var desired_height := int(max(1.0, round(rect_size.y)))
    var desired_size := Vector2i(desired_width, desired_height)
    if _terrain_viewport.size == desired_size:
        return
    _terrain_viewport.size = desired_size

func _duplicate_dictionary(source: Variant) -> Dictionary:
    var copy: Dictionary = {}
    if typeof(source) != TYPE_DICTIONARY:
        return copy
    var original: Dictionary = source
    for key in original.keys():
        var value: Variant = original[key]
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
    var original: Array = source
    for value in original:
        match typeof(value):
            TYPE_DICTIONARY:
                copy.append(_duplicate_dictionary(value))
            TYPE_ARRAY:
                copy.append(_duplicate_array(value))
            _:
                copy.append(value)
    return copy
