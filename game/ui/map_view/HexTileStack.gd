extends Node3D
class_name HexTileStack

const SURFACE_PIVOT_EPSILON: float = 0.0001

class TileLayer:
    var layer_id: String
    var mesh_region_id: String
    var variant_key: String
    var top_height: float
    var bottom_height: float

    func _init(layer_id_value: String = "", mesh_region_id_value: String = "", variant_key_value: String = "", top_height_value: float = 0.0, bottom_height_value: float = 0.0) -> void:
        layer_id = layer_id_value
        mesh_region_id = mesh_region_id_value
        variant_key = variant_key_value
        top_height = top_height_value
        bottom_height = bottom_height_value

class MeshBundle:
    var base_mesh_resource: Mesh
    var grass_top_height: float
    var grass_layer_height: float
    var surface_meshes: Dictionary

    func _init(base_mesh_value: Mesh = null, grass_top_value: float = 0.0, grass_height_value: float = 0.0, surface_meshes_value: Dictionary = {}) -> void:
        base_mesh_resource = base_mesh_value
        grass_top_height = grass_top_value
        grass_layer_height = grass_height_value
        surface_meshes = surface_meshes_value

    func get_surface_mesh(mesh_region_id: String, variant_key: String) -> Mesh:
        if surface_meshes.is_empty() or not surface_meshes.has(mesh_region_id):
            return null
        var region_meshes: Dictionary = surface_meshes[mesh_region_id]
        if not variant_key.is_empty() and region_meshes.has(variant_key):
            return region_meshes[variant_key]
        for mesh in region_meshes.values():
            return mesh
        return null

var _base_instance: MeshInstance3D
var _layer_nodes: Dictionary[String, MeshInstance3D] = {}
var _base_transparency: float = 0.0
var _layer_transparency: Dictionary[String, float] = {}
var _cached_stack: Array[TileLayer] = []

func configure_stack(stack: Array[TileLayer], mesh_bundle: MeshBundle) -> void:
    var base_instance := _ensure_base_instance()
    base_instance.mesh = mesh_bundle.base_mesh_resource
    base_instance.visible = mesh_bundle.base_mesh_resource != null
    var base_aabb := AABB()
    if mesh_bundle.base_mesh_resource != null:
        base_aabb = mesh_bundle.base_mesh_resource.get_aabb()
    var base_transform := _make_base_transform(mesh_bundle.base_mesh_resource, base_aabb, mesh_bundle.grass_top_height, mesh_bundle.grass_layer_height)
    base_instance.transform = base_transform
    base_instance.transparency = clampf(_base_transparency, 0.0, 1.0)
    var retained_layers: Dictionary[String, bool] = {}
    _cached_stack.clear()
    for layer_entry in stack:
        if layer_entry == null:
            continue
        _cached_stack.append(layer_entry)
        var layer_instance := _ensure_layer_instance(layer_entry.layer_id)
        var surface_mesh := mesh_bundle.get_surface_mesh(layer_entry.mesh_region_id, layer_entry.variant_key)
        layer_instance.mesh = surface_mesh
        if surface_mesh != null:
            layer_instance.transform = _make_surface_transform(surface_mesh, layer_entry.top_height, layer_entry.bottom_height)
            layer_instance.visible = true
        else:
            layer_instance.transform = Transform3D.IDENTITY
            layer_instance.visible = false
        var stored_transparency: float = _layer_transparency.get(layer_entry.layer_id, 0.0)
        var transparency := clampf(stored_transparency, 0.0, 1.0)
        layer_instance.transparency = transparency
        retained_layers[layer_entry.layer_id] = true
    _hide_unused_layers(retained_layers)

func set_base_transparency(value: float) -> void:
    _base_transparency = clampf(value, 0.0, 1.0)
    if _base_instance != null:
        _base_instance.transparency = _base_transparency

func set_layer_transparency(layer_id: String, value: float) -> void:
    var clamped := clampf(value, 0.0, 1.0)
    _layer_transparency[layer_id] = clamped
    if _layer_nodes.has(layer_id):
        _layer_nodes[layer_id].transparency = clamped

func get_combined_aabb() -> Dictionary:
    var has_bounds := false
    var combined := AABB()
    var root_transform := global_transform
    if _base_instance != null and _base_instance.mesh != null and _base_instance.visible:
        var base_aabb := _base_instance.mesh.get_aabb()
        var transformed_base := _transform_aabb(base_aabb, root_transform * _base_instance.transform)
        combined = transformed_base
        has_bounds = true
    for mesh_instance in _layer_nodes.values():
        if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
            continue
        var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
        var transformed := _transform_aabb(mesh_aabb, root_transform * mesh_instance.transform)
        if not has_bounds:
            combined = transformed
            has_bounds = true
        else:
            combined = combined.merge(transformed)
    return {
        "has": has_bounds,
        "aabb": combined,
    }

func _ensure_base_instance() -> MeshInstance3D:
    if _base_instance == null:
        _base_instance = MeshInstance3D.new()
        _base_instance.name = "LandBase"
        add_child(_base_instance)
    return _base_instance

