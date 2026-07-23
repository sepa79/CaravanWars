class_name DebugTravelPanel
extends VBoxContainer

const LOCAL_GAME_BOOTSTRAP_SCRIPT: GDScript = preload("res://simulation/LocalGameBootstrap.gd")
const DEBUG_MAP_CANVAS_SCRIPT: GDScript = preload("res://debug/DebugMapCanvas.gd")
const DEBUG_MAP_MODEL_SCRIPT: GDScript = preload("res://debug/DebugMapModel.gd")
const INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/InspectLocalRoutesCommand.gd")
const TRAVEL_INTENT_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/TravelIntentCommand.gd")

var server: RefCounted = null
var party_id: String = LOCAL_GAME_BOOTSTRAP_SCRIPT.PLAYER_PARTY_ID
var map_mode: String = DEBUG_MAP_MODEL_SCRIPT.MODE_PARTY
var last_command_text: String = "No command submitted."
var travel_buttons_by_node_id: Dictionary[String, Button] = {}

var _party_selector: OptionButton = OptionButton.new()
var _map_mode_selector: OptionButton = OptionButton.new()
var _party_label: Label = Label.new()
var _location_label: Label = Label.new()
var _travel_label: Label = Label.new()
var _visible_parties_label: Label = Label.new()
var _composition_label: Label = Label.new()
var _last_result_label: Label = Label.new()
var _events_label: Label = Label.new()
var _route_buttons_box: VBoxContainer = VBoxContainer.new()
var _inspect_local_routes_button: Button = Button.new()
var _advance_day_button: Button = Button.new()
var _debug_map_model: RefCounted = DEBUG_MAP_MODEL_SCRIPT.new()
var _debug_map_canvas: Control = DEBUG_MAP_CANVAS_SCRIPT.new()


func _ready() -> void:
    _build_controls()
    if server == null:
        bind_server(LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server())
    else:
        refresh_from_snapshot()


func bind_server(bound_server: RefCounted) -> void:
    server = bound_server
    if is_inside_tree():
        refresh_from_snapshot()


func refresh_from_snapshot() -> void:
    if server == null:
        return

    _refresh_party_selector()
    _refresh_map_mode_selector()
    var party_snapshot: Dictionary = _get_party_snapshot()
    if party_snapshot.is_empty():
        _party_label.text = "Party: missing"
        _location_label.text = "Location: unknown"
        _travel_label.text = "Travel: unavailable"
        _visible_parties_label.text = "Visible parties: unavailable"
        _composition_label.text = "Composition: unavailable"
        _last_result_label.text = "Last result: %s" % last_command_text
        _events_label.text = "Events: none"
        _clear_route_buttons()
        _refresh_debug_map()
        return

    _party_label.text = "Party: %s (%s)" % [str(party_snapshot.get("party_id", "")), str(party_snapshot.get("party_type", ""))]
    _location_label.text = "Location: %s" % str(party_snapshot.get("current_node_id", ""))
    _travel_label.text = _format_travel_text(party_snapshot)
    _visible_parties_label.text = _format_visible_parties_text()
    _composition_label.text = _format_composition_text(party_snapshot.get("composition", {}))
    _last_result_label.text = "Last result: %s" % last_command_text
    _events_label.text = _format_events_text()
    _rebuild_route_buttons(party_snapshot)
    _refresh_debug_map()


