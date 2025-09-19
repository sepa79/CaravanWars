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

var map_data: Dictionary = {}

var _mesh_library: Dictionary = {}
var _region_layers: Dictionary = {}
var _needs_refresh: bool = false

var _viewport: SubViewport
var _terrain_root: Node3D
var _viewport_container: Control

func _ready() -> void:
    _ensure_viewport_structure()
    _configure_viewport()
    _build_mesh_library()
    _ensure_region_layers()
    _needs_refresh = true
    _refresh_layers_if_needed()

func _exit_tree() -> void:
    if _viewport != null:
        _viewport.world_3d = null

func set_map_data(data: Dictionary) -> void:
    map_data = data
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
        multimesh.instance_count = index

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
