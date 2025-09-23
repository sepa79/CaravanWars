extends Control
class_name MapDebugScreen

const MAP_VIEW_SCENE: PackedScene = preload("res://ui/MapView.tscn")
const HEX_MAP_CONFIG_SCRIPT: GDScript = preload("res://mapgen/HexMapConfig.gd")
const HEX_MAP_GENERATOR_SCRIPT: GDScript = preload("res://mapgen/HexMapGenerator.gd")
const CONTROL_PANEL_WIDTH: float = 360.0

var _title_label: Label
var _seed_label: Label
var _seed_spinbox: SpinBox
var _random_seed_button: Button
var _regenerate_button: Button
var _back_button: Button
var _info_label: Label
var _map_view: MapView
var _generator: HexMapGenerator
var _config: HexMapConfig
var _current_dataset: MapData
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_setting_seed: bool = false

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    var host_viewport: Viewport = get_viewport()
    if host_viewport != null and not host_viewport.size_changed.is_connected(_on_viewport_resized):
        host_viewport.size_changed.connect(_on_viewport_resized)
    _rng.randomize()
    _build_ui()
    I18N.language_changed.connect(_on_language_changed)
    _create_generator()
    _apply_initial_seed()
    _on_language_changed()
    _regenerate_map()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_back_pressed()

func _build_ui() -> void:
    var map_node: Node = MAP_VIEW_SCENE.instantiate()
    if map_node is MapView:
        _map_view = map_node as MapView
    else:
        _map_view = null
        push_warning("[MapDebugScreen] MapView scene failed to instantiate")
    if _map_view != null:
        _map_view.name = "MapViewport"
        _map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
        _map_view.offset_left = 0.0
        _map_view.offset_top = 0.0
        _map_view.offset_right = 0.0
        _map_view.offset_bottom = 0.0
        _map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
        add_child(_map_view)

    var overlay := Control.new()
    overlay.name = "Overlay"
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.offset_left = 0.0
    overlay.offset_top = 0.0
    overlay.offset_right = 0.0
    overlay.offset_bottom = 0.0
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.z_index = 1
    add_child(overlay)

    var overlay_column := VBoxContainer.new()
    overlay_column.name = "OverlayColumn"
    overlay_column.position = Vector2(16.0, 16.0)
    overlay_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    overlay_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    overlay_column.alignment = BoxContainer.ALIGNMENT_BEGIN
    overlay_column.add_theme_constant_override("separation", 12)
    overlay.add_child(overlay_column)

    var header := HBoxContainer.new()
    header.name = "Header"
    header.custom_minimum_size = Vector2(CONTROL_PANEL_WIDTH, 0.0)
    header.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    header.alignment = BoxContainer.ALIGNMENT_BEGIN
    overlay_column.add_child(header)

    _title_label = Label.new()
    _title_label.name = "Title"
    _title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    header.add_child(_title_label)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(spacer)

    _back_button = Button.new()
    _back_button.name = "Back"
    _back_button.focus_mode = Control.FOCUS_ALL
    _back_button.pressed.connect(_on_back_pressed)
    header.add_child(_back_button)

    var control_frame := PanelContainer.new()
    control_frame.name = "ControlFrame"
    control_frame.custom_minimum_size = Vector2(CONTROL_PANEL_WIDTH, 0.0)
    control_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    control_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    overlay_column.add_child(control_frame)

    var control_margin := MarginContainer.new()
    control_margin.name = "ControlMargin"
    control_margin.add_theme_constant_override("margin_left", 12)
    control_margin.add_theme_constant_override("margin_top", 12)
    control_margin.add_theme_constant_override("margin_right", 12)
    control_margin.add_theme_constant_override("margin_bottom", 12)
    control_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    control_frame.add_child(control_margin)

    var control_panel := VBoxContainer.new()
    control_panel.name = "ControlPanel"
    control_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    control_panel.alignment = BoxContainer.ALIGNMENT_BEGIN
    control_panel.add_theme_constant_override("separation", 12)
    control_margin.add_child(control_panel)

    var controls_row := HBoxContainer.new()
    controls_row.name = "SeedRow"
    controls_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls_row.alignment = BoxContainer.ALIGNMENT_BEGIN
    controls_row.add_theme_constant_override("separation", 12)
    control_panel.add_child(controls_row)

    _seed_label = Label.new()
    _seed_label.name = "SeedLabel"
    _seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    controls_row.add_child(_seed_label)

    _seed_spinbox = SpinBox.new()
    _seed_spinbox.name = "Seed"
    _seed_spinbox.custom_minimum_size = Vector2(160.0, 0.0)
    _seed_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _seed_spinbox.min_value = 1.0
    _seed_spinbox.max_value = 999_999_999.0
    _seed_spinbox.step = 1.0
    _seed_spinbox.value_changed.connect(_on_seed_value_changed)
    controls_row.add_child(_seed_spinbox)

    _random_seed_button = Button.new()
    _random_seed_button.name = "RandomSeed"
    _random_seed_button.focus_mode = Control.FOCUS_ALL
    _random_seed_button.pressed.connect(_on_random_seed_pressed)
    controls_row.add_child(_random_seed_button)

    _regenerate_button = Button.new()
    _regenerate_button.name = "Regenerate"
    _regenerate_button.focus_mode = Control.FOCUS_ALL
    _regenerate_button.pressed.connect(_on_generate_pressed)
    controls_row.add_child(_regenerate_button)

    _info_label = Label.new()
    _info_label.name = "Info"
    _info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    control_panel.add_child(_info_label)

