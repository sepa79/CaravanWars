extends RefCounted
class_name HexCoord

const DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]

var q: int
var r: int

func _init(p_q: int = 0, p_r: int = 0) -> void:
    q = p_q
    r = p_r

func copy() -> HexCoord:
    return HexCoord.new(q, r)

func set_coord(p_q: int, p_r: int) -> void:
    q = p_q
    r = p_r

func to_vector2i() -> Vector2i:
    return Vector2i(q, r)

func add(other: HexCoord) -> HexCoord:
    return HexCoord.new(q + other.q, r + other.r)

func neighbor(direction_index: int) -> HexCoord:
    var wrapped_index := wrapi(direction_index, 0, DIRECTIONS.size())
    var dir := DIRECTIONS[wrapped_index]
    return HexCoord.new(q + dir.x, r + dir.y)

func neighbors() -> Array[HexCoord]:
    var result: Array[HexCoord] = []
    for dir in DIRECTIONS:
        result.append(HexCoord.new(q + dir.x, r + dir.y))
    return result

func distance_to(other: HexCoord) -> int:
    var dq := q - other.q
    var dr := r - other.r
    var ds := (-q - r) - (-other.q - other.r)
    return max(abs(dq), abs(dr), abs(ds))

static func from_vector2i(axial: Vector2i) -> HexCoord:
    return HexCoord.new(axial.x, axial.y)