func _build_controls() -> void:
    if _party_label.get_parent() != null:
        return

    _party_selector.name = "party_selector"
    _party_selector.item_selected.connect(_on_party_selected)
    _map_mode_selector.name = "map_mode_selector"
    _map_mode_selector.item_selected.connect(_on_map_mode_selected)
    _party_label.name = "party_label"
    _location_label.name = "location_label"
    _travel_label.name = "travel_label"
    _visible_parties_label.name = "visible_parties_label"
    _composition_label.name = "composition_label"
    _last_result_label.name = "last_result_label"
    _events_label.name = "events_label"
    _route_buttons_box.name = "route_buttons_box"
    _inspect_local_routes_button.name = "inspect_local_routes_button"
    _inspect_local_routes_button.text = "Check local routes"
    _inspect_local_routes_button.pressed.connect(_on_inspect_local_routes_pressed)
    _advance_day_button.name = "advance_day_button"
    _advance_day_button.text = "Advance 1 day"
    _advance_day_button.pressed.connect(_on_advance_day_pressed)
    _debug_map_canvas.name = "debug_map_canvas"
    _debug_map_canvas.custom_minimum_size = Vector2(720, 430)

    add_child(_party_selector)
    add_child(_map_mode_selector)
    add_child(_party_label)
    add_child(_location_label)
    add_child(_travel_label)
    add_child(_visible_parties_label)
    add_child(_composition_label)
    add_child(_last_result_label)
    add_child(_events_label)
    add_child(_inspect_local_routes_button)
    add_child(_route_buttons_box)
    add_child(_advance_day_button)
    add_child(_debug_map_canvas)
    _debug_map_canvas.bind_model(_debug_map_model)


func _refresh_party_selector() -> void:
    var party_ids: Array[String] = _all_party_ids()
    var current_items: Array[String] = []
    for item_index: int in range(0, _party_selector.item_count):
        current_items.append(str(_party_selector.get_item_metadata(item_index)))

    if current_items == party_ids:
        _select_party_item()
        return

    _party_selector.clear()
    for available_party_id: String in party_ids:
        _party_selector.add_item(available_party_id)
        _party_selector.set_item_metadata(_party_selector.item_count - 1, available_party_id)
    _select_party_item()


func _refresh_map_mode_selector() -> void:
    if _map_mode_selector.item_count == 0:
        _map_mode_selector.add_item("Party Map")
        _map_mode_selector.set_item_metadata(0, DEBUG_MAP_MODEL_SCRIPT.MODE_PARTY)
        _map_mode_selector.add_item("Truth Map")
        _map_mode_selector.set_item_metadata(1, DEBUG_MAP_MODEL_SCRIPT.MODE_TRUTH)

    for item_index: int in range(0, _map_mode_selector.item_count):
        if str(_map_mode_selector.get_item_metadata(item_index)) == map_mode:
            _map_mode_selector.select(item_index)
            return


func _select_party_item() -> void:
    for item_index: int in range(0, _party_selector.item_count):
        if str(_party_selector.get_item_metadata(item_index)) == party_id:
            _party_selector.select(item_index)
            return


func _all_party_ids() -> Array[String]:
    var party_ids: Array[String] = []
    var snapshot: Dictionary = server.get_snapshot()
    var parties: Variant = snapshot.get("parties", [])
    if typeof(parties) != TYPE_ARRAY:
        return party_ids

    for party_value: Variant in parties:
        if typeof(party_value) == TYPE_DICTIONARY:
            var available_party_id: String = str(party_value.get("party_id", ""))
            if not available_party_id.is_empty():
                party_ids.append(available_party_id)
    party_ids.sort()
    return party_ids


func _refresh_debug_map() -> void:
    if server == null:
        return

    _debug_map_model.rebuild_from_server(server, party_id, map_mode)
    _debug_map_canvas.queue_redraw()


func _get_party_snapshot() -> Dictionary:
    var snapshot: Dictionary = server.get_client_snapshot(party_id)
    var party: Variant = snapshot.get("party", {})
    if typeof(party) != TYPE_DICTIONARY:
        return {}

    return party


func _format_travel_text(party_snapshot: Dictionary) -> String:
    var travel_state: String = str(party_snapshot.get("travel_state", ""))
    if travel_state != "traveling":
        return "Travel: idle"

    return "Travel: %s -> %s %.1f/%.1f km at %.1f km/day" % [
        str(party_snapshot.get("origin_node_id", "")),
        str(party_snapshot.get("destination_node_id", "")),
        float(party_snapshot.get("travel_progress_km", 0.0)),
        float(party_snapshot.get("travel_distance_km", 0.0)),
        float(party_snapshot.get("travel_speed_km_per_day", 0.0))
    ]


