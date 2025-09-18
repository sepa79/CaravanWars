extends SubViewportContainer
class_name MapView

# Scene: MapView(SubViewportContainer) -> Viewport(SubViewport with World3D) -> WorldRoot/Terrain
signal cities_changed(cities: Array)

const HexCoord := preload("res://mapgen/HexCoord.gd")
const HexGrid := preload("res://mapgen/HexGrid.gd")

const HEX_TILE_SIZE: float = 1.0
const DEFAULT_REGION_KEY := StringName("plains")
const REGION_LIBRARY_KEY := StringName("regions")
const SHORELINE_LIBRARY_KEY := StringName("shoreline")
const REGION_LAYER_PREFIX := "Region_"

const PROJECT_ASSET_PREFIX := "res://assets/"
const SHARED_ASSET_PREFIX := "res://../assets/"

const REGION_SCENE_PATHS: Dictionary = {
    "plains": "res://assets/gltf/tiles/base/hex_grass.gltf",
    "valley": "res://assets/gltf/tiles/base/hex_grass_bottom.gltf",
    "hills": "res://assets/gltf/tiles/base/hex_grass_sloped_low.gltf",
    "mountains": "res://assets/gltf/tiles/base/hex_grass_sloped_high.gltf",
    "lake": "res://assets/gltf/tiles/base/hex_water.gltf",
    "sea": "res://assets/gltf/tiles/base/hex_water.gltf",
}

const SHORELINE_SCENE_PATHS: Dictionary = {
    "A": "res://assets/gltf/tiles/coast/hex_coast_A.gltf",
    "B": "res://assets/gltf/tiles/coast/hex_coast_B.gltf",
    "C": "res://assets/gltf/tiles/coast/hex_coast_C.gltf",
    "D": "res://assets/gltf/tiles/coast/hex_coast_D.gltf",
    "E": "res://assets/gltf/tiles/coast/hex_coast_E.gltf",
    "A_waterless": "res://assets/gltf/tiles/coast/waterless/hex_coast_A_waterless.gltf",
    "B_waterless": "res://assets/gltf/tiles/coast/waterless/hex_coast_B_waterless.gltf",
    "C_waterless": "res://assets/gltf/tiles/coast/waterless/hex_coast_C_waterless.gltf",
    "D_waterless": "res://assets/gltf/tiles/coast/waterless/hex_coast_D_waterless.gltf",
    "E_waterless": "res://assets/gltf/tiles/coast/waterless/hex_coast_E_waterless.gltf",
}

@onready var viewport: SubViewport = $Viewport
@onready var world_root: Node3D = $Viewport/WorldRoot
@onready var terrain_root: Node3D = $Viewport/WorldRoot/Terrain

var map_data: Dictionary = {}
var mesh_library: Dictionary = {}
var _region_meshes: Dictionary[StringName, Mesh] = {}
var _shoreline_meshes: Dictionary[StringName, Mesh] = {}
var terrain_layers: Dictionary[StringName, MultiMeshInstance3D] = {}
var _is_ready: bool = false
var _missing_resource_paths: PackedStringArray = []

func _ready() -> void:
    if viewport.world_3d == null:
        viewport.world_3d = World3D.new()
    _build_mesh_library()
    _is_ready = true
    _rebuild_map()

func set_map_data(payload: Variant) -> void:
    map_data = _unwrap_map_payload(payload)
    if _is_ready:
        _rebuild_map()

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

func _draw() -> void:
    pass

func _unwrap_map_payload(payload: Variant) -> Dictionary:
    if payload is Dictionary:
        return payload
    if payload is Object and payload.has_method("to_dictionary"):
        var converted: Variant = payload.call("to_dictionary")
        if converted is Dictionary:
            return converted
    return {}

func _build_mesh_library() -> void:
    mesh_library.clear()
    _region_meshes = _load_mesh_set(REGION_SCENE_PATHS)
    _shoreline_meshes = _load_mesh_set(SHORELINE_SCENE_PATHS)
    mesh_library[REGION_LIBRARY_KEY] = _region_meshes
    mesh_library[SHORELINE_LIBRARY_KEY] = _shoreline_meshes

