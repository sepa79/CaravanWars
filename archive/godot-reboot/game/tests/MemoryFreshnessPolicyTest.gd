extends MainLoop

const MEMORY_FRESHNESS_POLICY_SCRIPT: GDScript = preload("res://simulation/managers/MemoryFreshnessPolicy.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_recent_goods_source_is_actionable()
    _test_old_goods_source_is_not_actionable()
    _test_missing_observation_day_is_not_actionable()
    _test_day_text_fallback()
    _test_supply_intent_age()

    if not _failed:
        print("[MemoryFreshnessPolicyTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Memory freshness policy test failed.")
    return _is_finished


func _test_recent_goods_source_is_actionable() -> void:
    var entry: Dictionary = {
        "metadata": {
            "occurred_day": 10.0
        }
    }

    _expect(MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_actionable(entry, 20.0), "Expected 10-day-old goods source to be actionable.")
    _expect(not MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_stale(entry, 20.0), "Expected 10-day-old goods source not to be stale.")


func _test_old_goods_source_is_not_actionable() -> void:
    var entry: Dictionary = {
        "metadata": {
            "occurred_day": 1.0
        }
    }

    _expect(not MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_actionable(entry, 200.0), "Expected old goods source not to be actionable.")
    _expect(MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_stale(entry, 200.0), "Expected old goods source to be stale.")


func _test_missing_observation_day_is_not_actionable() -> void:
    var entry: Dictionary = {
        "metadata": {}
    }

    _expect(not MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_actionable(entry, 20.0), "Expected undated goods source not to be actionable.")
    _expect(MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_stale(entry, 20.0), "Expected undated goods source to be stale.")


func _test_day_text_fallback() -> void:
    var entry: Dictionary = {
        "heard_at_time": "day:7.500",
        "metadata": {}
    }

    _expect(MEMORY_FRESHNESS_POLICY_SCRIPT.is_goods_source_actionable(entry, 8.0), "Expected day text fallback to be actionable.")
    _expect(is_equal_approx(MEMORY_FRESHNESS_POLICY_SCRIPT.observed_day_for_entry(entry), 7.5), "Expected day text fallback to parse.")


func _test_supply_intent_age() -> void:
    var recent_entry: Dictionary = {
        "metadata": {
            "occurred_day": 10.0
        }
    }
    var old_entry: Dictionary = {
        "metadata": {
            "occurred_day": 1.0
        }
    }

    _expect(MEMORY_FRESHNESS_POLICY_SCRIPT.is_supply_intent_active(recent_entry, 20.0), "Expected recent supply intent to be active.")
    _expect(not MEMORY_FRESHNESS_POLICY_SCRIPT.is_supply_intent_active(old_entry, 200.0), "Expected old supply intent not to block forever.")


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
