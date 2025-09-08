extends RefCounted
class_name MapGenerator

var seed: int
var rng: RandomNumberGenerator

const CityPlacer = preload("res://map/CityPlacer.gd")
const RoadNetwork = preload("res://map/RoadNetwork.gd")
const RiverGenerator = preload("res://map/RiverGenerator.gd")

func _init(_seed: int) -> void:
    seed = _seed
    rng = RandomNumberGenerator.new()
    rng.seed = seed

func generate() -> Dictionary:
    var map_data: Dictionary = {}
    var city_stage := CityPlacer.new(rng)
    var cities := city_stage.place_cities()
    map_data["cities"] = cities

    var road_stage := RoadNetwork.new(rng)
    var roads := road_stage.build_roads(cities)
    map_data["roads"] = roads

    var river_stage := RiverGenerator.new(rng)
    var rivers := river_stage.generate_rivers()
    map_data["rivers"] = rivers

    return map_data
