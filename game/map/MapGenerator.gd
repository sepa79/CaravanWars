extends RefCounted
class_name MapGenerator

var world_seed: int
var rng: RandomNumberGenerator

const CityPlacerModule = preload("res://map/CityPlacer.gd")
const RoadNetworkModule = preload("res://map/RoadNetwork.gd")
const RiverGeneratorModule = preload("res://map/RiverGenerator.gd")

func _init(_seed: int) -> void:
    world_seed = _seed
    rng = RandomNumberGenerator.new()
    rng.seed = world_seed

func generate() -> Dictionary:
    var map_data: Dictionary = {}
    var city_stage := CityPlacerModule.new(rng)
    var cities := city_stage.place_cities()
    map_data["cities"] = cities

    var road_stage := RoadNetworkModule.new(rng)
    var roads := road_stage.build_roads(cities)
    map_data["roads"] = roads

    var river_stage := RiverGeneratorModule.new(rng)
    var rivers := river_stage.generate_rivers(roads)
    map_data["rivers"] = rivers

    return map_data
