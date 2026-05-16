extends MainLoop

const GAME_SESSION_FACTORY_SCRIPT: GDScript = preload("res://simulation/GameSessionFactory.gd")
const MERCHANT_FOOD_MANAGER_SCRIPT: GDScript = preload("res://simulation/managers/MerchantFoodManager.gd")
const PARTY_STATS_CALCULATOR_SCRIPT: GDScript = preload("res://simulation/PartyStatsCalculator.gd")
const TEST_EVENT_SINK_SCRIPT: GDScript = preload("res://simulation/events/TestSimulationEventSink.gd")

var _is_finished: bool = false
var _failed: bool = false


func _initialize() -> void:
    _test_merchant_moves_food_between_locations()

    if not _failed:
        print("[MerchantAutoplayScenarioTest] OK")
    _is_finished = true


func _process(_delta: float) -> bool:
    if _failed:
        assert(false, "Merchant autoplay scenario test failed.")
    return _is_finished


func _test_merchant_moves_food_between_locations() -> void:
    var server: RefCounted = GAME_SESSION_FACTORY_SCRIPT.create_new_game_server()
    var manager: RefCounted = MERCHANT_FOOD_MANAGER_SCRIPT.new()
    var event_sink: RefCounted = TEST_EVENT_SINK_SCRIPT.new()
    server.add_event_sink(event_sink)
    var merchant: RefCounted = server.state.get_party(GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
    var opole: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.OPOLE_LOCATION_ID)
    var wroclaw: RefCounted = server.state.get_location(GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID)

    merchant.cargo.clear()
    opole.resources["food"] = 140
    wroclaw.resources["food"] = 0
    var initial_wroclaw_food: int = int(wroclaw.resources.get("food", 0))

    for _day_index: int in range(5):
        manager.process(server, GAME_SESSION_FACTORY_SCRIPT.MERCHANT_PARTY_ID)
        server.tick(1.0)
        _expect(_all_location_resources_non_negative(server), "Expected location resources to stay non-negative.")
        _expect(_all_party_cargo_valid(server), "Expected party cargo to stay valid and within capacity.")

    var event_types: Array[String] = _event_types(server)
    _expect(event_types.has("goods_transferred"), "Expected scenario to transfer goods.")
    _expect(event_types.has("party_travel_started"), "Expected scenario to start merchant travel.")
    _expect(event_types.has("party_arrived"), "Expected scenario to complete merchant travel.")
    _expect(event_sink.event_types().has("goods_transferred"), "Expected event sink to observe goods transfer.")
    _expect(event_sink.event_types().has("party_travel_started"), "Expected event sink to observe merchant travel start.")
    _expect(event_sink.event_types().has("party_arrived"), "Expected event sink to observe merchant arrival.")
    _expect(_has_deposit_to_location(server, GAME_SESSION_FACTORY_SCRIPT.WROCLAW_LOCATION_ID), "Expected merchant to deposit food in Wroclaw.")
    _expect(int(wroclaw.resources.get("food", 0)) > initial_wroclaw_food, "Expected Wroclaw to receive food.")
    _expect(merchant.travel_state == "idle", "Expected merchant not to end in invalid travel state.")


func _all_location_resources_non_negative(server: RefCounted) -> bool:
    for location: RefCounted in server.state.locations_by_id.values():
        for goods_id: String in location.resources.keys():
            if location.resources[goods_id] < 0:
                return false
    return true


func _all_party_cargo_valid(server: RefCounted) -> bool:
    for party: RefCounted in server.state.parties_by_id.values():
        var resource_errors: Array[String] = server.goods_catalog.validate_resource_dictionary(party.cargo)
        if not resource_errors.is_empty():
            return false
        if not PARTY_STATS_CALCULATOR_SCRIPT.is_cargo_within_capacity(party.cargo, party.composition, server.goods_catalog, server.cargo_config):
            return false
    return true


func _event_types(server: RefCounted) -> Array[String]:
    var event_types: Array[String] = []
    for event_dictionary: Dictionary in server.get_recent_events(100):
        event_types.append(str(event_dictionary.get("event_type", "")))
    return event_types


func _has_deposit_to_location(server: RefCounted, location_id: String) -> bool:
    for event_dictionary: Dictionary in server.get_recent_events(100):
        if str(event_dictionary.get("event_type", "")) != "goods_transferred":
            continue
        var details: Dictionary = event_dictionary.get("details", {})
        if str(details.get("location_id", "")) == location_id and str(details.get("direction", "")) == "deposit_to_location":
            return true
    return false


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