func _format_composition_text(composition_value: Variant) -> String:
    if typeof(composition_value) != TYPE_DICTIONARY:
        return "Composition: unavailable"

    return "Composition: foot=%d horse=%d wagon=%d pack=%d guard=%d" % [
        int(composition_value.get("foot_count", 0)),
        int(composition_value.get("horse_count", 0)),
        int(composition_value.get("wagon_count", 0)),
        int(composition_value.get("pack_animal_count", 0)),
        int(composition_value.get("guard_count", 0))
    ]


func _format_visible_parties_text() -> String:
    var client_snapshot: Dictionary = server.get_client_snapshot(party_id)
    var visible_parties: Variant = client_snapshot.get("visible_parties", [])
    if typeof(visible_parties) != TYPE_ARRAY or visible_parties.is_empty():
        return "Visible parties: none"

    var party_summaries: Array[String] = []
    for party_value: Variant in visible_parties:
        if typeof(party_value) == TYPE_DICTIONARY:
            party_summaries.append("%s (%s, manager=%s)" % [
                str(party_value.get("party_id", "")),
                str(party_value.get("party_type", "")),
                str(party_value.get("manager_actor_id", ""))
            ])

    return "Visible parties: %s" % " | ".join(party_summaries)


func _format_events_text() -> String:
    var client_snapshot: Dictionary = server.get_client_snapshot(party_id)
    var recent_events: Variant = client_snapshot.get("recent_events", [])
    if typeof(recent_events) != TYPE_ARRAY or recent_events.is_empty():
        return "Events: none"

    var event_summaries: Array[String] = []
    for event_value: Variant in recent_events:
        if typeof(event_value) == TYPE_DICTIONARY:
            event_summaries.append(str(event_value.get("summary", "")))

    return "Events: %s" % " | ".join(event_summaries)


func _rebuild_route_buttons(party_snapshot: Dictionary) -> void:
    _clear_route_buttons()

    if str(party_snapshot.get("travel_state", "")) != "idle":
        return

    var destination_node_ids: Array[String] = server.get_known_destination_node_ids_for_party(party_id)

    for destination_node_id: String in destination_node_ids:
        var travel_button: Button = Button.new()
        travel_button.name = "travel_%s" % destination_node_id
        travel_button.text = "Travel to %s" % destination_node_id
        travel_button.pressed.connect(_on_travel_button_pressed.bind(destination_node_id))
        travel_buttons_by_node_id[destination_node_id] = travel_button
        _route_buttons_box.add_child(travel_button)


func _clear_route_buttons() -> void:
    travel_buttons_by_node_id.clear()
    for child: Node in _route_buttons_box.get_children():
        child.queue_free()


func _on_travel_button_pressed(to_node_id: String) -> void:
    var command: RefCounted = TRAVEL_INTENT_COMMAND_SCRIPT.new()
    command.party_id = party_id
    command.destination_node_id = to_node_id
    var result: RefCounted = server.submit_travel_intent(command)
    if result.accepted:
        last_command_text = "accepted travel intent to %s" % to_node_id
    else:
        last_command_text = "rejected %s: %s" % [result.error_code, result.message]
    refresh_from_snapshot()


func _on_inspect_local_routes_pressed() -> void:
    var command: RefCounted = INSPECT_LOCAL_ROUTES_COMMAND_SCRIPT.new()
    command.party_id = party_id
    var result: RefCounted = server.submit_inspect_local_routes(command)
    if result.accepted:
        last_command_text = "checked %d local routes" % int(result.details.get("discovered_edge_count", 0))
    else:
        last_command_text = "rejected %s: %s" % [result.error_code, result.message]
    refresh_from_snapshot()


func _on_advance_day_pressed() -> void:
    server.tick(1.0)
    last_command_text = "advanced 1 day"
    refresh_from_snapshot()


func _on_party_selected(item_index: int) -> void:
    party_id = str(_party_selector.get_item_metadata(item_index))
    last_command_text = "selected party %s" % party_id
    refresh_from_snapshot()


func _on_map_mode_selected(item_index: int) -> void:
    map_mode = str(_map_mode_selector.get_item_metadata(item_index))
    last_command_text = "selected map mode %s" % map_mode
    refresh_from_snapshot()
