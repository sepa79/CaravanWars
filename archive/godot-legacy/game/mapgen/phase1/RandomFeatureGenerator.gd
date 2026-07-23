extends RefCounted
class_name RandomFeatureGenerator

const ScopedRngScript: GDScript = preload("res://mapgen/phase1/ScopedRng.gd")

const BASELINE_HEIGHT: float = 0.5
const FEATURE_MARGIN: int = 2

const PEAK_CORE_RADIUS: float = 1.0
const PEAK_HALO_RADIUS: float = 5.0
const PEAK_CORE_HEIGHT: float = 0.9
const PEAK_HALO_HEIGHT: float = 0.7

const HILL_CORE_RADIUS: float = 0.0
const HILL_HALO_RADIUS: float = 4.0
const HILL_CORE_HEIGHT: float = 0.65
const HILL_HALO_HEIGHT: float = 0.55

enum FeatureType {
    PEAK,
    HILL,
}

func apply(rng_state: int, width: int, height: int, base_heights: Dictionary, config: HexMapConfig) -> Dictionary:
    var result: Dictionary = base_heights.duplicate(true)
    var settings: Dictionary = config.get_random_feature_settings()
    var roughness_scale: float = 1.0
    if settings.has("roughness_scale"):
        roughness_scale = clampf(float(settings.get("roughness_scale", 1.0)), 0.25, 4.0)
    var feature_count: int = _determine_feature_count(rng_state, settings)
    if feature_count <= 0:
        return result
    var centers: Array[Vector2i] = _pick_feature_centers(rng_state, width, height, feature_count)
    if centers.is_empty():
        return result
    var falloff: String = String(settings.get("falloff", "smooth")).to_lower()
    var mode: String = String(settings.get("mode", "auto")).to_lower()
    for index in range(centers.size()):
        var center: Vector2i = centers[index]
        var feature_type: FeatureType = _choose_feature_type(rng_state, index, mode)
        _apply_feature(result, center, width, height, feature_type, falloff, roughness_scale)
    return result

func _determine_feature_count(rng_state: int, settings: Dictionary) -> int:
    var override_value: Variant = settings.get("count_override")
    if typeof(override_value) == TYPE_INT and int(override_value) >= 0:
        return int(override_value)
    var intensity: String = String(settings.get("intensity", "none")).to_lower()
    match intensity:
        "low":
            return ScopedRngScript.rand_int_scope(rng_state, ["features", "low"], "count", 2, 3)
        "medium":
            return ScopedRngScript.rand_int_scope(rng_state, ["features", "medium"], "count", 5, 7)
        "high":
            return ScopedRngScript.rand_int_scope(rng_state, ["features", "high"], "count", 10, 14)
        _:
            return 0

func _pick_feature_centers(rng_state: int, width: int, height: int, count: int) -> Array[Vector2i]:
    var centers: Array[Vector2i] = []
    if width <= 0 or height <= 0:
        return centers
    var margin_q: int = _calculate_margin(width)
    var margin_r: int = _calculate_margin(height)
    var used: Dictionary = {}
    for index in range(count):
        var scope: Array = ["center", index]
        var q_min: int = margin_q
        var q_max: int = max(margin_q, width - 1 - margin_q)
        var r_min: int = margin_r
        var r_max: int = max(margin_r, height - 1 - margin_r)
        var q_value: int = ScopedRngScript.rand_int_scope(rng_state, scope + ["q"], "position", q_min, q_max)
        var r_value: int = ScopedRngScript.rand_int_scope(rng_state, scope + ["r"], "position", r_min, r_max)
        var candidate := Vector2i(q_value, r_value)
        var attempts: int = 0
        while used.has(candidate) and attempts < width * height:
            if width > 0:
                q_value = (q_value + 1) % width
            if height > 0:
                if q_value == 0:
                    r_value = (r_value + 1) % height
                else:
                    r_value = r_value % height
            candidate = Vector2i(q_value, r_value)
            attempts += 1
        used[candidate] = true
        centers.append(candidate)
    return centers

func _choose_feature_type(rng_state: int, index: int, mode: String) -> FeatureType:
    match mode:
        "peaks_only":
            return FeatureType.PEAK
        "hills_only":
            return FeatureType.HILL
        _:
            var roll: float = ScopedRngScript.rand_scope(rng_state, ["feature", index], "mode")
            if roll < 0.4:
                return FeatureType.PEAK
            return FeatureType.HILL

func _apply_feature(
    heights: Dictionary,
    center: Vector2i,
    width: int,
    height: int,
    feature_type: FeatureType,
    falloff: String,
    roughness_scale: float
) -> void:
    for r in range(height):
        for q in range(width):
            var axial := Vector2i(q, r)
            var base_value: float = float(heights.get(axial, BASELINE_HEIGHT))
            var distance: float = float(_axial_distance(center, axial))
            var feature_height: float = _compute_feature_height(
                distance,
                feature_type,
                falloff,
                base_value,
                roughness_scale
            )
            if feature_height <= base_value:
                continue
            heights[axial] = feature_height

func _compute_feature_height(
    distance: float,
    feature_type: FeatureType,
    falloff: String,
    base_value: float,
    roughness_scale: float
) -> float:
    match feature_type:
        FeatureType.PEAK:
            return _scale_feature_height(_compute_peak_height(distance, falloff), base_value, roughness_scale)
        _:
            return _scale_feature_height(_compute_hill_height(distance, falloff), base_value, roughness_scale)

func _scale_feature_height(raw_height: float, base_value: float, roughness_scale: float) -> float:
    if raw_height <= base_value:
        return raw_height
    var delta: float = raw_height - base_value
    var scaled: float = base_value + delta * roughness_scale
    return clampf(scaled, 0.0, 1.0)

func _compute_peak_height(distance: float, falloff: String) -> float:
    if distance <= PEAK_CORE_RADIUS:
        return PEAK_CORE_HEIGHT
    if distance >= PEAK_HALO_RADIUS:
        return 0.0
    var t: float = (distance - PEAK_CORE_RADIUS) / max(0.0001, PEAK_HALO_RADIUS - PEAK_CORE_RADIUS)
    var eased: float = _apply_falloff(t, falloff)
    return lerpf(PEAK_CORE_HEIGHT, PEAK_HALO_HEIGHT, eased)

func _compute_hill_height(distance: float, falloff: String) -> float:
    if distance <= HILL_CORE_RADIUS:
        return HILL_CORE_HEIGHT
    if distance >= HILL_HALO_RADIUS:
        return 0.0
    var t: float = (distance - HILL_CORE_RADIUS) / max(0.0001, HILL_HALO_RADIUS - HILL_CORE_RADIUS)
    var eased: float = _apply_falloff(t, falloff)
    return lerpf(HILL_CORE_HEIGHT, HILL_HALO_HEIGHT, eased)

func _apply_falloff(t: float, falloff: String) -> float:
    var clamped: float = clampf(t, 0.0, 1.0)
    match falloff:
        "linear":
            return clamped
        _:
            return clamped * clamped * (3.0 - 2.0 * clamped)

func _calculate_margin(dimension: int) -> int:
    if dimension <= FEATURE_MARGIN * 2 + 1:
        return 0
    return FEATURE_MARGIN

static func _axial_distance(a: Vector2i, b: Vector2i) -> int:
    var dq: int = a.x - b.x
    var dr: int = a.y - b.y
    var ds: int = (-a.x - a.y) - (-b.x - b.y)
    return max(abs(dq), abs(dr), abs(ds))