func _load_mesh_set(source: Dictionary) -> Dictionary[StringName, Mesh]:
    var result: Dictionary[StringName, Mesh] = {}
    for key in source.keys():
        var path := String(source[key])
        if path.is_empty():
            continue
        var mesh: Mesh = _load_mesh_from_path(path)
        if mesh == null:
            _warn_missing_resource(path)
            continue
        var library_key := StringName(String(key))
        result[library_key] = mesh
    return result

func _load_mesh_from_path(path: String) -> Mesh:
    if ResourceLoader.exists(path):
        var scene := load(path)
        if scene is PackedScene:
            return _extract_mesh(scene)
        return null
    var fallback_path := _resolve_external_asset_path(path)
    if fallback_path.is_empty():
        return null
    return _load_mesh_from_external_gltf(fallback_path)

func _extract_mesh(scene: PackedScene) -> Mesh:
    if scene == null:
        return null
    var instance: Node = scene.instantiate()
    var mesh := _extract_mesh_from_root(instance)
    instance.free()
    return mesh

func _extract_mesh_from_root(root: Node) -> Mesh:
    if root == null:
        return null
    var mesh_instance := _find_mesh_instance(root)
    if mesh_instance == null:
        return null
    return mesh_instance.mesh

func _find_mesh_instance(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node
    for child in node.get_children():
        var mesh_instance := _find_mesh_instance(child)
        if mesh_instance != null:
            return mesh_instance
    return null

func _resolve_external_asset_path(path: String) -> String:
    if not path.begins_with(PROJECT_ASSET_PREFIX):
        return ""
    return path.replace(PROJECT_ASSET_PREFIX, SHARED_ASSET_PREFIX)

func _load_mesh_from_external_gltf(path: String) -> Mesh:
    var absolute_path := ProjectSettings.globalize_path(path)
    if absolute_path.is_empty():
        return null
    if not FileAccess.file_exists(absolute_path):
        return null
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var error_code := document.append_from_file(absolute_path, state)
    if error_code != OK:
        push_warning("[MapView] Failed to append GLTF from %s (error %d)" % [path, error_code])
        return null
    var scene_root := document.generate_scene(state)
    var mesh := _extract_mesh_from_root(scene_root)
    if scene_root != null:
        scene_root.free()
    return mesh

func _rebuild_map() -> void:
    if not _is_ready or terrain_root == null:
        return
    var hex_entries := _collect_hex_entries()
    if hex_entries.is_empty():
        _clear_unused_region_layers([])
        cities_changed.emit([])
        return
    var radius := _extract_radius(hex_entries)
    var grid := HexGrid.new(radius)
    var region_transforms: Dictionary = {}
    for entry in hex_entries:
        var region_key := _resolve_region_key(entry)
        var transform := _build_hex_transform(grid, entry)
        var transforms: Array[Transform3D]
        if region_transforms.has(region_key):
            transforms = region_transforms[region_key]
        else:
            transforms = [] as Array[Transform3D]
            region_transforms[region_key] = transforms
        transforms.append(transform)
    _apply_region_transforms(region_transforms)
    _clear_unused_region_layers(region_transforms.keys())
    cities_changed.emit([])

func _collect_hex_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var raw_hexes: Variant = map_data.get("hexes", [])
    if raw_hexes is Array:
        for entry in raw_hexes:
            if entry is Dictionary:
                result.append(entry)
    elif raw_hexes is Dictionary:
        for entry in raw_hexes.values():
            if entry is Dictionary:
                result.append(entry)
    return result

func _extract_radius(hex_entries: Array[Dictionary]) -> int:
    var meta: Variant = map_data.get("meta")
    if meta is Dictionary and meta.has("map_radius"):
        var radius_value: Variant = meta["map_radius"]
        if typeof(radius_value) == TYPE_INT:
            return max(1, int(radius_value))
    var computed_radius := 1
    for entry in hex_entries:
        var axial := _read_axial(entry)
        var q := axial.x
        var r := axial.y
        var s := -q - r
        computed_radius = max(computed_radius, abs(q))
        computed_radius = max(computed_radius, abs(r))
        computed_radius = max(computed_radius, abs(s))
    return max(1, computed_radius)

func _resolve_region_key(entry: Dictionary) -> StringName:
    var region_value: String = String(entry.get("region", DEFAULT_REGION_KEY))
    var key := StringName(region_value.to_lower())
    if _region_meshes.has(key):
        return key
    return DEFAULT_REGION_KEY

func _build_hex_transform(grid: HexGrid, entry: Dictionary) -> Transform3D:
    var axial := _read_axial(entry)
    var coord := HexCoord.from_vector2i(axial)
    var position_2d := grid.axial_to_world(coord, HEX_TILE_SIZE)
    var elevation_value: Variant = entry.get("elev", 0.0)
    var elevation := 0.0
    if typeof(elevation_value) == TYPE_FLOAT or typeof(elevation_value) == TYPE_INT:
        elevation = float(elevation_value)
    var position := Vector3(position_2d.x, elevation, position_2d.y)
    return Transform3D(Basis(), position)

func _read_axial(entry: Dictionary) -> Vector2i:
    var raw_coord: Variant = entry.get("coord")
    if raw_coord is Vector2i:
        return raw_coord
    if raw_coord is Vector2:
        return Vector2i(int(raw_coord.x), int(raw_coord.y))
    if raw_coord is Dictionary:
        if raw_coord.has("x") and raw_coord.has("y"):
            return Vector2i(int(raw_coord["x"]), int(raw_coord["y"]))
        if raw_coord.has("q") and raw_coord.has("r"):
            return Vector2i(int(raw_coord["q"]), int(raw_coord["r"]))
    if raw_coord is Array and raw_coord.size() >= 2:
        return Vector2i(int(raw_coord[0]), int(raw_coord[1]))
    if entry.has("q") and entry.has("r"):
        return Vector2i(int(entry["q"]), int(entry["r"]))
    return Vector2i.ZERO

func _apply_region_transforms(region_transforms: Dictionary) -> void:
    for region_key in region_transforms.keys():
        var transforms: Array[Transform3D] = region_transforms[region_key]
        _update_region_layer(region_key, transforms)

func _update_region_layer(region_key: StringName, transforms: Array[Transform3D]) -> void:
    var mesh := _region_meshes.get(region_key) as Mesh
    if mesh == null:
        mesh = _region_meshes.get(DEFAULT_REGION_KEY)
        if mesh == null:
            return
    var layer := _ensure_region_layer(region_key, mesh)
    var multimesh: MultiMesh = layer.multimesh
    if multimesh == null:
        multimesh = MultiMesh.new()
        multimesh.mesh = mesh
        layer.multimesh = multimesh
    else:
        multimesh.mesh = mesh
    var count := transforms.size()
    multimesh.instance_count = count
    for index in range(count):
        multimesh.set_instance_transform(index, transforms[index])
    layer.visible = count > 0

func _ensure_region_layer(region_key: StringName, mesh: Mesh) -> MultiMeshInstance3D:
    if terrain_layers.has(region_key):
        return terrain_layers[region_key]
    var instance := MultiMeshInstance3D.new()
    instance.name = "%s%s" % [REGION_LAYER_PREFIX, String(region_key)]
    var multimesh := MultiMesh.new()
    multimesh.mesh = mesh
    instance.multimesh = multimesh
    if terrain_root != null:
        terrain_root.add_child(instance)
    terrain_layers[region_key] = instance
    return instance

func _clear_unused_region_layers(active_keys: Array) -> void:
    for region_key in terrain_layers.keys():
        if active_keys.has(region_key):
            continue
        var layer := terrain_layers[region_key]
        var multimesh := layer.multimesh
        if multimesh != null:
            multimesh.instance_count = 0
        layer.visible = false

func _warn_missing_resource(path: String) -> void:
    if _missing_resource_paths.has(path):
        return
    _missing_resource_paths.append(path)
    push_warning("[MapView] Missing terrain resource %s" % path)
