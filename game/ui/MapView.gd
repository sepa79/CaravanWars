extends Control
class_name MapView

# Scene layout: ViewportContainer (MapView) -> SubViewport (own World3D) -> TerrainRoot (Node3D)

signal cities_changed(cities: Array)

const LAND_BASE_SCENE := preload("res://assets/gltf/tiles/base/hex_grass_bottom.gltf")
const HEX_TILE_STACK: GDScript = preload("res://ui/map_view/HexTileStack.gd")

class TileEntry:
    var node: HexTileStack
    var region: String
    var layer_regions: Dictionary

    func _init(node_value: HexTileStack = null, region_value: String = "", layer_regions: Dictionary = {}) -> void:
        self.node = node_value
        self.region = region_value
        self.layer_regions = layer_regions.duplicate() if not layer_regions.is_empty() else {}

class HexEntry:
    var coord: Vector2i
    var region: String
    var elevation: float
    var world_height: float
    var river_mask: int
    var river_class: int
    var is_river_mouth: bool

    func _init(coord: Vector2i = Vector2i.ZERO, region: String = "", elevation: float = LAND_DEFAULT_ELEVATION, world_height: float = 0.0, river_mask: int = 0, river_class: int = 1, is_river_mouth: bool = false) -> void:
        self.coord = coord
        self.region = region
        self.elevation = elevation
        self.world_height = world_height
        self.river_mask = river_mask
        self.river_class = river_class
        self.is_river_mouth = is_river_mouth

class TileStackInfo:
    var layers: Array[HexTileStack.TileLayer]
    var layer_regions: Dictionary

    func _init() -> void:
        layers = []
        layer_regions = {}

class RiverTileInfo:
    var coord: Vector2i
    var mask: int
    var variant: String
    var rotation: int
    var river_class: int
    var is_mouth: bool

    func _init(coord: Vector2i = Vector2i.ZERO, mask: int = 0, variant: String = "", rotation: int = 0, river_class: int = 1, is_mouth: bool = false) -> void:
        self.coord = coord
        self.mask = mask
        self.variant = variant
        self.rotation = rotation
        self.river_class = river_class
        self.is_mouth = is_mouth

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
var _tiles: Dictionary[Vector2i, TileEntry] = {}
var _water_layers: Dictionary = {}
var _river_layers: Dictionary = {}
var _river_marker_layer: MultiMeshInstance3D
var _river_tile_cache: Dictionary[Vector2i, RiverTileInfo] = {}
var _hex_entries: Array[HexEntry] = []
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
var _land_tile_root: Node3D
var _viewport_container: Control
var _input_capture: Control
var _camera_rig: Node3D
var _camera: Camera3D
var _sun_light: DirectionalLight3D

func _ready() -> void:
    _ensure_viewport_structure()
    _configure_viewport()
    _build_mesh_library()
    _ensure_land_tile_root()
    _ensure_water_layers()
    call_deferred("_complete_preview_setup")
    _update_camera_framing()
    _needs_refresh = true
    _refresh_layers_if_needed()

func _exit_tree() -> void:
    if _viewport != null:
        _viewport.world_3d = null

func set_map_data(data: Dictionary) -> void:
    map_data = data
    _hex_entries = _sanitize_hex_entries(data.get("hexes"))
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
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color(0.2, 0.6, 1.0, 0.85)
    marker_material.metallic = 0.0
    marker_material.roughness = 0.35
    marker.material = marker_material
    return marker

func _ensure_land_tile_root() -> void:
    if _terrain_root == null:
        return
    _land_tile_root = _terrain_root.get_node_or_null("%LandTiles") as Node3D
    if _land_tile_root == null:
        _land_tile_root = Node3D.new()
        _land_tile_root.name = "LandTiles"
        _land_tile_root.unique_name_in_owner = true
        _terrain_root.add_child(_land_tile_root)

