extends SubViewportContainer
class_name MapView

signal cities_changed(cities: Array)

var map_data: Dictionary = {}

# Scene tree (MapView.tscn):
# SubViewportContainer (MapView)
# └── SubViewport %MapSubViewport
#     └── Node3D %TerrainRoot

const HEX_GRASS_SCENE := preload("res://assets/gltf/tiles/base/hex_grass.gltf")
const HEX_GRASS_BOTTOM_SCENE := preload("res://assets/gltf/tiles/base/hex_grass_bottom.gltf")
const HEX_GRASS_SLOPED_HIGH_SCENE := preload("res://assets/gltf/tiles/base/hex_grass_sloped_high.gltf")
const HEX_GRASS_SLOPED_LOW_SCENE := preload("res://assets/gltf/tiles/base/hex_grass_sloped_low.gltf")
const HEX_WATER_SCENE := preload("res://assets/gltf/tiles/base/hex_water.gltf")

const COAST_SCENE_A := preload("res://assets/gltf/tiles/coast/hex_coast_A.gltf")
const COAST_SCENE_B := preload("res://assets/gltf/tiles/coast/hex_coast_B.gltf")
const COAST_SCENE_C := preload("res://assets/gltf/tiles/coast/hex_coast_C.gltf")
const COAST_SCENE_D := preload("res://assets/gltf/tiles/coast/hex_coast_D.gltf")
const COAST_SCENE_E := preload("res://assets/gltf/tiles/coast/hex_coast_E.gltf")

const REGION_SCENE_MAP: Dictionary = {
    "mountains": HEX_GRASS_SLOPED_HIGH_SCENE,
    "hills": HEX_GRASS_SLOPED_LOW_SCENE,
    "plains": HEX_GRASS_SCENE,
    "valley": HEX_GRASS_BOTTOM_SCENE,
    "lake": HEX_WATER_SCENE,
    "sea": HEX_WATER_SCENE,
}

const SHORELINE_SCENE_MAP: Dictionary = {
    "A": COAST_SCENE_A,
    "B": COAST_SCENE_B,
    "C": COAST_SCENE_C,
    "D": COAST_SCENE_D,
    "E": COAST_SCENE_E,
}

const HEX_SIZE: float = 1.0
const SQRT_3: float = sqrt(3.0)

var mesh_library: Dictionary = {
    "terrain": {},
    "shoreline": {},
}

var region_nodes: Dictionary = {}
var pending_map_refresh: bool = false

@onready var map_viewport: SubViewport = %MapSubViewport
@onready var terrain_root: Node3D = %TerrainRoot

func set_map_data(data: Dictionary) -> void:
    map_data = data
    if is_node_ready():
        _update_terrain()
    else:
        pending_map_refresh = true
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

func _draw() -> void:
    pass

func _ready() -> void:
    _ensure_viewport_world()
    _prepare_mesh_library()
    if pending_map_refresh:
        _update_terrain()
        pending_map_refresh = false

func _ensure_viewport_world() -> void:
    if map_viewport.world_3d == null:
        map_viewport.world_3d = World3D.new()

func _prepare_mesh_library() -> void:
    var terrain_meshes: Dictionary = mesh_library.get("terrain", {})
    if terrain_meshes.is_empty():
        for region_key in REGION_SCENE_MAP.keys():
            var terrain_scene: PackedScene = REGION_SCENE_MAP[region_key]
            var terrain_mesh := _extract_mesh(terrain_scene)
            if terrain_mesh != null:
                terrain_meshes[region_key] = terrain_mesh
            else:
                push_warning("[MapView] Missing mesh for terrain region '%s'" % region_key)
        mesh_library["terrain"] = terrain_meshes

    var shoreline_meshes: Dictionary = mesh_library.get("shoreline", {})
    if shoreline_meshes.is_empty():
        for case_key in SHORELINE_SCENE_MAP.keys():
            var shoreline_scene: PackedScene = SHORELINE_SCENE_MAP[case_key]
            var shoreline_mesh := _extract_mesh(shoreline_scene)
            if shoreline_mesh != null:
                shoreline_meshes[case_key] = shoreline_mesh
            else:
                push_warning("[MapView] Missing mesh for shoreline case '%s'" % case_key)
        mesh_library["shoreline"] = shoreline_meshes

func _extract_mesh(scene: PackedScene) -> Mesh:
    if scene == null:
        return null
    var instance: Node = scene.instantiate()
    var mesh := _find_first_mesh(instance)
    instance.free()
    return mesh

