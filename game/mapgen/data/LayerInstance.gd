extends RefCounted
class_name LayerInstance

const AssetCatalogScript: GDScript = preload("res://mapgen/data/AssetCatalog.gd")

var asset_id: StringName
var rotation: int
var scale: float
var offset: Vector2

func _init(
    p_asset_id: StringName = StringName(),
    p_rotation: int = 0,
    p_scale: float = 1.0,
    p_offset: Vector2 = Vector2.ZERO
) -> void:
    asset_id = p_asset_id
    rotation = p_rotation
    scale = p_scale
    offset = p_offset

func to_serializable(catalog: AssetCatalog = null) -> Dictionary:
    var result: Dictionary = {
        "asset_id": String(asset_id),
        "rotation": rotation,
        "scale": scale,
        "offset": offset,
    }
    if catalog != null:
        result["role"] = AssetCatalogScript.role_to_string(catalog.get_role(asset_id))
        result["rotation_steps"] = catalog.get_rotation_steps(asset_id)
        var scene_path := catalog.get_asset_path(asset_id)
        if not scene_path.is_empty():
            result["scene_path"] = scene_path
    return result