func _ensure_water_layers() -> void:
    if _terrain_root == null:
        return
    var water_meshes: Dictionary = _mesh_library.get("water", {})
    var retained_regions: Array = []
    for region in water_meshes.keys():
        var mesh_variant: Variant = water_meshes[region]
        if not (mesh_variant is Mesh):
            continue
        var mesh := mesh_variant as Mesh
        var instance: MultiMeshInstance3D = null
        if _water_layers.has(region):
            var existing_variant: Variant = _water_layers[region]
            if existing_variant is MultiMeshInstance3D:
                instance = existing_variant as MultiMeshInstance3D
        if instance == null:
            instance = MultiMeshInstance3D.new()
            instance.name = "%sRegionLayer" % region.capitalize()
            instance.unique_name_in_owner = true
            _terrain_root.add_child(instance)
            _water_layers[region] = instance
        if instance.multimesh == null:
            instance.multimesh = MultiMesh.new()
            instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        elif instance.multimesh.transform_format != MultiMesh.TRANSFORM_3D and instance.multimesh.instance_count == 0:
            instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        instance.multimesh.mesh = mesh
        instance.visible = true
        retained_regions.append(region)
    var to_remove: Array = []
    for region in _water_layers.keys():
        if retained_regions.has(region):
            continue
        var instance_variant: Variant = _water_layers[region]
        if instance_variant is MultiMeshInstance3D:
            var node := instance_variant as MultiMeshInstance3D
            if is_instance_valid(node):
                node.queue_free()
        to_remove.append(region)
    for region in to_remove:
        _water_layers.erase(region)

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
    for tile_entry in _tiles.values():
        if tile_entry == null:
            continue
        if tile_entry.node == null or not is_instance_valid(tile_entry.node):
            continue
        if tile_entry.layer_regions.is_empty() or not tile_entry.layer_regions.has(region):
            continue
        var layer_ids: Array = tile_entry.layer_regions[region]
        for layer_id_variant in layer_ids:
            var layer_id := String(layer_id_variant)
            if layer_id.is_empty():
                continue
            tile_entry.node.set_layer_transparency(layer_id, transparency)

func _apply_all_region_transparency() -> void:
    for region in _region_transparency.keys():
        _apply_region_transparency(String(region))
    _apply_land_base_transparency()
    _apply_water_transparency()

func _apply_land_base_transparency() -> void:
    for tile_entry in _tiles.values():
        if tile_entry == null:
            continue
        if tile_entry.node == null or not is_instance_valid(tile_entry.node):
            continue
        var region_transparency := _get_region_transparency(tile_entry.region)
        var combined: float = max(region_transparency, _land_base_transparency)
        tile_entry.node.set_base_transparency(combined)

func _apply_water_transparency() -> void:
    for region in _water_layers.keys():
        var instance_variant: Variant = _water_layers[region]
        if not (instance_variant is MultiMeshInstance3D):
            continue
        var instance := instance_variant as MultiMeshInstance3D
        instance.transparency = _get_region_transparency(region)

func _refresh_layers_if_needed() -> void:
    if not _needs_refresh:
        return
    if not is_inside_tree():
        return
    _needs_refresh = false
    _update_region_layers()
    _update_river_layers()

