extends RefCounted
class_name EdgeShaper

const EDGE_ORDER: Array[String] = [
    "north",
    "east",
    "south",
    "west",
]

const EDGE_TARGET_LEVELS: Dictionary = {
    "sea": 0.10,
    "plains": 0.45,
    "hills": 0.65,
    "mountains": 0.85,
}

const EDGE_PRIORITY: Dictionary = {
    "sea": 0,
    "plains": 1,
    "hills": 2,
    "mountains": 3,
}

func apply(width: int, height: int, heights: Dictionary, config: HexMapConfig) -> Dictionary:
    var result: Dictionary = heights.duplicate(true)
    var edges: Dictionary = config.get_all_edge_settings()
    for r in range(height):
        for q in range(width):
            var axial := Vector2i(q, r)
            var base_height: float = float(heights.get(axial, 0.5))
            var shaped_height: float = _shape_height_for_tile(q, r, width, height, edges, base_height)
            result[axial] = shaped_height
    return result

func _shape_height_for_tile(
    q: int,
    r: int,
    width: int,
    height: int,
    edges: Dictionary,
    base_height: float
) -> float:
    var best_height: float = base_height
    var best_priority: int = -1
    var best_order: int = EDGE_ORDER.size()
    for direction_index in range(EDGE_ORDER.size()):
        var direction: String = EDGE_ORDER[direction_index]
        var edge_info: Dictionary = edges.get(direction, {})
        var band_width: int = int(edge_info.get("width", 0))
        if band_width <= 0:
            continue
        var distance: int = _distance_to_edge(direction, q, r, width, height)
        if distance >= band_width:
            continue
        var terrain_type: String = String(edge_info.get("type", HexMapConfig.DEFAULT_EDGE_TYPE)).to_lower()
        var priority: int = int(EDGE_PRIORITY.get(terrain_type, 0))
        if priority < best_priority:
            continue
        if priority == best_priority and direction_index >= best_order:
            continue
        var target_height: float = float(EDGE_TARGET_LEVELS.get(terrain_type, base_height))
        var t: float = _smoothstep(0.0, float(max(1, band_width)), float(distance))
        var candidate: float = lerpf(target_height, base_height, t)
        best_priority = priority
        best_order = direction_index
        best_height = candidate
    return best_height

static func _distance_to_edge(direction: String, q: int, r: int, width: int, height: int) -> int:
    match direction:
        "north":
            return r
        "south":
            return max(0, height - 1 - r)
        "west":
            return q
        "east":
            return max(0, width - 1 - q)
        _:
            return 0

static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
    if is_equal_approx(edge0, edge1):
        return 1.0 if value >= edge1 else 0.0
    var t: float = clampf((value - edge0) / max(0.0001, edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
