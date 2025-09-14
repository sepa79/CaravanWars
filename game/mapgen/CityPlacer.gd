extends RefCounted
class_name MapGenCityPlacer

var rng: RandomNumberGenerator
var map_width: float = 150.0
var map_height: float = 150.0
var border_margin: float = 30.0

func _init(_rng: RandomNumberGenerator) -> void:
    rng = _rng

## Places city centers using Poisson disk sampling (blue-noise).
## Ensures a minimum distance between any two cities.
func place_cities(
    count: int = 3,
    min_distance: float = 20.0,
    max_distance: float = 40.0,
    width: float = 150.0,
    height: float = 150.0,
    p_border_margin: float = 30.0
) -> Array[Vector2]:
    map_width = width
    map_height = height
    border_margin = p_border_margin
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

    var initial_point := Vector2(
        rng.randf_range(border_margin, map_width - border_margin),
        rng.randf_range(border_margin, map_height - border_margin)
    )
    samples.append(initial_point)
    var initial_index: int = _grid_index(initial_point, cell_size, grid_width)
    grid[initial_index] = 0
    active.append(0)

    var attempts: int = 0
    var max_attempts: int = count * k * 2
    while active.size() > 0 and samples.size() < count and attempts < max_attempts:
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
        attempts += 1

    return samples

func _generate_point_around(p: Vector2, min_distance: float, max_distance: float) -> Vector2:
    var r: float = rng.randf_range(min_distance, max_distance)
    var angle: float = rng.randf() * TAU
    return Vector2(p.x + r * cos(angle), p.y + r * sin(angle))

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
    if p.x < border_margin or p.y < border_margin or p.x >= map_width - border_margin or p.y >= map_height - border_margin:
        return false
    var gx: int = int(p.x / cell_size)
    var gy: int = int(p.y / cell_size)
    for x in range(max(0, gx - 2), min(grid_width, gx + 3)):
        for y in range(max(0, gy - 2), min(grid_height, gy + 3)):
            var index: int = grid[y * grid_width + x]
            if index != -1 and samples[index].distance_to(p) < min_distance:
                return false
    return true

## Selects city locations from a fertility field.
## Finds local maxima and keeps those spaced by at least `min_distance`.
## Returns a dictionary with `cities` Array[Vector2] and `capitals` Array[int]
## containing indexes of cities chosen as capitals.
func select_city_sites(field: Array, cities_target: int, min_distance: float, p_border_margin: float = 30.0) -> Dictionary:
    border_margin = p_border_margin
    var result: Dictionary = {"cities": [], "capitals": [], "leftovers": []}
    var h: int = field.size()
    if h == 0:
        return result
    var w: int = field[0].size()
    var candidates: Array = []
    for y in range(h):
        for x in range(w):
            if x < border_margin or x > w - border_margin or y < border_margin or y > h - border_margin:
                continue
            var v: float = field[y][x]
            var is_peak: bool = true
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if dx == 0 and dy == 0:
                        continue
                    var nx: int = x + dx
                    var ny: int = y + dy
                    if nx >= 0 and nx < w and ny >= 0 and ny < h:
                        if field[ny][nx] > v:
                            is_peak = false
                            break
                if not is_peak:
                    break
            if is_peak:
                candidates.append({"pos": Vector2(x + 0.5, y + 0.5), "score": v})
    candidates.sort_custom(func(a, b): return a["score"] > b["score"])
    var cities: Array[Vector2] = []
    var leftovers: Array[Vector2] = []
    for c in candidates:
        var p: Vector2 = c["pos"]
        var valid: bool = true
        for existing in cities:
            if existing.distance_to(p) < min_distance:
                valid = false
                break
        if valid and cities.size() < cities_target:
            cities.append(p)
        else:
            leftovers.append(p)
    result["cities"] = cities
    result["leftovers"] = leftovers
    if cities.size() > 0:
        var cap_count: int = rng.randi_range(1, min(3, cities.size()))
        var indices: Array[int] = []
        for i in range(cities.size()):
            indices.append(i)
        # Shuffle indices deterministically using the injected RNG
        for i in range(indices.size() - 1, 0, -1):
            var j: int = rng.randi_range(0, i)
            var tmp: int = indices[i]
            indices[i] = indices[j]
            indices[j] = tmp
        for i in range(cap_count):
            result["capitals"].append(indices[i])
    return result
