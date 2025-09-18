extends RefCounted
class_name MapSettlementStage

const MapGenerationParams := preload("res://map/generation/MapGenerationParams.gd")
const MapGenerationConstants := preload("res://map/generation/MapGenerationConstants.gd")
const MapGenerationShared := preload("res://map/generation/MapGenerationShared.gd")
static func run(state: Dictionary, params: MapGenerationParams) -> Dictionary:
    var size: int = state["map_size"]
    var assignment: PackedInt32Array = state["kingdom_assignment"]
    var slope_map: PackedFloat32Array = state["terrain"]["slope"]
    var sea_mask: PackedByteArray = state["terrain"]["sea_mask"]
    var rainfall: PackedFloat32Array = state["rainfall_map"]
    var temperature: PackedFloat32Array = state["temperature_map"]
    var river_distance: PackedFloat32Array = state["rivers"]["distance_map"]
    var rng: RandomNumberGenerator = state["rng"]

    var sample_step: int = max(1, int(size / 96.0))
    var city_candidates: Array[Dictionary] = []
    for y in range(0, size, sample_step):
        for x in range(0, size, sample_step):
            var index: int = y * size + x
            var kingdom_id: int = assignment[index]
            if kingdom_id < 0:
                continue
            if sea_mask[index] == 1:
                continue
            var slope_value: float = slope_map[index]
            if slope_value > 0.75:
                continue
            var rainfall_value: float = rainfall[index]
            var temp_value: float = temperature[index]
            var river_bonus: float = clamp(
                1.0 - min(river_distance[index] / float(MapGenerationConstants.RIVER_INFLUENCE_RADIUS * 1.8), 1.0),
                0.0,
                1.0
            )
            var border_distance: float = MapGenerationShared.distance_to_border(Vector2(x, y), state, params.map_size)
            var border_bonus: float = 0.0
            if border_distance < 6.0:
                border_bonus = 0.15
            var score: float = (1.0 - slope_value) * 0.5 + rainfall_value * 0.25 + (1.0 - abs(temp_value - 0.6)) * 0.2
            score += river_bonus * 0.3 + border_bonus
            score += rng.randf() * 0.05
            city_candidates.append({
                "position": Vector2(x, y),
                "kingdom_id": kingdom_id,
                "score": score,
                "index": index,
                "is_coast": MapGenerationShared.has_adjacent_sea(x, y, size, sea_mask),
            })

    city_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var cities: Array[Dictionary] = []
    var city_counts: Dictionary = {}
    var city_target_per_kingdom: Dictionary = {}

    for kingdom_id in range(params.kingdom_count):
        city_target_per_kingdom[kingdom_id] = max(1, int(size * size / float(params.kingdom_count * 16000)))
        city_counts[kingdom_id] = 0

    for candidate in city_candidates:
        var candidate_data: Dictionary = candidate
        var kingdom_id: int = candidate_data["kingdom_id"]
        if city_counts[kingdom_id] >= city_target_per_kingdom[kingdom_id]:
            continue
        var position: Vector2 = candidate_data["position"]
        if not _is_far_enough(position, cities, params.city_min_distance):
            continue
        var candidate_score: float = candidate_data["score"]
        var population: int = int(round(6000.0 + candidate_score * 20000.0))
        var city_entry: Dictionary = {
            "type": "city",
            "kingdom_id": kingdom_id,
            "position": position,
            "population": population,
            "port": candidate_data["is_coast"],
            "score": candidate_score,
        }
        cities.append(city_entry)
        city_counts[kingdom_id] = city_counts[kingdom_id] + 1
    if cities.is_empty() and not city_candidates.is_empty():
        var fallback: Dictionary = city_candidates[0]
        cities.append({
            "type": "city",
            "kingdom_id": fallback["kingdom_id"],
            "position": fallback["position"],
            "population": 6000,
            "port": fallback["is_coast"],
            "score": fallback["score"],
        })

    var village_candidates: Array[Dictionary] = city_candidates.duplicate()
    village_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a["score"] > b["score"]
    )

    var villages: Array[Dictionary] = []
    var village_target_per_kingdom: Dictionary = {}
    for kingdom_id in range(params.kingdom_count):
        village_target_per_kingdom[kingdom_id] = max(2, city_counts.get(kingdom_id, 0) * 3)

    for candidate in village_candidates:
        var candidate_data: Dictionary = candidate
        var kingdom_id: int = candidate_data["kingdom_id"]
        if villages.filter(func(v: Dictionary) -> bool:
            return v["kingdom_id"] == kingdom_id
        ).size() >= village_target_per_kingdom[kingdom_id]:
            continue
        var position: Vector2 = candidate_data["position"]
        if not _is_far_enough(position, cities, params.village_min_distance):
            continue
        if not _is_far_enough(position, villages, params.village_min_distance):
            continue
        var candidate_score: float = candidate_data["score"]
        var population: int = int(round(800.0 + candidate_score * 3500.0))
        villages.append({
            "type": "village",
            "kingdom_id": kingdom_id,
            "position": position,
            "population": population,
            "port": candidate_data["is_coast"],
            "score": candidate_score,
        })

    state["city_counts"] = city_counts
    state["cities"] = cities
    state["villages"] = villages

    return {
        "cities": cities,
        "villages": villages,
    }

static func _is_far_enough(position: Vector2, existing: Array[Dictionary], minimum_distance: float) -> bool:
    for entry in existing:
        var other_position: Vector2 = entry["position"]
        if position.distance_to(other_position) < minimum_distance:
            return false
    return true
