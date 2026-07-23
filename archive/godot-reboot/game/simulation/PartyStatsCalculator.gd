class_name PartyStatsCalculator
extends RefCounted


static func calculate_travel_speed_km_per_day(composition: RefCounted, travel_config: RefCounted) -> float:
    var speed_km_per_day: float = travel_config.base_speed_km_per_day
    speed_km_per_day += float(composition.horse_count) * travel_config.horse_speed_bonus_km_per_day
    speed_km_per_day -= float(composition.wagon_count) * travel_config.wagon_speed_penalty_km_per_day
    return maxf(travel_config.minimum_speed_km_per_day, speed_km_per_day)


static func calculate_cargo_capacity_bulk(composition: RefCounted, cargo_config: RefCounted) -> float:
    var capacity_bulk: float = 0.0
    capacity_bulk += float(composition.foot_count) * cargo_config.foot_capacity_bulk
    capacity_bulk += float(composition.horse_count) * cargo_config.horse_capacity_bulk
    capacity_bulk += float(composition.pack_animal_count) * cargo_config.pack_animal_capacity_bulk
    capacity_bulk += float(composition.wagon_count) * cargo_config.wagon_capacity_bulk
    return capacity_bulk


static func calculate_cargo_used_bulk(cargo: Dictionary[String, int], goods_catalog: RefCounted) -> float:
    var used_bulk: float = 0.0
    for goods_id: String in cargo.keys():
        var goods_entry: Dictionary = goods_catalog.get_goods(goods_id)
        if goods_entry.is_empty():
            continue
        used_bulk += float(cargo[goods_id]) * float(goods_entry.get("bulk_per_unit", 0.0))
    return used_bulk


static func is_cargo_within_capacity(cargo: Dictionary[String, int], composition: RefCounted, goods_catalog: RefCounted, cargo_config: RefCounted) -> bool:
    var used_bulk: float = calculate_cargo_used_bulk(cargo, goods_catalog)
    var capacity_bulk: float = calculate_cargo_capacity_bulk(composition, cargo_config)
    return used_bulk <= capacity_bulk
