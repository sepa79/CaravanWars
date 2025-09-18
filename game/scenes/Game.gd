extends Node

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const HexMapDataScript := preload("res://mapgen/HexMapData.gd")

var map_data: HexMapData

func _ready() -> void:
    var config: HexMapConfig = HexMapConfigScript.new(Time.get_ticks_msec())
    var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
    map_data = generator.generate()
    if not map_data is HexMapDataScript:
        push_warning("[Game] Unexpected map data payload: %s" % [map_data])
    print("[Game] Hex map pipeline ready with seed %d" % map_data.seed)
