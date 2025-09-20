extends RefCounted
class_name Tile

const TERRAIN_SEA := StringName("SEA")
const TERRAIN_PLAINS := StringName("PLAINS")
const TERRAIN_HILLS := StringName("HILLS")
const TERRAIN_MOUNTAINS := StringName("MOUNTAINS")

const VARIANT_A := StringName("A")
const VARIANT_B := StringName("B")
const VARIANT_C := StringName("C")

const ALL_VARIANTS: Array[StringName] = [
    VARIANT_A,
    VARIANT_B,
    VARIANT_C,
]

var q: int
var r: int
var terrain_type: StringName = TERRAIN_PLAINS
var height_value: float = 0.0
var tile_rotation: int = 0
var visual_variant: StringName = VARIANT_A
var with_trees: bool = false
var draw_stack: Array = []

func _init(p_q: int = 0, p_r: int = 0) -> void:
    q = p_q
    r = p_r
    draw_stack = []

func axial() -> Vector2i:
    return Vector2i(q, r)

func add_layer(layer) -> void:
    if not draw_stack is Array:
        draw_stack = []
    draw_stack.append(layer)

func clear_layers() -> void:
    draw_stack.clear()

func to_serializable(catalog = null) -> Dictionary:
    var serialized_layers: Array[Dictionary] = []
    for layer in draw_stack:
        if layer is LayerInstance:
            serialized_layers.append(layer.to_serializable(catalog))
    return {
        "coord": axial(),
        "q": q,
        "r": r,
        "terrain_type": String(terrain_type),
        "height_value": height_value,
        "tile_rotation": tile_rotation,
        "visual_variant": String(visual_variant),
        "with_trees": with_trees,
        "draw_stack": serialized_layers,
    }
