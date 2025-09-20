extends Node3D
class_name HexTileStack

const SURFACE_PIVOT_EPSILON: float = 0.0001

var _base_instance: MeshInstance3D
var _layer_nodes: Dictionary = {}
var _base_transparency: float = 0.0
var _layer_transparency: Dictionary = {}
var _cached_stack: Array = []

func configure(elev: float, stack: Array, meshes: Dictionary) -> void:
    var base_mesh: Mesh = null
    var base_mesh_variant: Variant = meshes.get("base")
    if base_mesh_variant is Mesh:
        base_mesh = base_mesh_variant as Mesh
    var base_instance := _ensure_base_instance()
    base_instance.mesh = base_mesh
    base_instance.visible = base_mesh != null
    var grass_top := float(meshes.get("grass_top", elev))
    var grass_height := float(meshes.get("grass_height", 0.0))
    if grass_height < 0.0:
        grass_height = 0.0
    var base_aabb := AABB()
    if base_mesh != null:
        base_aabb = base_mesh.get_aabb()
    var base_transform := _make_base_transform(base_mesh, base_aabb, grass_top, grass_height)
    base_instance.transform = base_transform
    base_instance.transparency = clampf(_base_transparency, 0.0, 1.0)
    var surfaces_variant: Variant = meshes.get("surfaces")
    var surface_meshes: Dictionary = {}
    if typeof(surfaces_variant) == TYPE_DICTIONARY:
        surface_meshes = surfaces_variant
    var retained_layers: Dictionary = {}
    for layer_variant in stack:
        if typeof(layer_variant) != TYPE_DICTIONARY:
            continue
        var layer_data: Dictionary = layer_variant
        var layer_id := String(layer_data.get("id", ""))
        if layer_id.is_empty():
            continue
        var mesh_region := String(layer_data.get("mesh_region", ""))
        var variant_key := String(layer_data.get("variant", ""))
        var layer_top := float(layer_data.get("top", elev))
        var layer_bottom := float(layer_data.get("bottom", layer_top))
        var surface_mesh := _resolve_surface_mesh(surface_meshes, mesh_region, variant_key)
        var layer_instance := _ensure_layer_instance(layer_id)
        layer_instance.mesh = surface_mesh
        if surface_mesh != null:
            layer_instance.transform = _make_surface_transform(surface_mesh, layer_top, layer_bottom)
            layer_instance.visible = true
        else:
            layer_instance.transform = Transform3D.IDENTITY
            layer_instance.visible = false
        var transparency := clampf(float(_layer_transparency.get(layer_id, 0.0)), 0.0, 1.0)
        layer_instance.transparency = transparency
        retained_layers[layer_id] = true
    _hide_unused_layers(retained_layers)
    _cached_stack = stack.duplicate()

func set_base_transparency(value: float) -> void:
    _base_transparency = clampf(value, 0.0, 1.0)
    if _base_instance != null:
        _base_instance.transparency = _base_transparency

func set_layer_transparency(layer_id: String, value: float) -> void:
    var clamped := clampf(value, 0.0, 1.0)
    _layer_transparency[layer_id] = clamped
    if _layer_nodes.has(layer_id):
        var instance_variant: Variant = _layer_nodes[layer_id]
        if instance_variant is MeshInstance3D:
            (instance_variant as MeshInstance3D).transparency = clamped

func get_combined_aabb() -> Dictionary:
    var has_bounds := false
    var combined := AABB()
    var root_transform := global_transform
    if _base_instance != null and _base_instance.mesh != null and _base_instance.visible:
        var base_aabb := _base_instance.mesh.get_aabb()
        var transformed_base := _transform_aabb(base_aabb, root_transform * _base_instance.transform)
        combined = transformed_base
        has_bounds = true
    for key in _layer_nodes.keys():
        var instance_variant: Variant = _layer_nodes[key]
        if not (instance_variant is MeshInstance3D):
            continue
        var mesh_instance := instance_variant as MeshInstance3D
        if mesh_instance.mesh == null or not mesh_instance.visible:
            continue
        var mesh_aabb := mesh_instance.mesh.get_aabb()
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

func _ensure_layer_instance(layer_id: String) -> MeshInstance3D:
    if _layer_nodes.has(layer_id):
        var existing_variant: Variant = _layer_nodes[layer_id]
        if existing_variant is MeshInstance3D:
            return existing_variant as MeshInstance3D
    var instance := MeshInstance3D.new()
    instance.name = "%sLayer" % layer_id.capitalize()
    add_child(instance)
    _layer_nodes[layer_id] = instance
    return instance

