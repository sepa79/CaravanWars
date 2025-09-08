extends Node

const MapGenerator = preload("res://map/MapGenerator.gd")

var map_data: Dictionary

func _ready() -> void:
    var seed := Time.get_ticks_msec()
    var generator := MapGenerator.new(seed)
    map_data = generator.generate()
    print("[Game] Map generated with seed %d" % seed)
    print("[Game] Data: %s" % map_data)
