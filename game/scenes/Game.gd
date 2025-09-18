extends Node

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const HexMapDataScript := preload("res://mapgen/HexMapData.gd")

var map_data: HexMapData

func _ready() -> void:
    var used_prepared := true
    map_data = World.take_prepared_map(Net.run_mode)
    if map_data == null:
        used_prepared = false
        var config: HexMapConfig = HexMapConfigScript.new(Time.get_ticks_msec())
        var generator: HexMapGenerator = HexMapGeneratorScript.new(config)
        map_data = generator.generate()
    if not map_data is HexMapDataScript:
        push_warning("[Game] Unexpected map data payload: %s" % [map_data])
        return
    if used_prepared:
        print("[Game] Using prepared %s map with seed %d" % [Net.run_mode, map_data.seed])
    else:
        print("[Game] Hex map pipeline generated on demand with seed %d" % map_data.seed)
