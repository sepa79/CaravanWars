class_name MemoryFreshnessPolicy
extends RefCounted

const GOODS_SOURCE_ACTIONABLE_DAYS: float = 14.0
const GOODS_SOURCE_STALE_DAYS: float = 45.0
const SUPPLY_INTENT_ACTIVE_DAYS: float = 45.0


static func is_goods_source_actionable(entry: Dictionary, current_day: float) -> bool:
    var observed_day: float = observed_day_for_entry(entry)
    if observed_day < 0.0:
        return false
    return current_day - observed_day <= GOODS_SOURCE_ACTIONABLE_DAYS


static func is_goods_source_stale(entry: Dictionary, current_day: float) -> bool:
    var observed_day: float = observed_day_for_entry(entry)
    if observed_day < 0.0:
        return true
    return current_day - observed_day > GOODS_SOURCE_STALE_DAYS


static func is_supply_intent_active(entry: Dictionary, current_day: float) -> bool:
    var observed_day: float = observed_day_for_entry(entry)
    if observed_day < 0.0:
        return true
    return current_day - observed_day <= SUPPLY_INTENT_ACTIVE_DAYS


static func observed_day_for_entry(entry: Dictionary) -> float:
    var metadata_value: Variant = entry.get("metadata", {})
    if typeof(metadata_value) == TYPE_DICTIONARY:
        var metadata: Dictionary = metadata_value
        if metadata.has("occurred_day"):
            return float(metadata.get("occurred_day", -1.0))
        if metadata.has("observed_day"):
            return float(metadata.get("observed_day", -1.0))

    if entry.has("heard_at_time"):
        return _day_from_time_text(str(entry.get("heard_at_time", "")))
    if entry.has("occurred_at"):
        return _day_from_time_text(str(entry.get("occurred_at", "")))

    return -1.0


static func _day_from_time_text(time_text: String) -> float:
    if not time_text.begins_with("day:"):
        return -1.0

    var day_text: String = time_text.substr(4)
    if not day_text.is_valid_float():
        return -1.0
    return float(day_text)