func _hide_unused_layers(retained: Dictionary) -> void:
    for key in _layer_nodes.keys():
        if retained.has(key):
            continue
        var instance_variant: Variant = _layer_nodes[key]
        if not (instance_variant is MeshInstance3D):
            continue
        var mesh_instance := instance_variant as MeshInstance3D
        mesh_instance.visible = false
        mesh_instance.mesh = null

func _resolve_surface_mesh(surface_meshes: Dictionary, mesh_region: String, variant_key: String) -> Mesh:
    var region_variant: Variant = surface_meshes.get(mesh_region)
    if typeof(region_variant) != TYPE_DICTIONARY:
        return null
    var region_meshes: Dictionary = region_variant
    if not variant_key.is_empty() and region_meshes.has(variant_key):
        var mesh_variant: Variant = region_meshes[variant_key]
        if mesh_variant is Mesh:
            return mesh_variant as Mesh
    for value in region_meshes.values():
        if value is Mesh:
            return value as Mesh
    return null

func _make_base_transform(base_mesh: Mesh, base_aabb: AABB, grass_top: float, grass_height: float) -> Transform3D:
    var origin := Vector3(0.0, grass_top, 0.0)
    var basis := Basis.IDENTITY
    if base_mesh == null:
        basis = basis.scaled(Vector3(1.0, grass_height, 1.0))
        return Transform3D(basis, origin)
    var min_y: float = base_aabb.position.y
    var height: float = base_aabb.size.y
    var max_y: float = min_y + height
    var safe_height: float = max(height, SURFACE_PIVOT_EPSILON)
    var y_scale: float = 0.0
    if safe_height > 0.0:
        y_scale = grass_height / safe_height
    basis = basis.scaled(Vector3(1.0, y_scale, 1.0))
    origin.y = grass_top - max_y * y_scale
    return Transform3D(basis, origin)

func _make_surface_transform(surface_mesh: Mesh, layer_top: float, layer_bottom: float) -> Transform3D:
    var top_height := layer_top
    var bottom_height := layer_bottom
    if top_height < bottom_height:
        var swap := top_height
        top_height = bottom_height
        bottom_height = swap
    var desired_height := top_height - bottom_height
    if desired_height < 0.0:
        desired_height = 0.0
    var origin := Vector3(0.0, bottom_height, 0.0)
    var basis := Basis.IDENTITY
    if surface_mesh == null:
        if desired_height <= SURFACE_PIVOT_EPSILON:
            return Transform3D(basis, origin)
        basis = basis.scaled(Vector3(1.0, desired_height, 1.0))
        return Transform3D(basis, origin)
    var surface_aabb := surface_mesh.get_aabb()
    var min_y: float = surface_aabb.position.y
    var height: float = surface_aabb.size.y
    var max_y: float = min_y + height
    if max_y <= SURFACE_PIVOT_EPSILON:
        if is_zero_approx(height):
            origin.y = bottom_height - min_y
            return Transform3D(basis, origin)
        var y_scale_below: float = 0.0
        if desired_height > SURFACE_PIVOT_EPSILON:
            y_scale_below = desired_height / height
        basis = basis.scaled(Vector3(1.0, y_scale_below, 1.0))
        origin.y = bottom_height - min_y * y_scale_below
        return Transform3D(basis, origin)
    var span: float = max_y - min_y
    if span <= SURFACE_PIVOT_EPSILON or desired_height <= SURFACE_PIVOT_EPSILON:
        origin.y = bottom_height - min_y
        return Transform3D(basis, origin)
    var y_scale: float = desired_height / span
    basis = basis.scaled(Vector3(1.0, y_scale, 1.0))
    var scaled_min_y := min_y * y_scale
    var scaled_max_y := max_y * y_scale
    var origin_from_bottom := bottom_height - scaled_min_y
    var origin_from_top := top_height - scaled_max_y
    var aligned_origin_y := origin_from_bottom
    if abs(origin_from_top - origin_from_bottom) > SURFACE_PIVOT_EPSILON:
        aligned_origin_y = (origin_from_bottom + origin_from_top) * 0.5
    origin.y = aligned_origin_y
    return Transform3D(basis, origin)

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
