extends RefCounted
class_name HexGrid

const AXIAL_DIRECTIONS: Array[Vector2i] = HexCoord.DIRECTIONS

var radius: int

func _init(p_radius: int = 16) -> void:
    radius = max(1, p_radius)

func set_radius(p_radius: int) -> void:
    radius = max(1, p_radius)

func is_within_bounds(coord: HexCoord) -> bool:
    var q := coord.q
    var r := coord.r
    var s := -q - r
    return abs(q) <= radius and abs(r) <= radius and abs(s) <= radius

func get_neighbor_coords(coord: HexCoord) -> Array[HexCoord]:
    var neighbors: Array[HexCoord] = []
    for direction in AXIAL_DIRECTIONS:
        var neighbor := HexCoord.new(coord.q + direction.x, coord.r + direction.y)
        if is_within_bounds(neighbor):
            neighbors.append(neighbor)
    return neighbors

func axial_distance(a: HexCoord, b: HexCoord) -> int:
    return a.distance_to(b)

func axial_to_world(coord: HexCoord, hex_size: float = 1.0) -> Vector2:
    var size: float = max(0.001, hex_size)
    var x: float = size * ((sqrt(3.0) * coord.q) + (sqrt(3.0) * 0.5 * coord.r))
    var y: float = size * (1.5 * coord.r)
    return Vector2(x, y)

func each_coordinate(callback: Callable) -> void:
    for q in range(-radius, radius + 1):
        var r1: int = max(-radius, -q - radius)
        var r2: int = min(radius, -q + radius)
        for r in range(r1, r2 + 1):
            callback.call(HexCoord.new(q, r))