func _find_first_mesh(node: Node) -> Mesh:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        return mesh_instance.mesh
    for child in node.get_children():
        var mesh := _find_first_mesh(child)
        if mesh != null:
            return mesh
    return null

func _update_terrain() -> void:
    if not is_node_ready():
        pending_map_refresh = true
        return

    var grouped_hexes := _group_hexes_by_region()
    var active_regions: Array = grouped_hexes.keys()
    var terrain_meshes: Dictionary = mesh_library.get("terrain", {})

    for region_key in active_regions:
        var region_mesh: Mesh = terrain_meshes.get(region_key, null)
        if region_mesh == null:
            push_warning("[MapView] No mesh registered for terrain region '%s'" % region_key)
            continue
        var node := _get_or_create_region_node(region_key)
        var entries: Array = grouped_hexes[region_key]
        _populate_region_multimesh(node, entries, region_mesh)

    var stale_regions: Array = []
    for existing_region in region_nodes.keys():
        if not grouped_hexes.has(existing_region):
            stale_regions.append(existing_region)
    for stale_region in stale_regions:
        var stale_node: MultiMeshInstance3D = region_nodes[stale_region]
        if is_instance_valid(stale_node):
            stale_node.queue_free()
        region_nodes.erase(stale_region)

func _group_hexes_by_region() -> Dictionary:
    var grouped: Dictionary = {}
    var hexes_data: Variant = map_data.get("hexes", {})
    match typeof(hexes_data):
        TYPE_ARRAY:
            for entry_variant in hexes_data:
                _accumulate_hex_entry(grouped, entry_variant)
        TYPE_DICTIONARY:
            for value in (hexes_data as Dictionary).values():
                _accumulate_hex_entry(grouped, value)
        _:
            pass
    return grouped

func _accumulate_hex_entry(grouped: Dictionary, entry_variant: Variant) -> void:
    if typeof(entry_variant) != TYPE_DICTIONARY:
        return
    var entry: Dictionary = entry_variant
    var region_key := String(entry.get("region", ""))
    if region_key.is_empty():
        return
    if not grouped.has(region_key):
        grouped[region_key] = []
    var bucket: Array = grouped[region_key]
    bucket.append(entry)
    grouped[region_key] = bucket

func _get_or_create_region_node(region_key: String) -> MultiMeshInstance3D:
    if region_nodes.has(region_key):
        var existing: MultiMeshInstance3D = region_nodes[region_key]
        if is_instance_valid(existing):
            return existing
    var node := MultiMeshInstance3D.new()
    node.name = "Region_%s" % region_key
    terrain_root.add_child(node)
    region_nodes[region_key] = node
    return node

func _populate_region_multimesh(node: MultiMeshInstance3D, entries: Array, mesh: Mesh) -> void:
    var count: int = entries.size()
    var multi_mesh := node.multimesh
    if multi_mesh == null:
        multi_mesh = MultiMesh.new()
    multi_mesh.mesh = mesh
    multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
    multi_mesh.instance_count = count
    for index in range(count):
        var entry: Dictionary = entries[index]
        var axial := _to_axial(entry.get("coord"))
        var position := _axial_to_local(axial)
        position.y = float(entry.get("elev", 0.0))
        var transform := Transform3D(Basis(), position)
        multi_mesh.set_instance_transform(index, transform)
    node.multimesh = multi_mesh
    node.visible = count > 0

func _to_axial(value: Variant) -> Vector2i:
    match typeof(value):
        TYPE_VECTOR2I:
            return value
        TYPE_VECTOR2:
            var vec2: Vector2 = value
            return Vector2i(int(round(vec2.x)), int(round(vec2.y)))
        TYPE_ARRAY:
            var arr: Array = value
            if arr.size() >= 2:
                return Vector2i(int(arr[0]), int(arr[1]))
        TYPE_DICTIONARY:
            var dict: Dictionary = value
            if dict.has("x") and dict.has("y"):
                return Vector2i(int(dict["x"]), int(dict["y"]))
            if dict.has("q") and dict.has("r"):
                return Vector2i(int(dict["q"]), int(dict["r"]))
    return Vector2i.ZERO

func _axial_to_local(coord: Vector2i) -> Vector3:
    var q := float(coord.x)
    var r := float(coord.y)
    var x := HEX_SIZE * ((SQRT_3 * q) + (SQRT_3 * 0.5 * r))
    var z := HEX_SIZE * (1.5 * r)
    return Vector3(x, 0.0, z)