func _create_generator() -> void:
    if HEX_MAP_CONFIG_SCRIPT == null or HEX_MAP_GENERATOR_SCRIPT == null:
        push_warning("[MapDebugScreen] Unable to load map generator scripts")
        return
    _config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    if _config == null:
        push_warning("[MapDebugScreen] Failed to build HexMapConfig")
        return
    _generator = HEX_MAP_GENERATOR_SCRIPT.new(_config) as HexMapGenerator
    if _generator == null:
        push_warning("[MapDebugScreen] Failed to instantiate HexMapGenerator")
        return
    _generator.set_debug_board_enabled(true)

func _apply_initial_seed() -> void:
    if _config == null or _seed_spinbox == null:
        return
    _set_seed_value(max(1, _config.map_seed))

func _on_language_changed() -> void:
    _update_texts()
    _update_info_label()

func _update_texts() -> void:
    if _title_label != null:
        _title_label.text = I18N.t("debug_map.title")
    if _seed_label != null:
        _seed_label.text = I18N.t("setup.seed")
    if _random_seed_button != null:
        _random_seed_button.text = I18N.t("setup.random_seed")
    if _regenerate_button != null:
        _regenerate_button.text = I18N.t("debug_map.regenerate")
    if _back_button != null:
        _back_button.text = I18N.t("menu.back")

func _on_seed_value_changed(_value: float) -> void:
    if _is_setting_seed:
        return
    _regenerate_map()

func _on_random_seed_pressed() -> void:
    var random_seed_value := int(_rng.randi_range(1, 999_999_999))
    _set_seed_value(random_seed_value)
    _regenerate_map()

func _on_generate_pressed() -> void:
    _regenerate_map()

func _set_seed_value(board_seed: int) -> void:
    if _seed_spinbox == null:
        return
    _is_setting_seed = true
    _seed_spinbox.value = float(max(1, board_seed))
    _is_setting_seed = false

func _regenerate_map() -> void:
    if _generator == null or _map_view == null:
        return
    var target_seed: int = max(1, int(round(_seed_spinbox.value)))
    _generator.set_debug_board_seed(target_seed)
    var dataset: MapData = _generator.generate()
    if dataset == null:
        return
    _current_dataset = dataset
    var map_dictionary: Dictionary = {}
    if dataset is MapData:
        map_dictionary = dataset.to_dictionary()
    _map_view.set_map_data(map_dictionary)
    _update_info_label()

func _update_info_label() -> void:
    if _info_label == null:
        return
    var description := I18N.t("debug_map.description")
    var stats_text := ""
    if _current_dataset != null:
        var stats_format := I18N.t("debug_map.grid_stats")
        var debug_data: Dictionary = _current_dataset.terrain_metadata.get("debug_board", {})
        var dimensions: Vector2i = _to_vector2i(debug_data.get("dimensions", Vector2i(_current_dataset.width, _current_dataset.height)))
        var sections: Dictionary = debug_data.get("sections", {})
        var terrain_section: Dictionary = sections.get("terrain_combinations", {})
        var edge_section: Dictionary = sections.get("edge_widths", {})
        var feature_section: Dictionary = sections.get("feature_intensity_modes", {})
        var terrain_rows := _to_vector2i(terrain_section.get("size", Vector2i.ZERO)).y
        var edge_rows := _to_vector2i(edge_section.get("size", Vector2i.ZERO)).y
        var feature_rows := _to_vector2i(feature_section.get("size", Vector2i.ZERO)).y
        stats_text = stats_format.format({
            "width": dimensions.x,
            "height": dimensions.y,
            "terrain_rows": terrain_rows,
            "edge_rows": edge_rows,
            "feature_rows": feature_rows,
        })
    if stats_text.is_empty():
        _info_label.text = description
    else:
        _info_label.text = "%s\n%s" % [description, stats_text]

func _to_vector2i(value: Variant) -> Vector2i:
    if value is Vector2i:
        return value as Vector2i
    if value is Vector2:
        var vector := value as Vector2
        return Vector2i(int(round(vector.x)), int(round(vector.y)))
    if value is Array and value.size() >= 2:
        var array := value as Array
        return Vector2i(int(array[0]), int(array[1]))
    return Vector2i.ZERO

func _on_back_pressed() -> void:
    Net.run_mode = ""
    App.goto_scene("res://scenes/StartMenu.tscn")

func _on_viewport_resized() -> void:
    size = get_viewport_rect().size
