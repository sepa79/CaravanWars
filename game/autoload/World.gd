extends Node

var _hex_map_generator_script: GDScript
var _hex_map_config_script: GDScript
var _hex_map_data_script: GDScript

var _prepared_maps: Dictionary = {}
var _prepared_configs: Dictionary = {}

func _get_hex_map_generator_script() -> GDScript:
    if _hex_map_generator_script == null:
        _hex_map_generator_script = load("res://mapgen/HexMapGenerator.gd")
    return _hex_map_generator_script

func _get_hex_map_config_script() -> GDScript:
    if _hex_map_config_script == null:
        _hex_map_config_script = load("res://mapgen/HexMapConfig.gd")
    return _hex_map_config_script

func _get_hex_map_data_script() -> GDScript:
    if _hex_map_data_script == null:
        _hex_map_data_script = load("res://mapgen/HexMapData.gd")
    return _hex_map_data_script

func prepare_map_for_run_mode(run_mode: String, config: Variant = null, force: bool = false) -> void:
    if run_mode.is_empty():
        return
    if not force and _prepared_maps.has(run_mode):
        return
    var config_script := _get_hex_map_config_script()
    var generator_script := _get_hex_map_generator_script()
    if config_script == null or generator_script == null:
        push_warning("[World] Unable to load map generator scripts")
        return
    var chosen_config: Variant
    if config_script != null and config is Object and config.has_method("duplicate_config") and config.get_script() == config_script:
        chosen_config = config.duplicate_config()
    else:
        chosen_config = config_script.new(Time.get_ticks_msec())
    if chosen_config == null:
        push_warning("[World] Failed to build map config for run mode %s" % [run_mode])
        return
    var generator_instance: Variant = generator_script.new(chosen_config)
    if generator_instance == null or not generator_instance.has_method("generate"):
        push_warning("[World] Unable to instantiate HexMapGenerator")
        return
    var map_data: Variant = generator_instance.generate()
    var data_script := _get_hex_map_data_script()
    if data_script != null and (map_data == null or not (map_data is Object) or map_data.get_script() != data_script):
        push_warning("[World] Prepared map payload is not HexMapData: %s" % [map_data])
        return
    _prepared_configs[run_mode] = chosen_config
    _prepared_maps[run_mode] = map_data
    if data_script != null and map_data is Object and map_data.get_script() == data_script:
        print("[World] Prepared %s map with seed %d" % [run_mode, map_data.map_seed])
    else:
        print("[World] Prepared %s map" % run_mode)

func get_prepared_map(run_mode: String) -> Variant:
    var stored: Variant = _prepared_maps.get(run_mode)
    if stored == null:
        return null
    var data_script := _get_hex_map_data_script()
    if data_script != null and (not (stored is Object) or stored.get_script() != data_script):
        return null
    return stored

func take_prepared_map(run_mode: String) -> Variant:
    var stored_map: Variant = get_prepared_map(run_mode)
    if stored_map == null:
        return null
    _prepared_maps.erase(run_mode)
    _prepared_configs.erase(run_mode)
    return stored_map

func get_prepared_config(run_mode: String) -> Variant:
    var stored: Variant = _prepared_configs.get(run_mode)
    if stored == null:
        return null
    var config_script := _get_hex_map_config_script()
    if config_script != null and (not (stored is Object) or stored.get_script() != config_script):
        return null
    return stored

func clear_prepared_map(run_mode: String) -> void:
    _prepared_maps.erase(run_mode)
    _prepared_configs.erase(run_mode)
