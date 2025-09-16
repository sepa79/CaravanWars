extends SceneTree

const MapNodeModule: GDScript = preload("res://mapview/MapNode.gd")
const EdgeModule: GDScript = preload("res://mapview/Edge.gd")
const RegionModule: GDScript = preload("res://mapview/Region.gd")
const CityPlacerModule: GDScript = preload("res://mapgen/CityPlacer.gd")
const RoadNetworkModule: GDScript = preload("res://mapview/RoadNetwork.gd")
const RiverGeneratorModule: GDScript = preload("res://mapgen/RiverGenerator.gd")
const MapGeneratorModule: GDScript = preload("res://mapgen/MapGenerator.gd")

func _init() -> void:
    var generator: RefCounted = MapGeneratorModule.new()
    var data: Dictionary = generator.generate()
    var cities: Array = data.get("cities", [])
    var villages: Array = data.get("villages", [])
    print("[Test] Map generation complete: cities=%d villages=%d" % [
        cities.size(),
        villages.size(),
    ])
    quit()
