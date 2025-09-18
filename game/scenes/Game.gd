extends Node

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"

const HexMapGeneratorScript := preload("res://mapgen/HexMapGenerator.gd")
const HexMapConfigScript := preload("res://mapgen/HexMapConfig.gd")
const HexMapDataScript := preload("res://mapgen/HexMapData.gd")

var map_data: HexMapData

func _ready() -> void:
    var should_auto_quit := _should_auto_quit_after_load()
    if should_auto_quit:
        call_deferred("_ci_quit_after_load")
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

func _should_auto_quit_after_load() -> bool:
    return OS.has_environment(CI_AUTO_SINGLEPLAYER_ENV) or OS.has_environment(CI_AUTO_QUIT_ENV)

func _ci_quit_after_load() -> void:
    await get_tree().process_frame
    print("[Game] CI auto quit after load")
    get_tree().quit()
