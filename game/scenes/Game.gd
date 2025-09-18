extends Node

const HexMapGenerator := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfig := preload("res://mapgen/HexMapConfig.gd")

var map_data: HexMapData

func _ready() -> void:
    var config := HexMapConfig.new(Time.get_ticks_msec())
    var generator := HexMapGenerator.new(config)
    map_data = generator.generate()
    print("[Game] Hex map pipeline ready with seed %d" % map_data.seed)
