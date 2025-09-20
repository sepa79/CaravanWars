extends Node

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"

var map_data: HexMapData

func _ready() -> void:
    var should_auto_quit := _should_auto_quit_after_load()
    if should_auto_quit:
        call_deferred("_ci_quit_after_load")
    var used_prepared := true
    map_data = World.take_prepared_map(Net.run_mode)
    if map_data == null:
        used_prepared = false
        var config: HexMapConfig = HexMapConfig.new()
        var generator: HexMapGenerator = HexMapGenerator.new(config)
        map_data = generator.generate()
    if not map_data is HexMapData:
        push_warning("[Game] Unexpected map data payload: %s" % [map_data])
        return
    if used_prepared:
        print("[Game] Using prepared %s map with seed %d" % [Net.run_mode, map_data.map_seed])
    else:
        print("[Game] Hex map pipeline generated on demand with seed %d" % map_data.map_seed)

func _should_auto_quit_after_load() -> bool:
    return OS.has_environment(CI_AUTO_SINGLEPLAYER_ENV) or OS.has_environment(CI_AUTO_QUIT_ENV)

func _ci_quit_after_load() -> void:
    await get_tree().process_frame
    print("[Game] CI auto quit after load")
    get_tree().quit()