func _update_region_layers() -> void:
    _ensure_land_tile_root()
    _ensure_water_layers()
    var grouped_hexes := _group_hexes_by_region()
    var min_pos := Vector3(INF, INF, INF)
    var max_pos := Vector3(-INF, -INF, -INF)
    var has_positions := false
    var land_surfaces: Dictionary = _mesh_library.get("land_surfaces", {})
    var land_base_mesh: Mesh = _mesh_library.get("land_base")
    var grass_stack := _compute_grass_stack(grouped_hexes)
    _land_grass_top = float(grass_stack.get("top", 0.0))
    _land_grass_height = max(float(grass_stack.get("height", LAND_BASE_MIN_HEIGHT)), LAND_BASE_MIN_HEIGHT)
    var mesh_bundle := HexTileStack.MeshBundle.new(land_base_mesh, _land_grass_top, _land_grass_height, land_surfaces)
    var seen_coords: Dictionary[Vector2i, bool] = {}
    var water_transforms: Dictionary = {}
    var water_meshes: Dictionary = _mesh_library.get("water", {})
    for entry in _hex_entries:
        if entry == null:
            continue
        var region := entry.region
        if region.is_empty():
            region = "plains"
        var axial := entry.coord
        var world_center := _axial_to_world(axial)
        if region == "sea" or region == "lake":
            var water_list: Array = water_transforms.get(region, [])
            water_list.append(Transform3D(Basis.IDENTITY, world_center))
            water_transforms[region] = water_list
            continue
        seen_coords[axial] = true
        var tile_entry: TileEntry = _tiles.get(axial, null)
        if tile_entry == null:
            tile_entry = TileEntry.new()
            _tiles[axial] = tile_entry
        var tile_stack: HexTileStack = tile_entry.node
        if tile_stack == null or not is_instance_valid(tile_stack):
            var created: Object = HEX_TILE_STACK.new()
            if not (created is HexTileStack):
                continue
            tile_stack = created
            tile_stack.name = "HexTile_%d_%d" % [axial.x, axial.y]
            tile_stack.transform = Transform3D(Basis.IDENTITY, world_center)
            if _land_tile_root != null:
                _land_tile_root.add_child(tile_stack)
            else:
                _terrain_root.add_child(tile_stack)
        else:
            tile_stack.transform = Transform3D(Basis.IDENTITY, world_center)
        var plain_top := _determine_plain_top(region, entry.world_height, _land_grass_top)
        var valley_top := _determine_valley_top(entry.world_height, _land_grass_top)
        var stack_info := _build_land_stack(entry, plain_top, valley_top)
        tile_stack.configure(entry.world_height, stack_info.layers, mesh_bundle)
        tile_entry.node = tile_stack
        tile_entry.region = region
        var region_layers: Dictionary = {}
        for layer_region in stack_info.layer_regions.keys():
            var layer_ids: Array = stack_info.layer_regions[layer_region]
            var copied_ids: Array = layer_ids.duplicate()
            region_layers[layer_region] = copied_ids
        tile_entry.layer_regions = region_layers
        var combined_base: float = max(_land_base_transparency, _get_region_transparency(region))
        tile_stack.set_base_transparency(combined_base)
        for layer_region in region_layers.keys():
            var layer_ids: Array = region_layers[layer_region]
            var layer_transparency := _get_region_transparency(layer_region)
            for layer_id_variant in layer_ids:
                var layer_id := String(layer_id_variant)
                if layer_id.is_empty():
                    continue
                tile_stack.set_layer_transparency(layer_id, layer_transparency)
        var tile_bounds: Dictionary = tile_stack.get_combined_aabb()
        if tile_bounds.has("has") and bool(tile_bounds.get("has", false)):
            var aabb_variant: Variant = tile_bounds.get("aabb")
            if typeof(aabb_variant) == TYPE_AABB:
                var tile_aabb: AABB = aabb_variant
                var merged := _merge_bounds_with_aabb(min_pos, max_pos, has_positions, tile_aabb)
                min_pos = merged.get("min", min_pos)
                max_pos = merged.get("max", max_pos)
                has_positions = bool(merged.get("has", has_positions))
    var tiles_to_remove: Array[Vector2i] = []
    for key in _tiles.keys():
        if not seen_coords.has(key):
            tiles_to_remove.append(key)
    for key in tiles_to_remove:
        var stale_entry := _tiles[key]
        if stale_entry != null and stale_entry.node != null and is_instance_valid(stale_entry.node):
            stale_entry.node.queue_free()
        _tiles.erase(key)
    for region in _water_layers.keys():
        var instance_variant: Variant = _water_layers[region]
        if not (instance_variant is MultiMeshInstance3D):
            continue
        var instance := instance_variant as MultiMeshInstance3D
        if instance.multimesh == null:
            instance.multimesh = MultiMesh.new()
            instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
            var mesh_variant: Variant = water_meshes.get(region)
            if mesh_variant is Mesh:
                instance.multimesh.mesh = mesh_variant
        var transforms: Array = water_transforms.get(region, [])
        var multimesh := instance.multimesh
        multimesh.instance_count = transforms.size()
        var water_mesh: Mesh = multimesh.mesh
        for index in range(transforms.size()):
            var transform: Transform3D = transforms[index]
            multimesh.set_instance_transform(index, transform)
            if water_mesh != null:
                var water_aabb := water_mesh.get_aabb()
                var transformed_water := _transform_aabb(water_aabb, transform)
                var merged_water := _merge_bounds_with_aabb(min_pos, max_pos, has_positions, transformed_water)
                min_pos = merged_water.get("min", min_pos)
                max_pos = merged_water.get("max", max_pos)
                has_positions = bool(merged_water.get("has", has_positions))
            else:
                var merged_water_point := _merge_bounds_with_point(min_pos, max_pos, has_positions, transform.origin)
                min_pos = merged_water_point.get("min", min_pos)
                max_pos = merged_water_point.get("max", max_pos)
                has_positions = bool(merged_water_point.get("has", has_positions))
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

func _sanitize_hex_entries(source: Variant) -> Array[HexEntry]:
    var sanitized: Array[HexEntry] = []
    if not (source is Array):
        return sanitized
    for entry_variant in source:
        if not (entry_variant is Dictionary):
            continue
        var entry_dict := entry_variant as Dictionary
        var region := String(entry_dict.get("region", ""))
        if region.is_empty():
            region = "plains"
        var axial := _coord_to_axial(entry_dict.get("coord"))
        var elevation := _sanitize_elevation(entry_dict.get("elev", LAND_DEFAULT_ELEVATION))
        var world_height := _elevation_to_world_height(elevation)
        var river_mask := int(entry_dict.get("river_mask", 0))
        var river_class := int(entry_dict.get("river_class", 1))
        if river_class <= 0:
            river_class = 1
        var is_mouth := bool(entry_dict.get("is_mouth", false))
        sanitized.append(HexEntry.new(axial, region, elevation, world_height, river_mask, river_class, is_mouth))
    return sanitized

