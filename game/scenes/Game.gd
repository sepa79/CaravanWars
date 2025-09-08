extends Node

const MapGeneratorModule = preload("res://map/MapGenerator.gd")

var map_data: Dictionary

func _ready() -> void:
    var rng_seed := Time.get_ticks_msec()
    var generator := MapGeneratorModule.new(rng_seed)
    map_data = generator.generate()
    print("[Game] Map generated with seed %d" % rng_seed)
    print("[Game] Data: %s" % map_data)
