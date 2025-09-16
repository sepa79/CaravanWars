extends Node

const MapGeneratorModule = preload("res://mapgen_stub.gd")

var map_data: Dictionary

func _ready() -> void:
    var rng_seed := Time.get_ticks_msec()
    var params := MapGeneratorModule.MapGenParams.new(rng_seed)
    var generator := MapGeneratorModule.new(params)
    map_data = generator.generate()
    var city_count: int = map_data.get("cities", []).size()
    var village_count: int = map_data.get("villages", []).size()
    var road_data: Dictionary = map_data.get("roads", {})
    var road_nodes: int = road_data.get("nodes", {}).size()
    var road_edges: int = road_data.get("edges", {}).size()
    var river_count: int = map_data.get("rivers", []).size()
    print(
        "[Game] Map generated with seed %d (cities=%d, villages=%d, road_nodes=%d, road_edges=%d, rivers=%d)"
        % [
            params.rng_seed,
            city_count,
            village_count,
            road_nodes,
            road_edges,
            river_count,
        ]
    )
