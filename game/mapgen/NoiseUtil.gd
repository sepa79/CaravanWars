extends RefCounted
class_name NoiseUtil

## Creates a FastNoiseLite configured to approximate OpenSimplex noise.
func create_simplex(seed: int, octaves: int = 3, frequency: float = 0.05, gain: float = 0.5, lacunarity: float = 2.0) -> FastNoiseLite:
    var noise := FastNoiseLite.new()
    noise.seed = seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = frequency
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = octaves
    noise.fractal_lacunarity = lacunarity
    noise.fractal_gain = gain
    return noise

## Generates a 2D array of normalized noise values (0..1).
func generate_field(noise: FastNoiseLite, width: int, height: int, step: float = 1.0) -> Array:
    var field: Array = []
    for y in range(height):
        var row: Array = []
        for x in range(width):
            var v: float = noise.get_noise_2d(x * step, y * step)
            row.append((v + 1.0) * 0.5)
        field.append(row)
    return field

## Calculates a simple roughness field based on local differences.
func compute_roughness(field: Array) -> Array:
    var h: int = field.size()
    if h == 0:
        return []
    var w: int = field[0].size()
    var rough: Array = []
    for y in range(h):
        var row: Array = []
        for x in range(w):
            var v: float = field[y][x]
            var diff: float = 0.0
            var count: int = 0
            for offset in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
                var nx: int = x + offset[0]
                var ny: int = y + offset[1]
                if nx >= 0 and nx < w and ny >= 0 and ny < h:
                    diff += abs(v - field[ny][nx])
                    count += 1
            row.append(diff / count if count > 0 else 0.0)
        rough.append(row)
    return rough