func _group_hexes_by_region() -> Dictionary:
    var grouped: Dictionary = {}
    for entry in _hex_entries:
        if entry == null:
            continue
        var region := entry.region
        if region.is_empty():
            region = "plains"
        var region_entries: Array = grouped.get(region, [])
        region_entries.append(entry)
        grouped[region] = region_entries
    return grouped

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
    if not grouped_hexes.has(region):
        return fallback
    var entries: Array = grouped_hexes[region]
    if entries.is_empty():
        return fallback
    var first_entry: HexEntry = entries[0]
    return first_entry.world_height

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

func _build_land_stack(entry: HexEntry, plain_top: float, valley_top: float) -> TileStackInfo:
    var info := TileStackInfo.new()
    var region := entry.region
    if not LAND_LAYER_STACK.has(region):
        return info
    var layer_definitions: Array = LAND_LAYER_STACK.get(region, [])
    var axial := entry.coord
    for layer_definition_variant in layer_definitions:
        if not (layer_definition_variant is Dictionary):
            continue
        var layer_definition: Dictionary = layer_definition_variant
        var layer_id := String(layer_definition.get("id", ""))
        if layer_id.is_empty():
            continue
        if _should_skip_layer_entry(entry, layer_id):
            continue
        var mesh_region := String(layer_definition.get("mesh_region", region))
        var variant_key := _select_land_surface_variant(mesh_region, axial)
        if variant_key.is_empty():
            continue
        var top_height := entry.world_height
        var bottom_height := _land_grass_top
        if layer_id == "plain":
            top_height = plain_top
            bottom_height = _land_grass_top
        elif layer_id == "valley":
            top_height = valley_top
            bottom_height = _land_grass_top
        elif layer_id == "hills" or layer_id == "mountains":
            top_height = entry.world_height
            bottom_height = plain_top
        var tile_layer := HexTileStack.TileLayer.new(layer_id, mesh_region, variant_key, top_height, bottom_height)
        info.layers.append(tile_layer)
        if not info.layer_regions.has(mesh_region):
            info.layer_regions[mesh_region] = []
        var layer_list: Array = info.layer_regions.get(mesh_region, [])
        if not layer_list.has(layer_id):
            layer_list.append(layer_id)
        info.layer_regions[mesh_region] = layer_list
    return info

func _should_skip_layer_entry(entry: HexEntry, layer_id: String) -> bool:
    var has_river := entry.river_mask != 0 or entry.is_river_mouth
    if layer_id == "valley" and has_river:
        return true
    if layer_id == "plain" and has_river:
        return true
    return false

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
    var hash_value := int(coord.x) * 92837111
    hash_value ^= int(coord.y) * 689287499
    hash_value ^= hash_value >> 13
    hash_value &= 0x7fffffff
    return hash_value

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
    for entry in _hex_entries:
        if entry == null:
            continue
        var sanitized_mask := entry.river_mask & ((1 << RIVER_MASK_BIT_COUNT) - 1)
        var is_mouth := entry.is_river_mouth
        if sanitized_mask == 0 and not is_mouth:
            continue
        var variant_info := _resolve_river_variant(sanitized_mask, is_mouth)
        var variant := String(variant_info.get("variant", ""))
        if variant.is_empty():
            continue
        var rotation := int(variant_info.get("rotation", 0))
        var river_class: int = max(entry.river_class, 1)
        var cached_entry := RiverTileInfo.new(entry.coord, sanitized_mask, variant, rotation, river_class, is_mouth)
        _river_tile_cache[entry.coord] = cached_entry

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
    var mouth_entries: Array[RiverTileInfo] = []
    for info in _river_tile_cache.values():
        if info == null:
            continue
        var variant: String = info.variant
        if variant.is_empty():
            continue
        var class_value: int = max(info.river_class, 1)
        if not grouped.has(class_value):
            grouped[class_value] = {}
        var variant_map: Dictionary = grouped[class_value]
        var list: Array = variant_map.get(variant, [])
        list.append(info)
        variant_map[variant] = list
        grouped[class_value] = variant_map
        if info.is_mouth:
            mouth_entries.append(info)
    var used_keys: Dictionary = {}
    for class_value in grouped.keys():
        var variant_map: Dictionary = grouped[class_value]
        for variant_key in variant_map.keys():
            var variant := String(variant_key)
            var entries: Array = variant_map[variant_key]
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
                var entry: RiverTileInfo = entries[index]
                var axial := entry.coord
                var world_position := _axial_to_world(axial)
                world_position.y = _land_grass_top + RIVER_Y_OFFSET
                var rotation_steps := entry.rotation % 6
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

func _update_river_markers(entries: Array[RiverTileInfo]) -> void:
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
        var entry: RiverTileInfo = entries[index]
        var axial := entry.coord
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
