extends RefCounted
class_name MapTerrainStage

const MapGenerationParams := preload("res://map/generation/MapGenerationParams.gd")
const TERRAIN_CONTOUR_INTERVAL: float = 0.1
const EROSION_KERNEL: Array[float] = [0.05, 0.2, 0.5, 0.2, 0.05]

static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var size: int = state["map_size"]
    var total: int = size * size

    var noise := FastNoiseLite.new()
    noise.seed = params.rng_seed
    noise.frequency = 1.0 / float(size)
    noise.fractal_octaves = params.terrain_octaves
    noise.fractal_lacunarity = 2.0 + params.terrain_roughness
    noise.fractal_gain = 0.5 + params.terrain_roughness * 0.35

    var ridge_noise := FastNoiseLite.new()
    ridge_noise.seed = params.rng_seed + 17
    ridge_noise.frequency = 2.0 / float(size)
    ridge_noise.fractal_octaves = max(1, params.terrain_octaves - 2)
    ridge_noise.fractal_gain = 0.45

    var heightmap := PackedFloat32Array()
    heightmap.resize(total)
    var sea_mask := PackedByteArray()
    sea_mask.resize(total)

    var rng: RandomNumberGenerator = state["rng"]
    var erosion_passes: int = int(round(params.erosion_strength * 4.0))

    for y in range(size):
        for x in range(size):
            var nx: float = float(x) / float(size)
            var ny: float = float(y) / float(size)
            var base_height: float = (noise.get_noise_2d(nx * size, ny * size) + 1.0) * 0.5
            var ridge: float = (ridge_noise.get_noise_2d(nx * size, ny * size) + 1.0) * 0.5
            var mountain_factor: float = pow(ridge, 1.0 - clampf(params.mountain_scale, 0.0, 0.95))
            var height_value: float = clampf(base_height * (0.7 + params.mountain_scale * 0.2) + mountain_factor * 0.3, 0.0, 1.0)
            height_value = clampf(height_value, 0.0, 1.0)
            var jitter: float = (rng.randf() - 0.5) * 0.01
            height_value = clampf(height_value + jitter, 0.0, 1.0)
            var index: int = y * size + x
            heightmap[index] = height_value
            if height_value < params.sea_level:
                sea_mask[index] = 1
            else:
                sea_mask[index] = 0

    if erosion_passes > 0:
        heightmap = _apply_erosion(heightmap, size, erosion_passes)

    var slope_map: PackedFloat32Array = _calculate_slope(heightmap, size)
    var contours: Array[Dictionary] = _build_contours(heightmap, size)

    return {
        "heightmap": heightmap,
        "slope": slope_map,
        "sea_mask": sea_mask,
        "contours": contours,
    }

static func _apply_erosion(heightmap: PackedFloat32Array, size: int, passes: int) -> PackedFloat32Array:
    var result: PackedFloat32Array = heightmap.duplicate()
    var kernel_radius: int = int(EROSION_KERNEL.size() / 2)
    for _i in range(passes):
        var temp: PackedFloat32Array = result.duplicate()
        for y in range(size):
            for x in range(size):
                var acc: float = 0.0
                var weight: float = 0.0
                for ky in range(EROSION_KERNEL.size()):
                    var offset_y: int = ky - kernel_radius
                    var yy: int = int(clamp(y + offset_y, 0, size - 1))
                    for kx in range(EROSION_KERNEL.size()):
                        var offset_x: int = kx - kernel_radius
                        var xx: int = int(clamp(x + offset_x, 0, size - 1))
                        var idx: int = yy * size + xx
                        var weight_factor: float = EROSION_KERNEL[ky] * EROSION_KERNEL[kx]
                        acc += result[idx] * weight_factor
                        weight += weight_factor
                var index: int = y * size + x
                temp[index] = acc / maxf(weight, 0.001)
        result = temp
    return result

static func _calculate_slope(heightmap: PackedFloat32Array, size: int) -> PackedFloat32Array:
    var slope := PackedFloat32Array()
    slope.resize(size * size)
    for y in range(size):
        for x in range(size):
            var index: int = y * size + x
            var left: float = heightmap[index]
            if x > 0:
                left = heightmap[index - 1]
            var right: float = heightmap[index]
            if x < size - 1:
                right = heightmap[index + 1]
            var up: float = heightmap[index]
            if y > 0:
                up = heightmap[index - size]
            var down: float = heightmap[index]
            if y < size - 1:
                down = heightmap[index + size]
            var dx: float = (right - left) * 0.5
            var dy: float = (down - up) * 0.5
            var slope_value: float = sqrt(dx * dx + dy * dy)
            slope[index] = clampf(slope_value, 0.0, 1.0)
    return slope

static func _build_contours(heightmap: PackedFloat32Array, size: int) -> Array[Dictionary]:
    var contours_by_level: Dictionary = {}
    for y in range(size):
        for x in range(size):
            var index: int = y * size + x
            var height_value: float = heightmap[index]
            var level := int(round(height_value / TERRAIN_CONTOUR_INTERVAL))
            var level_value: float = float(level) * TERRAIN_CONTOUR_INTERVAL
            var delta: float = float(abs(height_value - level_value))
            if delta < TERRAIN_CONTOUR_INTERVAL * 0.1:
                if not contours_by_level.has(level):
                    contours_by_level[level] = {
                        "level": float(level_value),
                        "points": PackedVector2Array(),
                    }
                var contour: Dictionary = contours_by_level[level]
                var points: PackedVector2Array = contour["points"]
                points.append(Vector2(x, y))
    var contours_array: Array = contours_by_level.values()
    var typed_contours: Array[Dictionary] = []
    for contour_entry in contours_array:
        if contour_entry is Dictionary:
            typed_contours.append(contour_entry)
    return typed_contours
