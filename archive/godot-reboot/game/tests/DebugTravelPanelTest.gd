extends SceneTree

const DEBUG_TRAVEL_PANEL_SCRIPT: GDScript = preload("res://debug/DebugTravelPanel.gd")
const LOCAL_GAME_BOOTSTRAP_SCRIPT: GDScript = preload("res://simulation/LocalGameBootstrap.gd")

var _failed: bool = false
var _panel: Control = null


func _initialize() -> void:
    _panel = DEBUG_TRAVEL_PANEL_SCRIPT.new()
    _panel.bind_server(LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server())
    root.add_child(_panel)
    _run_tests.call_deferred()


func _run_tests() -> void:
    _test_initial_panel_state()
    _test_debug_map_modes_separate_truth_from_party_knowledge()
    _test_check_button_reveals_local_routes()
    _test_travel_button_submits_authoritative_command()
    _test_advance_day_button_ticks_simulation()

    if not _failed:
        print("[DebugTravelPanelTest] OK")
    quit(1 if _failed else 0)


func _test_initial_panel_state() -> void:
    _expect(_panel.get_node("location_label").text == "Location: wroclaw", "Expected initial location label to show Wroclaw.")
    _expect(_panel.get_node("travel_label").text == "Travel: idle", "Expected initial travel label to show idle.")
    _expect(_panel.get_node("visible_parties_label").text.contains("wroclaw_supply_party_01"), "Expected Wroclaw supply party visible at start.")
    _expect(_panel.get_node("events_label").text == "Events: none", "Expected empty initial event log label.")
    _expect(_panel.travel_buttons_by_node_id.has("opole"), "Expected Opole travel button from Wroclaw.")
    _expect(_panel.travel_buttons_by_node_id.has("legnica"), "Expected Legnica travel button from Wroclaw.")
    _expect(not _panel.travel_buttons_by_node_id.has("nysa"), "Expected unknown Nysa route to be hidden from debug panel.")
    _expect(_panel.get_node("party_selector").item_count >= 3, "Expected debug party selector to list managed parties.")
    _expect(_panel.get_node("map_mode_selector").item_count == 2, "Expected debug map mode selector to expose Party and Truth modes.")


func _test_debug_map_modes_separate_truth_from_party_knowledge() -> void:
    var canvas: Control = _panel.get_node("debug_map_canvas")
    var model: RefCounted = canvas.model
    _expect(model.map_mode == "party", "Expected initial debug map to use party mode.")
    _expect(model.map_nodes.has("wroclaw"), "Expected party map to show known Wroclaw.")
    _expect(model.map_nodes.has("opole"), "Expected party map to show known Opole.")
    _expect(not model.map_nodes.has("raciborz"), "Expected party map to hide unknown Raciborz.")

    var map_mode_selector: OptionButton = _panel.get_node("map_mode_selector")
    map_mode_selector.item_selected.emit(1)
    model = canvas.model
    _expect(model.map_mode == "truth", "Expected debug map to switch to truth mode.")
    _expect(model.map_nodes.has("raciborz"), "Expected truth map to show Raciborz.")
    _expect(model.map_edges.has("wroclaw_opole"), "Expected truth map to show route edges.")

    map_mode_selector.item_selected.emit(0)
    model = canvas.model
    _expect(model.map_mode == "party", "Expected debug map to switch back to party mode.")


func _test_check_button_reveals_local_routes() -> void:
    var check_button: Button = _panel.get_node("inspect_local_routes_button")
    check_button.pressed.emit()
    _expect(_panel.get_node("last_result_label").text.begins_with("Last result: checked "), "Expected local route check result label.")
    _expect(_panel.get_node("events_label").text.contains("inspected local routes"), "Expected local route inspection event label.")
    _expect(_panel.travel_buttons_by_node_id.has("nysa"), "Expected Nysa route to appear after checking local routes.")


func _test_travel_button_submits_authoritative_command() -> void:
    var opole_button: Button = _panel.travel_buttons_by_node_id.get("opole")
    _expect(opole_button != null, "Expected Opole button to exist before travel.")
    if opole_button == null:
        return

    opole_button.pressed.emit()
    var party_snapshot: Dictionary = _get_party_snapshot()
    _expect(str(party_snapshot.get("travel_state", "")) == "traveling", "Expected party to be traveling after Opole button press.")
    _expect(str(party_snapshot.get("destination_node_id", "")) == "opole", "Expected Opole destination after button press.")
    _expect(_panel.get_node("last_result_label").text == "Last result: accepted travel intent to opole", "Expected accepted command label.")
    _expect(_panel.get_node("events_label").text.contains("started travel"), "Expected travel start event label.")
    _expect(_panel.travel_buttons_by_node_id.is_empty(), "Expected no route buttons while party is traveling.")
    var canvas: Control = _panel.get_node("debug_map_canvas")
    var model: RefCounted = canvas.model
    _expect(model.map_landmarks.has("old_willow_ford"), "Expected party map to include observed Old Willow Ford after starting Wroclaw-Opole travel.")
    _expect(model.map_terrain_areas.has("odra_valley"), "Expected party map to include observed Odra valley after starting Wroclaw-Opole travel.")


func _test_advance_day_button_ticks_simulation() -> void:
    var advance_button: Button = _panel.get_node("advance_day_button")
    advance_button.pressed.emit()
    var after_one_day: Dictionary = _get_party_snapshot()
    _expect(str(after_one_day.get("travel_state", "")) == "traveling", "Expected party to still travel after one day.")
    _expect(float(after_one_day.get("travel_progress_km", 0.0)) > 0.0, "Expected travel progress after one day.")

    advance_button.pressed.emit()
    advance_button.pressed.emit()
    advance_button.pressed.emit()
    var after_four_days: Dictionary = _get_party_snapshot()
    _expect(str(after_four_days.get("travel_state", "")) == "idle", "Expected party to arrive after four days.")
    _expect(str(after_four_days.get("current_node_id", "")) == "opole", "Expected current node to be Opole after arrival.")
    _expect(_panel.get_node("location_label").text == "Location: opole", "Expected location label to refresh after arrival.")
    _expect(_panel.get_node("visible_parties_label").text.contains("merchant_party_01"), "Expected merchant party visible at Opole.")
    _expect(_panel.get_node("events_label").text.contains("arrived at opole"), "Expected arrival event label.")
    _expect(_panel.travel_buttons_by_node_id.has("wroclaw"), "Expected Wroclaw route button after arriving at Opole.")


func _get_party_snapshot() -> Dictionary:
    var snapshot: Dictionary = _panel.server.get_snapshot()
    var parties: Array = snapshot.get("parties", [])
    for party_value: Variant in parties:
        if typeof(party_value) == TYPE_DICTIONARY and str(party_value.get("party_id", "")) == LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID:
            return party_value
    return {}


func _expect(condition: bool, failure_message: String) -> void:
    if condition:
        return
    push_error(failure_message)
    _failed = true
