extends Node

const MapGeneratorModule := preload("res://mapgen_stub.gd")

var map_data: Dictionary = {}

func _ready() -> void:
    var params := MapGeneratorModule.MapGenParams.new(Time.get_ticks_msec())
    map_data = MapGeneratorModule.new(params).generate()
    print("[Game] Map stub ready with seed %d" % params.rng_seed)
