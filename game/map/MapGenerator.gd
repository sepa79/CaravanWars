extends RefCounted
class_name MapGenerator

## Parameter container for map generation.
class MapGenParams:
    var seed: int
    var node_count: int
    var city_count: int
    var max_river_count: int

    func _init(seed: int = 0, node_count: int = 2, city_count: int = 3, max_river_count: int = 1) -> void:
        self.seed = seed if seed != 0 else Time.get_ticks_msec()
        self.node_count = node_count
        self.city_count = city_count
        self.max_river_count = max_river_count

var params: MapGenParams
var rng: RandomNumberGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RoadNetworkModule = preload("res://map/RoadNetwork.gd")
const RiverGeneratorModule: Script = preload("res://map/RiverGenerator.gd")

func _init(_params: MapGenParams = MapGenParams.new()) -> void:
    params = _params
    rng = RandomNumberGenerator.new()
    rng.seed = params.seed

func generate() -> Dictionary:
    var map_data: Dictionary = {}
    var city_stage := CityPlacerModule.new(rng)
    var cities := city_stage.place_cities(params.city_count)
    map_data["cities"] = cities

    var road_stage := RoadNetworkModule.new(rng)
    var roads := road_stage.build_roads(cities, params.node_count)
    map_data["roads"] = roads

    var river_stage: RiverGenerator = RiverGeneratorModule.new(rng)
    var rivers: Array = river_stage.generate_rivers(roads, params.max_river_count)
    map_data["rivers"] = rivers

    return map_data