func _ensure_layer_instance(layer_id_value: String) -> MeshInstance3D:
    if _layer_nodes.has(layer_id_value):
        return _layer_nodes[layer_id_value]
    var instance := MeshInstance3D.new()
    instance.name = "%sLayer" % layer_id_value.capitalize()
    add_child(instance)
    _layer_nodes[layer_id_value] = instance
    return instance

func _hide_unused_layers(retained: Dictionary[String, bool]) -> void:
    for key in _layer_nodes.keys():
        if retained.has(key):
            continue
        var mesh_node := _layer_nodes[key]
        if mesh_node == null:
            continue
        mesh_node.visible = false
        mesh_node.mesh = null

func _make_base_transform(base_mesh_value: Mesh, base_aabb_value: AABB, grass_top_height: float, grass_layer_height: float) -> Transform3D:
    var origin := Vector3(0.0, grass_top_height, 0.0)
    var local_basis := Basis.IDENTITY
    if base_mesh_value == null:
        local_basis = local_basis.scaled(Vector3(1.0, grass_layer_height, 1.0))
        return Transform3D(local_basis, origin)
    var min_y: float = base_aabb_value.position.y
    var height: float = base_aabb_value.size.y
    var max_y: float = min_y + height
    var safe_height: float = max(height, SURFACE_PIVOT_EPSILON)
    var y_scale: float = 0.0
    if safe_height > 0.0:
        y_scale = grass_layer_height / safe_height
    local_basis = local_basis.scaled(Vector3(1.0, y_scale, 1.0))
    origin.y = grass_top_height - max_y * y_scale
    return Transform3D(local_basis, origin)

func _make_surface_transform(surface_mesh_value: Mesh, layer_top_height: float, layer_bottom_height: float) -> Transform3D:
    var top_height := layer_top_height
    var bottom_height := layer_bottom_height
    if top_height < bottom_height:
        var swap := top_height
        top_height = bottom_height
        bottom_height = swap
    var desired_height := top_height - bottom_height
    if desired_height < 0.0:
        desired_height = 0.0
    var origin := Vector3(0.0, bottom_height, 0.0)
    var local_basis := Basis.IDENTITY
    if surface_mesh_value == null:
        if desired_height <= SURFACE_PIVOT_EPSILON:
            return Transform3D(local_basis, origin)
        local_basis = local_basis.scaled(Vector3(1.0, desired_height, 1.0))
        return Transform3D(local_basis, origin)
    var surface_aabb := surface_mesh_value.get_aabb()
    var min_y: float = surface_aabb.position.y
    var height: float = surface_aabb.size.y
    var max_y: float = min_y + height
    if max_y <= SURFACE_PIVOT_EPSILON:
        if is_zero_approx(height):
            origin.y = bottom_height - min_y
            return Transform3D(local_basis, origin)
        var y_scale_below: float = 0.0
        if desired_height > SURFACE_PIVOT_EPSILON:
            y_scale_below = desired_height / height
        local_basis = local_basis.scaled(Vector3(1.0, y_scale_below, 1.0))
        origin.y = bottom_height - min_y * y_scale_below
        return Transform3D(local_basis, origin)
    var span: float = max_y - min_y
    if span <= SURFACE_PIVOT_EPSILON or desired_height <= SURFACE_PIVOT_EPSILON:
        origin.y = bottom_height - min_y
        return Transform3D(local_basis, origin)
    var y_scale: float = desired_height / span
    local_basis = local_basis.scaled(Vector3(1.0, y_scale, 1.0))
    var scaled_min_y := min_y * y_scale
    var scaled_max_y := max_y * y_scale
    var origin_from_bottom := bottom_height - scaled_min_y
    var origin_from_top := top_height - scaled_max_y
    var aligned_origin_y := origin_from_bottom
    if abs(origin_from_top - origin_from_bottom) > SURFACE_PIVOT_EPSILON:
        aligned_origin_y = (origin_from_bottom + origin_from_top) * 0.5
    origin.y = aligned_origin_y
    return Transform3D(local_basis, origin)

func _transform_aabb(input_aabb: AABB, input_transform: Transform3D) -> AABB:
    var start: Vector3 = input_aabb.position
    var end: Vector3 = input_aabb.position + input_aabb.size
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    for xi in range(2):
        var x := start.x if xi == 0 else end.x
        for yi in range(2):
            var y := start.y if yi == 0 else end.y
            for zi in range(2):
                var z := start.z if zi == 0 else end.z
                var corner := input_transform * Vector3(x, y, z)
                min_corner.x = min(min_corner.x, corner.x)
                min_corner.y = min(min_corner.y, corner.y)
                min_corner.z = min(min_corner.z, corner.z)
                max_corner.x = max(max_corner.x, corner.x)
                max_corner.y = max(max_corner.y, corner.y)
                max_corner.z = max(max_corner.z, corner.z)
    return AABB(min_corner, max_corner - min_corner)
