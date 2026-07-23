class_name LocationEconomyConfig
extends RefCounted

var schema_version: int = -1
var profiles_by_location_id: Dictionary[String, Dictionary] = {}
var validation_errors: Array[String] = []


static func load_from_file(resource_path: String, goods_catalog: RefCounted) -> RefCounted:
    var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
    if file == null:
        var missing_config: RefCounted = new()
        missing_config.validation_errors.append("Could not open location economy config file: %s" % resource_path)
        push_error(missing_config.validation_errors[0])
        return missing_config

    var file_text: String = file.get_as_text()
    var parsed_json: Variant = JSON.parse_string(file_text)
    if typeof(parsed_json) != TYPE_DICTIONARY:
        var invalid_config: RefCounted = new()
        invalid_config.validation_errors.append("Location economy config file is not a JSON object: %s" % resource_path)
        push_error(invalid_config.validation_errors[0])
        return invalid_config

    return from_dictionary(parsed_json, goods_catalog, true)


static func from_dictionary(config_dictionary: Dictionary, goods_catalog: RefCounted, emit_errors: bool = true) -> RefCounted:
    var config: RefCounted = new()
    config.schema_version = int(config_dictionary.get("schema_version", -1))
    if config.schema_version != 0:
        config.validation_errors.append("Location economy schema_version must be 0.")

    var profiles_value: Variant = config_dictionary.get("profiles", [])
    if typeof(profiles_value) != TYPE_ARRAY:
        config.validation_errors.append("Location economy profiles must be an array.")
        return config

    var seen_location_ids: Dictionary[String, bool] = {}
    for profile_value: Variant in profiles_value:
        if typeof(profile_value) != TYPE_DICTIONARY:
            config.validation_errors.append("Location economy profile must be an object.")
            continue

        var profile_dictionary: Dictionary = profile_value
        var location_id: String = str(profile_dictionary.get("location_id", ""))
        if location_id.is_empty():
            config.validation_errors.append("Location economy profile has empty location_id.")
            continue
        if seen_location_ids.has(location_id):
            config.validation_errors.append("Duplicate location economy profile: %s." % location_id)
            continue

        seen_location_ids[location_id] = true
        var normalized_profile: Dictionary = _normalize_profile(profile_dictionary)
        _validate_profile(location_id, normalized_profile, goods_catalog, config.validation_errors)
        config.profiles_by_location_id[location_id] = normalized_profile

    if config.profiles_by_location_id.is_empty():
        config.validation_errors.append("Location economy config must define at least one profile.")

    if emit_errors:
        for validation_error: String in config.validation_errors:
            push_error(validation_error)

    return config


func is_valid() -> bool:
    return validation_errors.is_empty()


func has_profile(location_id: String) -> bool:
    return profiles_by_location_id.has(location_id)


func validate_locations(locations_by_id: Dictionary[String, RefCounted]) -> Array[String]:
    var errors: Array[String] = []
    for location_id: String in profiles_by_location_id.keys():
        if not locations_by_id.has(location_id):
            errors.append("Location economy profile references unknown location: %s." % location_id)

    for location_id: String in locations_by_id.keys():
        if not profiles_by_location_id.has(location_id):
            errors.append("Location has no economy profile: %s." % location_id)

    return errors


