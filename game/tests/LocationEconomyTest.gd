extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const GOODS_CATALOG_SCRIPT: GDScript = preload("res://simulation/GoodsCatalog.gd")
const LOCATION_ECONOMY_CONFIG_SCRIPT: GDScript = preload("res://simulation/LocationEconomyConfig.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_location_economy_config_loads()
    _test_location_economy_tick_changes_resources()
    _test_location_economy_waits_for_full_days()
    _test_location_economy_clamps_consumption_and_storage()
    _test_unknown_goods_profile_is_invalid()

    if not _failed:
        print("[LocationEconomyTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Location economy test failed.")
    return _is_finished


func _test_location_economy_config_loads() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    _expect(server.location_economy_config.is_valid(), "Expected valid location economy config.")
    var location_errors: Array[String] = server.location_economy_config.validate_locations(server.state.locations_by_id)
    _expect(location_errors.is_empty(), "Expected all locations to have economy profiles: %s" % str(location_errors))


func _test_location_economy_tick_changes_resources() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    server.tick(1.0)

    _expect(int(wroclaw.resources.get("food", 0)) == 116, "Expected Wroclaw food consumption after one day.")
    _expect(int(wroclaw.resources.get("coin", 0)) == 305, "Expected Wroclaw coin production after one day.")
    _expect(int(wroclaw.resources.get("tools", 0)) == 1, "Expected Wroclaw tool production after one day.")
    _expect(_has_event_type(server.get_recent_events(10), "location_economy_ticked"), "Expected economy tick event.")


func _test_location_economy_waits_for_full_days() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    server.tick(0.5)
    _expect(int(wroclaw.resources.get("food", 0)) == 120, "Expected no half-day food change.")

    server.tick(0.5)
    _expect(int(wroclaw.resources.get("food", 0)) == 116, "Expected full-day food change after accumulated time.")


func _test_location_economy_clamps_consumption_and_storage() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)
    wroclaw.resources["food"] = 1
    wroclaw.resources["coin"] = 399
    wroclaw.resources["tools"] = 30

    server.tick(1.0)

    _expect(int(wroclaw.resources.get("food", 0)) == 0, "Expected food consumption to clamp at zero.")
    _expect(int(wroclaw.resources.get("coin", 0)) == 400, "Expected coin production to clamp at storage cap.")
    _expect(int(wroclaw.resources.get("tools", 0)) == 30, "Expected tools to stay at storage cap.")


func _test_unknown_goods_profile_is_invalid() -> void:
    var goods_catalog: RefCounted = GOODS_CATALOG_SCRIPT.load_from_file(GAME_SESSION_FACTORY_SCRIPT.DEFAULT_GOODS_CATALOG_PATH)
    var config: RefCounted = LOCATION_ECONOMY_CONFIG_SCRIPT.from_dictionary({
        "schema_version": 0,
        "profiles": [
            {
                "location_id": "test_location",
                "production_per_day": {
                    "missing_goods": 1
                },
                "consumption_per_day": {},
                "storage_caps": {
                    "missing_goods": 10
                }
            }
        ]
    }, goods_catalog, false)

    _expect(not config.is_valid(), "Expected unknown goods profile to be invalid.")


func _has_event_type(events: Array[Dictionary], event_type: String) -> bool:
    for event_dictionary: Dictionary in events:
        if str(event_dictionary.get("event_type", "")) == event_type:
            return true
    return false


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
