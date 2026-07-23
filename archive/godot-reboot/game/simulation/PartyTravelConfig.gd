class_name PartyTravelConfig
extends RefCounted

var base_speed_km_per_day: float = 0.0
var horse_speed_bonus_km_per_day: float = 0.0
var wagon_speed_penalty_km_per_day: float = 0.0
var minimum_speed_km_per_day: float = 0.0


static func from_dictionary(config_dictionary: Dictionary) -> RefCounted:
    var config: RefCounted = new()
    config.base_speed_km_per_day = float(config_dictionary.get("base_speed_km_per_day", 0.0))
    config.horse_speed_bonus_km_per_day = float(config_dictionary.get("horse_speed_bonus_km_per_day", 0.0))
    config.wagon_speed_penalty_km_per_day = float(config_dictionary.get("wagon_speed_penalty_km_per_day", 0.0))
    config.minimum_speed_km_per_day = float(config_dictionary.get("minimum_speed_km_per_day", 0.0))
    return config


static func load_from_file(resource_path: String) -> RefCounted:
    var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
    if file == null:
        push_error("Could not open party travel config file: %s" % resource_path)
        return new()

    var file_text: String = file.get_as_text()
    var parsed_json: Variant = JSON.parse_string(file_text)
    if typeof(parsed_json) != TYPE_DICTIONARY:
        push_error("Party travel config file is not a JSON object: %s" % resource_path)
        return new()

    return from_dictionary(parsed_json)
