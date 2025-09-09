extends RefCounted
class_name MapGenerator

## Parameter container for map generation.
class MapGenParams:
    var rng_seed: int
    var city_count: int
    var max_river_count: int
    var min_connections: int
    var max_connections: int
    var crossing_detour_margin: float

    func _init(
        p_rng_seed: int = 0,
        p_city_count: int = 3,
        p_max_river_count: int = 1,
        p_min_connections: int = 1,
        p_max_connections: int = 3,
        p_crossing_detour_margin: float = 5.0
    ) -> void:
        rng_seed = p_rng_seed if p_rng_seed != 0 else Time.get_ticks_msec()
        city_count = p_city_count
        max_river_count = p_max_river_count
        var max_possible: int = max(1, p_city_count - 1)
        min_connections = clamp(p_min_connections, 1, max_possible)
        max_connections = clamp(p_max_connections, 1, max_possible)
        if min_connections > max_connections:
            var tmp: int = min_connections
            min_connections = max_connections
            max_connections = tmp
        crossing_detour_margin = p_crossing_detour_margin

var params: MapGenParams
var rng: RandomNumberGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RoadNetworkModule = preload("res://map/RoadNetwork.gd")
const RiverGeneratorModule: Script = preload("res://map/RiverGenerator.gd")
const RegionGeneratorModule: Script = preload("res://map/RegionGenerator.gd")

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params
    rng = RandomNumberGenerator.new()
    rng.seed = params.rng_seed

func generate() -> Dictionary:
    var map_data: Dictionary = {}
    var city_stage := CityPlacerModule.new(rng)
    var cities := city_stage.place_cities(params.city_count)
    map_data["cities"] = cities

    var region_stage = RegionGeneratorModule.new()
    var regions: Dictionary = region_stage.generate_regions(cities)
    map_data["regions"] = regions

    var road_stage := RoadNetworkModule.new(rng)
    var roads := road_stage.build_roads(
        cities,
        params.min_connections,
        params.max_connections,
        params.crossing_detour_margin
    )
    map_data["roads"] = roads

    var river_stage = RiverGeneratorModule.new(rng)
    var rivers: Array = river_stage.generate_rivers(roads, params.max_river_count)
    map_data["rivers"] = rivers

    return map_data
