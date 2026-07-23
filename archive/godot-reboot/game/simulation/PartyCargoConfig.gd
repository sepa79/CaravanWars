class_name PartyCargoConfig
extends RefCounted

var schema_version: int = -1
var foot_capacity_bulk: float = 0.0
var horse_capacity_bulk: float = 0.0
var pack_animal_capacity_bulk: float = 0.0
var wagon_capacity_bulk: float = 0.0
var validation_errors: Array[String] = []


static func load_from_file(resource_path: String) -> RefCounted:
    var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
    if file == null:
        var missing_config: RefCounted = new()
        missing_config.validation_errors.append("Could not open party cargo config file: %s" % resource_path)
        push_error(missing_config.validation_errors[0])
        return missing_config

    var file_text: String = file.get_as_text()
    var parsed_json: Variant = JSON.parse_string(file_text)
    if typeof(parsed_json) != TYPE_DICTIONARY:
        var invalid_config: RefCounted = new()
        invalid_config.validation_errors.append("Party cargo config file is not a JSON object: %s" % resource_path)
        push_error(invalid_config.validation_errors[0])
        return invalid_config

    return from_dictionary(parsed_json)


static func from_dictionary(config_dictionary: Dictionary, emit_errors: bool = true) -> RefCounted:
    var config: RefCounted = new()
    config.schema_version = int(config_dictionary.get("schema_version", -1))
    config.foot_capacity_bulk = float(config_dictionary.get("foot_capacity_bulk", 0.0))
    config.horse_capacity_bulk = float(config_dictionary.get("horse_capacity_bulk", 0.0))
    config.pack_animal_capacity_bulk = float(config_dictionary.get("pack_animal_capacity_bulk", 0.0))
    config.wagon_capacity_bulk = float(config_dictionary.get("wagon_capacity_bulk", 0.0))
    config.validation_errors = _validate(config)

    if emit_errors:
        for validation_error: String in config.validation_errors:
            push_error(validation_error)

    return config


func is_valid() -> bool:
    return validation_errors.is_empty()


static func _validate(config: RefCounted) -> Array[String]:
    var errors: Array[String] = []
    if config.schema_version != 0:
        errors.append("Party cargo schema_version must be 0.")
    if config.foot_capacity_bulk < 0.0:
        errors.append("foot_capacity_bulk must not be negative.")
    if config.horse_capacity_bulk < 0.0:
        errors.append("horse_capacity_bulk must not be negative.")
    if config.pack_animal_capacity_bulk < 0.0:
        errors.append("pack_animal_capacity_bulk must not be negative.")
    if config.wagon_capacity_bulk < 0.0:
        errors.append("wagon_capacity_bulk must not be negative.")
    return errors
