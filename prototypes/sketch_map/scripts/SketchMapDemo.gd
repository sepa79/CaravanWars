extends ColorRect

const SketchMapModelScript: GDScript = preload("res://scripts/SketchMapModel.gd")
const SketchMapCanvasScript: GDScript = preload("res://scripts/SketchMapCanvas.gd")

var model: RefCounted
var canvas: Control

var _destinations_box: VBoxContainer = VBoxContainer.new()
var _current_label: Label = Label.new()
var _bought_map_label: Label = Label.new()
var _notes_label: Label = Label.new()


func _ready() -> void:
    model = SketchMapModelScript.new()
    model.load_demo_graph()
    _build_ui()
    _refresh()


func _build_ui() -> void:
    var root: HBoxContainer = HBoxContainer.new()
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    root.offset_left = 0.0
    root.offset_top = 0.0
    root.offset_right = 0.0
    root.offset_bottom = 0.0
    root.add_theme_constant_override("separation", 0)
    add_child(root)

    var sidebar: VBoxContainer = VBoxContainer.new()
    sidebar.custom_minimum_size = Vector2(310, 0)
    sidebar.add_theme_constant_override("separation", 10)
    sidebar.add_theme_constant_override("margin_left", 12)
    sidebar.add_theme_constant_override("margin_top", 12)
    root.add_child(sidebar)

    canvas = SketchMapCanvasScript.new()
    canvas.name = "sketch_map_canvas"
    canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    canvas.bind_model(model)
    root.add_child(canvas)

    var title: Label = Label.new()
    title.text = "Sketch Map Lab"
    title.add_theme_font_size_override("font_size", 20)
    sidebar.add_child(title)

    var subtitle: Label = Label.new()
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.text = "A deliberately inaccurate player-made parchment map. It is built from travel, sight, and rumor; not from full world truth."
    sidebar.add_child(subtitle)

    _current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sidebar.add_child(_current_label)

    var view_section: Label = Label.new()
    view_section.text = "Map view"
    view_section.add_theme_font_size_override("font_size", 15)
    sidebar.add_child(view_section)

    var view_buttons: HBoxContainer = HBoxContainer.new()
    view_buttons.add_theme_constant_override("separation", 6)
    sidebar.add_child(view_buttons)

    var player_view_button: Button = Button.new()
    player_view_button.text = "Player"
    player_view_button.pressed.connect(_on_view_pressed.bind("player"))
    view_buttons.add_child(player_view_button)

    var bought_view_button: Button = Button.new()
    bought_view_button.text = "Bought"
    bought_view_button.pressed.connect(_on_view_pressed.bind("bought"))
    view_buttons.add_child(bought_view_button)

    var compare_view_button: Button = Button.new()
    compare_view_button.text = "Compare"
    compare_view_button.pressed.connect(_on_view_pressed.bind("compare"))
    view_buttons.add_child(compare_view_button)

    var truth_view_button: Button = Button.new()
    truth_view_button.text = "Truth"
    truth_view_button.pressed.connect(_on_view_pressed.bind("truth"))
    view_buttons.add_child(truth_view_button)

    var section: Label = Label.new()
    section.text = "Known travel choices"
    section.add_theme_font_size_override("font_size", 15)
    sidebar.add_child(section)
    sidebar.add_child(_destinations_box)

    var hill_button: Button = Button.new()
    hill_button.text = "Sketch from high ground"
    hill_button.pressed.connect(_on_hill_pressed)
    sidebar.add_child(hill_button)

    var rumor_button: Button = Button.new()
    rumor_button.text = "Add tavern rumor"
    rumor_button.pressed.connect(_on_rumor_pressed)
    sidebar.add_child(rumor_button)

    var buy_map_button: Button = Button.new()
    buy_map_button.text = "Buy regional map"
    buy_map_button.pressed.connect(_on_buy_map_pressed)
    sidebar.add_child(buy_map_button)

    var copy_map_button: Button = Button.new()
    copy_map_button.text = "Copy bought map"
    copy_map_button.pressed.connect(_on_copy_map_pressed)
    sidebar.add_child(copy_map_button)

    var redraw_toggle: CheckBox = CheckBox.new()
    redraw_toggle.text = "Redraw existing marks"
    redraw_toggle.button_pressed = model.redraw_existing_marks
    redraw_toggle.toggled.connect(_on_redraw_toggled)
    sidebar.add_child(redraw_toggle)

    _bought_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sidebar.add_child(_bought_map_label)

    var reset_button: Button = Button.new()
    reset_button.text = "Reset parchment"
    reset_button.pressed.connect(_on_reset_pressed)
    sidebar.add_child(reset_button)

    var notes_title: Label = Label.new()
    notes_title.text = "Map notes"
    notes_title.add_theme_font_size_override("font_size", 15)
    sidebar.add_child(notes_title)

    _notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notes_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sidebar.add_child(_notes_label)


func _refresh() -> void:
    _current_label.text = "Current position: %s" % str(model.nodes_by_id.get(model.current_node_id, {}).get("name", model.current_node_id))
    if model.bought_map_quality >= 0.0:
        _bought_map_label.text = "Bought map quality: %d%%\nCopied into parchment: %d time(s)\nRedraw existing: %s" % [int(round(model.bought_map_quality * 100.0)), int(model.copied_map_count), "on" if model.redraw_existing_marks else "off"]
    else:
        _bought_map_label.text = "No bought map.\nRedraw existing: %s" % ("on" if model.redraw_existing_marks else "off")
    _rebuild_destination_buttons()
    _refresh_notes()
    canvas.queue_redraw()


func _rebuild_destination_buttons() -> void:
    for child: Node in _destinations_box.get_children():
        child.queue_free()

    var destinations: Array[String] = model.get_known_destinations()
    if destinations.is_empty():
        var none_label: Label = Label.new()
        none_label.text = "No known route from here."
        _destinations_box.add_child(none_label)
        return

    for destination_id: String in destinations:
        var destination: Dictionary = model.nodes_by_id.get(destination_id, {})
        var button: Button = Button.new()
        button.text = "Travel to %s" % str(destination.get("name", destination_id))
        button.pressed.connect(_on_travel_pressed.bind(destination_id))
        _destinations_box.add_child(button)


func _refresh_notes() -> void:
    if model.notes.is_empty():
        _notes_label.text = "No notes yet."
        return

    var lines: Array[String] = []
    var start_index: int = max(0, model.notes.size() - 7)
    for i: int in range(start_index, model.notes.size()):
        var note: Dictionary = model.notes[i]
        lines.append("- %s" % str(note.get("text", "")))
    _notes_label.text = "\n".join(lines)


func _on_travel_pressed(destination_id: String) -> void:
    model.travel_to(destination_id)
    _refresh()


func _on_hill_pressed() -> void:
    model.reveal_from_hill()
    _refresh()


func _on_rumor_pressed() -> void:
    model.add_tavern_rumor()
    _refresh()


func _on_buy_map_pressed() -> void:
    model.buy_regional_map()
    canvas.set_view_mode("bought")
    _refresh()


func _on_copy_map_pressed() -> void:
    model.copy_bought_map_to_player()
    canvas.set_view_mode("player")
    _refresh()


func _on_view_pressed(view_mode: String) -> void:
    canvas.set_view_mode(view_mode)
    _refresh()


func _on_redraw_toggled(enabled: bool) -> void:
    model.redraw_existing_marks = enabled
    _refresh()


func _on_reset_pressed() -> void:
    model.load_demo_graph()
    canvas.selected_node_id = ""
    canvas.zoom = 0.92
    canvas.pan = Vector2(80, 70)
    _refresh()
