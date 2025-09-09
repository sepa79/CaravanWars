extends Node

const MapGeneratorModule = preload("res://map/MapGenerator.gd")

var map_data: Dictionary

func _ready() -> void:
    var rng_seed := Time.get_ticks_msec()
    var params := MapGeneratorModule.MapGenParams.new(rng_seed)
    var generator := MapGeneratorModule.new(params)
    map_data = generator.generate()
    print("[Game] Map generated with seed %d" % params.rng_seed)
    print("[Game] Data: %s" % map_data)