func apply_to_location(location: RefCounted, full_days: int) -> Dictionary:
    if full_days <= 0:
        return {}
    if not profiles_by_location_id.has(location.location_id):
        return {}

    var profile_dictionary: Dictionary = profiles_by_location_id[location.location_id]
    var production_per_day: Dictionary[String, int] = profile_dictionary.get("production_per_day", {})
    var consumption_per_day: Dictionary[String, int] = profile_dictionary.get("consumption_per_day", {})
    var storage_caps: Dictionary[String, int] = profile_dictionary.get("storage_caps", {})
    var changes: Dictionary[String, int] = {}

    for goods_id: String in consumption_per_day.keys():
        var previous_amount: int = int(location.resources.get(goods_id, 0))
        var consumed_amount: int = consumption_per_day[goods_id] * full_days
        var new_amount: int = maxi(0, previous_amount - consumed_amount)
        location.resources[goods_id] = new_amount
        changes[goods_id] = int(changes.get(goods_id, 0)) + new_amount - previous_amount

    for goods_id: String in production_per_day.keys():
        var previous_amount: int = int(location.resources.get(goods_id, 0))
        var produced_amount: int = production_per_day[goods_id] * full_days
        var capped_amount: int = previous_amount + produced_amount
        if storage_caps.has(goods_id):
            capped_amount = mini(capped_amount, storage_caps[goods_id])
        location.resources[goods_id] = capped_amount
        changes[goods_id] = int(changes.get(goods_id, 0)) + capped_amount - previous_amount

    return _non_zero_changes(changes)


static func _normalize_profile(profile_dictionary: Dictionary) -> Dictionary:
    return {
        "location_id": str(profile_dictionary.get("location_id", "")),
        "production_per_day": _int_dictionary_from_variant(profile_dictionary.get("production_per_day", {})),
        "consumption_per_day": _int_dictionary_from_variant(profile_dictionary.get("consumption_per_day", {})),
        "storage_caps": _int_dictionary_from_variant(profile_dictionary.get("storage_caps", {}))
    }


static func _validate_profile(location_id: String, profile_dictionary: Dictionary, goods_catalog: RefCounted, errors: Array[String]) -> void:
    var production_per_day: Dictionary[String, int] = profile_dictionary.get("production_per_day", {})
    var consumption_per_day: Dictionary[String, int] = profile_dictionary.get("consumption_per_day", {})
    var storage_caps: Dictionary[String, int] = profile_dictionary.get("storage_caps", {})
    var affected_goods_ids: Array[String] = []

    _append_unique_goods_ids(affected_goods_ids, production_per_day)
    _append_unique_goods_ids(affected_goods_ids, consumption_per_day)

    for goods_id: String in affected_goods_ids:
        if not goods_catalog.has_goods(goods_id):
            errors.append("Location economy profile %s references unknown goods id: %s." % [location_id, goods_id])
        if not storage_caps.has(goods_id):
            errors.append("Location economy profile %s is missing storage cap for goods id: %s." % [location_id, goods_id])

    for goods_id: String in production_per_day.keys():
        if production_per_day[goods_id] < 0:
            errors.append("Location economy production must not be negative: %s %s." % [location_id, goods_id])

    for goods_id: String in consumption_per_day.keys():
        if consumption_per_day[goods_id] < 0:
            errors.append("Location economy consumption must not be negative: %s %s." % [location_id, goods_id])

    for goods_id: String in storage_caps.keys():
        if not goods_catalog.has_goods(goods_id):
            errors.append("Location economy cap references unknown goods id: %s %s." % [location_id, goods_id])
        if storage_caps[goods_id] < 0:
            errors.append("Location economy storage cap must not be negative: %s %s." % [location_id, goods_id])


static func _append_unique_goods_ids(goods_ids: Array[String], values: Dictionary[String, int]) -> void:
    for goods_id: String in values.keys():
        if not goods_ids.has(goods_id):
            goods_ids.append(goods_id)


static func _int_dictionary_from_variant(value: Variant) -> Dictionary[String, int]:
    var values: Dictionary[String, int] = {}
    if typeof(value) != TYPE_DICTIONARY:
        return values

    for key: Variant in value.keys():
        values[str(key)] = int(value.get(key))
    return values


static func _non_zero_changes(changes: Dictionary[String, int]) -> Dictionary[String, int]:
    var non_zero_changes: Dictionary[String, int] = {}
    for goods_id: String in changes.keys():
        if changes[goods_id] != 0:
            non_zero_changes[goods_id] = changes[goods_id]
    return non_zero_changes
