extends RefCounted
class_name ScopedRng

const HASH_MODULUS: int = 2147483647

static func rand(seed: int, q: int, r: int, purpose: String) -> float:
    return rand_scope(seed, [q, r], purpose)

static func rand_scope(seed: int, scope: Array, purpose: String) -> float:
    var hashed: int = _hash_components(seed, scope, purpose)
    var normalized: float = float(hashed % HASH_MODULUS) / float(HASH_MODULUS)
    return clampf(normalized, 0.0, 0.999999)

static func rand_range(seed: int, q: int, r: int, purpose: String, minimum: float, maximum: float) -> float:
    if maximum <= minimum:
        return minimum
    var sample: float = rand(seed, q, r, purpose)
    return lerpf(minimum, maximum, sample)

static func rand_int(seed: int, q: int, r: int, purpose: String, minimum: int, maximum: int) -> int:
    if maximum <= minimum:
        return minimum
    var span: int = maximum - minimum + 1
    var hashed: int = _hash_components(seed, [q, r], purpose)
    var index: int = hashed % span
    return minimum + index

static func rand_int_scope(seed: int, scope: Array, purpose: String, minimum: int, maximum: int) -> int:
    if maximum <= minimum:
        return minimum
    var span: int = maximum - minimum + 1
    var hashed: int = _hash_components(seed, scope, purpose)
    var index: int = hashed % span
    return minimum + index

static func rand_bool(seed: int, q: int, r: int, purpose: String, probability: float) -> bool:
    if probability <= 0.0:
        return false
    if probability >= 1.0:
        return true
    var sample: float = rand(seed, q, r, purpose)
    return sample < probability

static func rand_bool_scope(seed: int, scope: Array, purpose: String, probability: float) -> bool:
    if probability <= 0.0:
        return false
    if probability >= 1.0:
        return true
    var sample: float = rand_scope(seed, scope, purpose)
    return sample < probability

static func rand_choice(seed: int, q: int, r: int, purpose: String, options: Array) -> Variant:
    if options.is_empty():
        return null
    var hashed: int = _hash_components(seed, [q, r], purpose)
    var index: int = hashed % options.size()
    return options[index]

static func rand_choice_scope(seed: int, scope: Array, purpose: String, options: Array) -> Variant:
    if options.is_empty():
        return null
    var hashed: int = _hash_components(seed, scope, purpose)
    var index: int = hashed % options.size()
    return options[index]

static func rand_rotation(seed: int, q: int, r: int, purpose: String, steps: int) -> int:
    if steps <= 1:
        return 0
    var hashed: int = _hash_components(seed, [q, r], purpose)
    return hashed % steps

static func rand_variant(seed: int, q: int, r: int, purpose: String, variants: Array[StringName]) -> StringName:
    if variants.is_empty():
        return StringName()
    var hashed: int = _hash_components(seed, [q, r], purpose)
    var index: int = hashed % variants.size()
    return variants[index]

static func _hash_components(seed: int, scope: Array, purpose: String) -> int:
    var values: Array = [seed]
    for entry in scope:
        values.append(entry)
    values.append(String(purpose))
    var raw: int = int(hash(values))
    if raw < 0:
        raw = -raw
    return raw
