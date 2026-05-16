class_name GoodsCatalog
extends RefCounted

var schema_version: int = -1
var goods_by_id: Dictionary[String, Dictionary] = {}
var validation_errors: Array[String] = []


static func load_from_file(resource_path: String) -> RefCounted:
    var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
    if file == null:
        var missing_catalog: RefCounted = new()
        missing_catalog.validation_errors.append("Could not open goods catalog file: %s" % resource_path)
        push_error(missing_catalog.validation_errors[0])
        return missing_catalog

    var file_text: String = file.get_as_text()
    var parsed_json: Variant = JSON.parse_string(file_text)
    if typeof(parsed_json) != TYPE_DICTIONARY:
        var invalid_catalog: RefCounted = new()
        invalid_catalog.validation_errors.append("Goods catalog file is not a JSON object: %s" % resource_path)
        push_error(invalid_catalog.validation_errors[0])
        return invalid_catalog

    return from_dictionary(parsed_json)


static func from_dictionary(catalog_dictionary: Dictionary) -> RefCounted:
    var catalog: RefCounted = new()
    catalog.schema_version = int(catalog_dictionary.get("schema_version", -1))

    if catalog.schema_version != 0:
        catalog.validation_errors.append("Goods catalog schema_version must be 0.")

    var goods_value: Variant = catalog_dictionary.get("goods", [])
    if typeof(goods_value) != TYPE_ARRAY:
        catalog.validation_errors.append("Goods catalog goods must be an array.")
        return catalog

    var seen_goods_ids: Dictionary[String, bool] = {}
    for goods_entry_value: Variant in goods_value:
        if typeof(goods_entry_value) != TYPE_DICTIONARY:
            catalog.validation_errors.append("Goods catalog entry must be an object.")
            continue

        var goods_entry: Dictionary = goods_entry_value
        var goods_id: String = str(goods_entry.get("goods_id", ""))
        if goods_id.is_empty():
            catalog.validation_errors.append("Goods catalog entry has empty goods_id.")
            continue
        if seen_goods_ids.has(goods_id):
            catalog.validation_errors.append("Duplicate goods_id: %s." % goods_id)
            continue

        seen_goods_ids[goods_id] = true
        _validate_goods_entry(goods_id, goods_entry, catalog.validation_errors)
        catalog.goods_by_id[goods_id] = goods_entry.duplicate(true)

    if catalog.goods_by_id.is_empty():
        catalog.validation_errors.append("Goods catalog must define at least one goods entry.")

    for validation_error: String in catalog.validation_errors:
        push_error(validation_error)

    return catalog


func is_valid() -> bool:
    return validation_errors.is_empty()


func has_goods(goods_id: String) -> bool:
    return goods_by_id.has(goods_id)


func get_goods(goods_id: String) -> Dictionary:
    if not goods_by_id.has(goods_id):
        return {}
    return goods_by_id[goods_id].duplicate(true)


func validate_resource_dictionary(resources: Dictionary[String, int]) -> Array[String]:
    var errors: Array[String] = []
    for resource_id: String in resources.keys():
        if not has_goods(resource_id):
            errors.append("Unknown goods id in resources: %s." % resource_id)
        if resources[resource_id] < 0:
            errors.append("Resource amount must not be negative: %s." % resource_id)
    return errors


static func _validate_goods_entry(goods_id: String, goods_entry: Dictionary, errors: Array[String]) -> void:
    if str(goods_entry.get("display_name", "")).is_empty():
        errors.append("Goods %s display_name must not be empty." % goods_id)
    if str(goods_entry.get("category", "")).is_empty():
        errors.append("Goods %s category must not be empty." % goods_id)
    if float(goods_entry.get("bulk_per_unit", 0.0)) <= 0.0:
        errors.append("Goods %s bulk_per_unit must be greater than 0." % goods_id)
    if int(goods_entry.get("base_value", -1)) < 0:
        errors.append("Goods %s base_value must not be negative." % goods_id)
    if typeof(goods_entry.get("perishable", false)) != TYPE_BOOL:
        errors.append("Goods %s perishable must be a boolean." % goods_id)
    if typeof(goods_entry.get("tags", [])) != TYPE_ARRAY:
        errors.append("Goods %s tags must be an array." % goods_id)
