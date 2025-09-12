extends RefCounted
class_name CityPlacer

var rng: RandomNumberGenerator
var map_width: float = 100.0
var map_height: float = 100.0

const MapUtils = preload("res://map/MapUtils.gd")

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Places city centers using Poisson disk sampling (blue-noise).
## Ensures a minimum distance between any two cities.
func place_cities(
    count: int = 3,
    min_distance: float = 20.0,
    max_distance: float = 40.0,
    width: float = 100.0,
    height: float = 100.0
) -> Array[Vector2]:
    map_width = width
    map_height = height
    var radius: float = min_distance
    var k: int = 30
    var cell_size: float = radius / sqrt(2.0)
    var grid_width: int = int(ceil(map_width / cell_size))
    var grid_height: int = int(ceil(map_height / cell_size))
    var grid: Array[int] = []
    for i in range(grid_width * grid_height):
        grid.append(-1)

    var samples: Array[Vector2] = []
    var active: Array[int] = []

    var initial_point := Vector2(rng.randf() * map_width, rng.randf() * map_height)
    initial_point = MapUtils.ensure_within_bounds(initial_point, map_width, map_height)
    samples.append(initial_point)
    var initial_index: int = _grid_index(initial_point, cell_size, grid_width)
    grid[initial_index] = 0
    active.append(0)

    while active.size() > 0 and samples.size() < count:
        var idx: int = active[rng.randi_range(0, active.size() - 1)]
        var point: Vector2 = samples[idx]
        var found: bool = false
        for _i in range(k):
            var new_point: Vector2 = _generate_point_around(point, min_distance, max_distance)
            if _is_valid(new_point, cell_size, grid_width, grid_height, grid, samples, min_distance):
                samples.append(new_point)
                active.append(samples.size() - 1)
                grid[_grid_index(new_point, cell_size, grid_width)] = samples.size() - 1
                found = true
                if samples.size() >= count:
                    break
        if not found:
            active.erase(idx)

    return samples

func _generate_point_around(p: Vector2, min_distance: float, max_distance: float) -> Vector2:
    var r: float = rng.randf_range(min_distance, max_distance)
    var angle: float = rng.randf() * TAU
    var candidate := Vector2(p.x + r * cos(angle), p.y + r * sin(angle))
    return MapUtils.ensure_within_bounds(candidate, map_width, map_height)

func _grid_index(p: Vector2, cell_size: float, grid_width: int) -> int:
    var gx: int = int(p.x / cell_size)
    var gy: int = int(p.y / cell_size)
    return gy * grid_width + gx

func _is_valid(
    p: Vector2,
    cell_size: float,
    grid_width: int,
    grid_height: int,
    grid: Array[int],
    samples: Array[Vector2],
    min_distance: float
) -> bool:
    if not MapUtils.is_within_bounds(p, map_width, map_height):
        return false
    var gx: int = int(p.x / cell_size)
    var gy: int = int(p.y / cell_size)
    for x in range(max(0, gx - 2), min(grid_width, gx + 3)):
        for y in range(max(0, gy - 2), min(grid_height, gy + 3)):
            var index: int = grid[y * grid_width + x]
            if index != -1 and samples[index].distance_to(p) < min_distance:
                return false
    return true
