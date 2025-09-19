extends Control

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"
const HEX_MAP_CONFIG_SCRIPT := preload("res://mapgen/HexMapConfig.gd")
const REGION_LEGEND_ENTRIES: Array = [
    {
        "id": "plains",
        "color": Color(0.58, 0.75, 0.39),
    },
    {
        "id": "hills",
        "color": Color(0.73, 0.62, 0.39),
    },
    {
        "id": "mountains",
        "color": Color(0.56, 0.56, 0.6),
    },
    {
        "id": "valley",
        "color": Color(0.4, 0.62, 0.35),
    },
    {
        "id": "lake",
        "color": Color(0.29, 0.6, 0.8),
    },
    {
        "id": "sea",
        "color": Color(0.18, 0.36, 0.6),
    },
]
const LEGEND_SWATCH_SIZE: Vector2 = Vector2(18.0, 18.0)
const SIDE_TYPE_PLAINS := "plains"
const SIDE_TYPE_SEA := "sea"
const SIDE_TYPE_MOUNTAINS := "mountains"
const SIDE_DIRECTIONS: Array[String] = [
    "east",
    "northeast",
    "northwest",
    "west",
    "southwest",
    "southeast",
]

@onready var start_button: Button = $HBox/ControlsScroll/Controls/Buttons/Start
@onready var back_button: Button = $HBox/ControlsScroll/Controls/Buttons/Back
@onready var main_ui: Control = $HBox
@onready var map_view: MapView = $HBox/MapRow/MapView
@onready var legend_container: VBoxContainer = $HBox/MapRow/KingdomLegend
@onready var title_label: Label = $HBox/ControlsScroll/Controls/Title
@onready var seed_label: Label = $HBox/ControlsScroll/Controls/Params/SeedLabel
@onready var seed_spinbox: SpinBox = $HBox/ControlsScroll/Controls/Params/SeedRow/Seed
@onready var random_seed_button: Button = $HBox/ControlsScroll/Controls/Params/SeedRow/RandomSeed
@onready var kingdom_label: Label = $HBox/ControlsScroll/Controls/Params/KingdomsLabel
@onready var kingdom_spinbox: SpinBox = $HBox/ControlsScroll/Controls/Params/Kingdoms
@onready var rivers_label: Label = $HBox/ControlsScroll/Controls/Params/RiversLabel
@onready var rivers_spinbox: SpinBox = $HBox/ControlsScroll/Controls/Params/Rivers
@onready var radius_label: Label = $HBox/ControlsScroll/Controls/Params/WidthLabel
@onready var radius_spinbox: SpinBox = $HBox/ControlsScroll/Controls/Params/Width
@onready var params_container: Container = $HBox/ControlsScroll/Controls/Params
@onready var layers_row: HBoxContainer = get_node_or_null("Layers")

var previous_state: String = Net.state
var _current_config: HexMapConfig
var _updating_controls: bool = false
var _rng := RandomNumberGenerator.new()
var _legend_title_label: Label
var _legend_entries_container: VBoxContainer
var _legend_rows: Dictionary = {}
var _legend_counts: Dictionary = {}
var _side_controls_root: VBoxContainer
var _side_section_label: Label
var _side_labels: Array = []
var _side_width_labels: Array = []
var _side_type_options: Array = []
var _side_width_spins: Array = []
var _jitter_label: Label
var _jitter_spinbox: SpinBox

func _ready() -> void:
    _rng.randomize()
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    random_seed_button.pressed.connect(_on_random_seed_pressed)
    seed_spinbox.value_changed.connect(_on_seed_value_changed)
    kingdom_spinbox.value_changed.connect(_on_kingdoms_changed)
    rivers_spinbox.value_changed.connect(_on_rivers_changed)
    radius_spinbox.value_changed.connect(_on_radius_changed)
    _ensure_legend_controls()
    _strip_legacy_controls()
    _configure_param_ranges()
    _ensure_side_controls()
    _update_texts()
    if not Net.run_mode.is_empty():
        World.prepare_map_for_run_mode(Net.run_mode, null, true)
    _load_config_from_world()
    _apply_config_to_controls()
    _refresh_map_view()
    _on_net_state_changed(Net.state)
    if Net.run_mode == "single" and _should_drive_ci_singleplayer():
        await _ci_start_singleplayer_game()

func _strip_legacy_controls() -> void:
    var controls_container := $HBox/ControlsScroll/Controls
    var buttons := controls_container.get_node("Buttons")
    for child in buttons.get_children():
        if child != start_button and child != back_button:
            child.visible = false
    var params := controls_container.get_node("Params")
    var legacy_names := [
        "CitiesLabel",
        "Cities",
        "MinCitySpacingLabel",
        "MinCitySpacing",
        "MaxCitySpacingLabel",
        "MaxCitySpacing",
        "MinConnectionsLabel",
        "MinConnections",
        "MaxConnectionsLabel",
        "MaxConnections",
        "CrossingMarginLabel",
        "CrossingMargin",
        "HeightLabel",
        "Height",
    ]
    for legacy_name in legacy_names:
        var node := params.get_node_or_null(legacy_name)
        if node != null:
            node.visible = false
    if layers_row != null:
        layers_row.visible = false

func _ensure_side_controls() -> void:
    if params_container == null:
        return
    if _side_controls_root != null and is_instance_valid(_side_controls_root):
        return
    _side_labels.clear()
    _side_width_labels.clear()
    _side_type_options.clear()
    _side_width_spins.clear()
    _side_controls_root = VBoxContainer.new()
    _side_controls_root.name = "SideControls"
    _side_controls_root.add_theme_constant_override("separation", 6)
    params_container.add_child(_side_controls_root)
    _side_section_label = Label.new()
    _side_section_label.name = "SideControlsTitle"
    _side_controls_root.add_child(_side_section_label)
    for side_index in range(SIDE_DIRECTIONS.size()):
        var row := HBoxContainer.new()
        row.name = "SideRow%d" % side_index
        row.add_theme_constant_override("separation", 12)
        row.alignment = BoxContainer.ALIGNMENT_BEGIN
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _side_controls_root.add_child(row)

        var label := Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.custom_minimum_size = Vector2(120.0, 0.0)
        row.add_child(label)
        _side_labels.append(label)

        var type_option := OptionButton.new()
        type_option.focus_mode = Control.FOCUS_NONE
        type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var type_modes: Array[String] = [SIDE_TYPE_PLAINS, SIDE_TYPE_SEA, SIDE_TYPE_MOUNTAINS]
        for option_index in range(type_modes.size()):
            var mode: String = type_modes[option_index]
            var item_index: int = type_option.item_count
            type_option.add_item(I18N.t(_side_type_label_key(mode)))
            type_option.set_item_metadata(item_index, mode)
        type_option.item_selected.connect(Callable(self, "_on_side_type_selected").bind(side_index))
        row.add_child(type_option)
        _side_type_options.append(type_option)

        var width_label := Label.new()
        width_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        width_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        width_label.custom_minimum_size = Vector2(110.0, 0.0)
        width_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(width_label)
        _side_width_labels.append(width_label)

        var width_spin := SpinBox.new()
        width_spin.min_value = 0.0
        width_spin.max_value = 12.0
        width_spin.step = 1.0
        width_spin.allow_lesser = false
        width_spin.allow_greater = true
        width_spin.custom_minimum_size = Vector2(72.0, 0.0)
        width_spin.value_changed.connect(Callable(self, "_on_side_width_changed").bind(side_index))
        row.add_child(width_spin)
        _side_width_spins.append(width_spin)

    var jitter_row := HBoxContainer.new()
    jitter_row.name = "SideJitterRow"
    jitter_row.add_theme_constant_override("separation", 8)
    _side_controls_root.add_child(jitter_row)

    _jitter_label = Label.new()
    jitter_row.add_child(_jitter_label)

    _jitter_spinbox = SpinBox.new()
    _jitter_spinbox.min_value = 0.0
    _jitter_spinbox.max_value = 1.0
    _jitter_spinbox.step = 0.05
    _jitter_spinbox.allow_lesser = false
    _jitter_spinbox.allow_greater = false
    _jitter_spinbox.value_changed.connect(Callable(self, "_on_side_jitter_changed"))
    jitter_row.add_child(_jitter_spinbox)

    _update_side_control_texts()

func _configure_param_ranges() -> void:
    seed_spinbox.step = 1.0
    seed_spinbox.min_value = 0.0
    seed_spinbox.max_value = 9999999999.0
    kingdom_spinbox.step = 1.0
    kingdom_spinbox.min_value = 1.0
    kingdom_spinbox.max_value = 12.0
    rivers_spinbox.step = 1.0
    rivers_spinbox.min_value = 0.0
    rivers_spinbox.max_value = 12.0
    radius_spinbox.step = 1.0
    radius_spinbox.min_value = 6.0
    radius_spinbox.max_value = 48.0

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    kingdom_label.text = I18N.t("setup.kingdoms")
    rivers_label.text = I18N.t("setup.rivers")
    radius_label.text = I18N.t("setup.map_radius")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")
    _update_legend_texts()
    _update_side_control_texts()

func _apply_config_to_controls() -> void:
    if _current_config == null:
        return
    _updating_controls = true
    seed_spinbox.value = float(_current_config.map_seed)
    kingdom_spinbox.value = float(_current_config.kingdom_count)
    rivers_spinbox.value = float(_current_config.rivers_cap)
    radius_spinbox.value = float(_current_config.map_radius)
    _apply_side_config_to_controls()
    _updating_controls = false

func _load_config_from_world() -> void:
    var prepared_config: Variant = World.get_prepared_config(Net.run_mode)
    if prepared_config is HexMapConfig:
        var typed_config := prepared_config as HexMapConfig
        _current_config = typed_config.duplicate_config()
    else:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig

func _refresh_map_view() -> void:
    if map_view == null:
        _update_region_legend({})
        return
    var prepared_map: Variant = World.get_prepared_map(Net.run_mode)
    var map_dictionary: Dictionary = {}
    if prepared_map is HexMapData:
        var typed_map := prepared_map as HexMapData
        map_dictionary = typed_map.to_dictionary()
    elif typeof(prepared_map) == TYPE_DICTIONARY:
        map_dictionary = prepared_map
    map_view.set_map_data(map_dictionary)
    _update_region_legend(map_dictionary)
    _sync_side_config_from_map(map_dictionary)

func _regenerate_map() -> void:
    if _current_config == null:
        return
    if Net.run_mode.is_empty():
        return
    World.prepare_map_for_run_mode(Net.run_mode, _current_config, true)
    _load_config_from_world()
    _apply_config_to_controls()
    _refresh_map_view()

func _on_seed_value_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.map_seed = int(value)
    _regenerate_map()

func _on_random_seed_pressed() -> void:
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    var new_seed := int(_rng.randi_range(1, 999_999_999))
    _current_config.map_seed = new_seed
    _apply_config_to_controls()
    _regenerate_map()

func _on_kingdoms_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.kingdom_count = max(1, int(value))
    _regenerate_map()

func _on_rivers_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.rivers_cap = max(0, int(value))
    _regenerate_map()

func _on_radius_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.map_radius = max(1, int(value))
    _regenerate_map()

func _on_side_type_selected(item_index: int, side_index: int) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    if side_index >= _current_config.side_modes.size():
        return
    if side_index >= _side_type_options.size():
        return
    var option: OptionButton = _side_type_options[side_index]
    if option == null:
        return
    var mode: String = String(option.get_item_metadata(item_index))
    if mode.is_empty():
        mode = SIDE_TYPE_PLAINS
    _current_config.side_modes[side_index] = mode
    _regenerate_map()

func _on_side_width_changed(value: float, side_index: int) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    if side_index >= _current_config.side_widths.size():
        return
    var width_value: int = max(0, int(round(value)))
    _current_config.side_widths[side_index] = width_value
    _regenerate_map()

func _on_side_jitter_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.side_jitter = clampf(value, 0.0, 1.0)
    _regenerate_map()

func _on_start_pressed() -> void:
    match Net.run_mode:
        "single":
            Net.start_singleplayer()
        "host":
            Net.start_host()
        _:
            Net.start_singleplayer()

func _on_back_pressed() -> void:
    Net.run_mode = ""
    App.goto_scene("res://scenes/StartMenu.tscn")

func _on_net_state_changed(state: String) -> void:
    if state == Net.STATE_READY:
        App.goto_scene("res://scenes/Game.tscn")
    elif state == Net.STATE_MENU and previous_state != Net.STATE_MENU:
        App.goto_scene("res://scenes/StartMenu.tscn")
    elif state == Net.STATE_MENU:
        main_ui.visible = true
    else:
        main_ui.visible = false
    previous_state = state

func _should_drive_ci_singleplayer() -> bool:
    return OS.has_environment(CI_AUTO_SINGLEPLAYER_ENV) or OS.has_environment(CI_AUTO_QUIT_ENV)

func _ci_start_singleplayer_game() -> void:
    await get_tree().process_frame
    if not is_inside_tree():
        return
    _on_start_pressed()

func _ensure_legend_controls() -> void:
    if legend_container == null:
        return
    legend_container.visible = false
    if _legend_title_label == null:
        _legend_title_label = Label.new()
        _legend_title_label.name = "LegendTitle"
        _legend_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        legend_container.add_child(_legend_title_label)
    if _legend_entries_container == null:
        _legend_entries_container = VBoxContainer.new()
        _legend_entries_container.name = "LegendEntries"
        _legend_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        legend_container.add_child(_legend_entries_container)
    if _legend_rows.is_empty():
        for entry in REGION_LEGEND_ENTRIES:
            var entry_id := String(entry.get("id", ""))
            if entry_id.is_empty():
                continue
            var row := HBoxContainer.new()
            row.name = "%sRow" % entry_id.capitalize()
            row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.alignment = BoxContainer.ALIGNMENT_BEGIN
            var swatch := ColorRect.new()
            swatch.custom_minimum_size = LEGEND_SWATCH_SIZE
            swatch.size_flags_vertical = Control.SIZE_FILL
            swatch.color = entry.get("color", Color.WHITE)
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            var label := Label.new()
            label.name = "%sLabel" % entry_id.capitalize()
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            row.add_child(swatch)
            row.add_child(label)
            _legend_entries_container.add_child(row)
            _legend_rows[entry_id] = {
                "label": label,
                "swatch": swatch,
            }
    for entry in REGION_LEGEND_ENTRIES:
        var entry_id := String(entry.get("id", ""))
        if entry_id.is_empty():
            continue
        _legend_counts[entry_id] = int(_legend_counts.get(entry_id, 0))
    _update_legend_texts()

func _update_region_legend(map_dictionary: Dictionary) -> void:
    for entry in REGION_LEGEND_ENTRIES:
        var entry_id := String(entry.get("id", ""))
        if entry_id.is_empty():
            continue
        _legend_counts[entry_id] = 0
    if typeof(map_dictionary) == TYPE_DICTIONARY:
        var terrain: Variant = map_dictionary.get("terrain")
        if typeof(terrain) == TYPE_DICTIONARY:
            var regions: Variant = terrain.get("regions")
            if typeof(regions) == TYPE_DICTIONARY:
                var counts: Variant = regions.get("counts")
                if typeof(counts) == TYPE_DICTIONARY:
                    for key in counts.keys():
                        var region_id := String(key)
                        if _legend_counts.has(region_id):
                            _legend_counts[region_id] = int(counts[key])
    _update_legend_texts()
    if legend_container != null:
        legend_container.visible = _legend_has_any_counts()

func _legend_has_any_counts() -> bool:
    for value in _legend_counts.values():
        if int(value) > 0:
            return true
    return false

func _update_legend_texts() -> void:
    if legend_container == null:
        return
    if _legend_title_label != null:
        _legend_title_label.text = I18N.t("setup.legend.title")
    var format_string := I18N.t("setup.legend.count_format")
    for entry in REGION_LEGEND_ENTRIES:
        var entry_id := String(entry.get("id", ""))
        if entry_id.is_empty():
            continue
        var label_entry: Dictionary = _legend_rows.get(entry_id, {})
        var label_node: Label = null
        if label_entry.has("label") and label_entry["label"] is Label:
            label_node = label_entry["label"] as Label
        if label_node == null:
            continue
        var localized_name := I18N.t("setup.legend.%s" % entry_id)
        var count_value := int(_legend_counts.get(entry_id, 0))
        label_node.text = format_string.format({
            "name": localized_name,
            "count": count_value,
        })

func _update_side_control_texts() -> void:
    if _side_controls_root == null:
        return
    if _side_section_label != null:
        _side_section_label.text = I18N.t("setup.side.controls")
    for side_index in range(_side_labels.size()):
        var direction_key: String = "setup.side_direction.%s" % SIDE_DIRECTIONS[side_index]
        var label: Label = _side_labels[side_index]
        if label != null:
            label.text = I18N.t(direction_key)
        if side_index < _side_width_labels.size():
            var width_label: Label = _side_width_labels[side_index]
            if width_label != null:
                width_label.text = I18N.t("setup.side.border_width")
        if side_index < _side_type_options.size():
            var option: OptionButton = _side_type_options[side_index]
            if option != null:
                for item_index in range(option.item_count):
                    var mode: String = String(option.get_item_metadata(item_index))
                    option.set_item_text(item_index, I18N.t(_side_type_label_key(mode)))
    if _jitter_label != null:
        _jitter_label.text = I18N.t("setup.side.jitter")

func _sync_side_config_from_map(map_dictionary: Dictionary) -> void:
    if _current_config == null:
        return
    if _updating_controls:
        return
    if typeof(map_dictionary) != TYPE_DICTIONARY:
        return
    var terrain: Variant = map_dictionary.get("terrain")
    if typeof(terrain) != TYPE_DICTIONARY:
        return
    var direction_count: int = SIDE_DIRECTIONS.size()
    if direction_count <= 0:
        return

    var updated_modes: Array[String] = []
    updated_modes.resize(direction_count)
    var updated_widths: Array[int] = []
    updated_widths.resize(direction_count)

    for side_index in range(direction_count):
        var fallback_mode: String = SIDE_TYPE_PLAINS
        if side_index < _current_config.side_modes.size():
            var stored_mode: String = String(_current_config.side_modes[side_index])
            if not stored_mode.is_empty():
                fallback_mode = stored_mode
        updated_modes[side_index] = fallback_mode

        var fallback_width: int = 0
        if side_index < _current_config.side_widths.size():
            fallback_width = max(0, int(_current_config.side_widths[side_index]))
        updated_widths[side_index] = fallback_width

    var sea_sides: Dictionary = {}
    var coastline: Variant = terrain.get("coastline")
    if typeof(coastline) == TYPE_DICTIONARY:
        var selected_sides: Variant = coastline.get("selected_sides")
        var depth_lookup: Dictionary = {}
        if coastline.has("side_depths") and typeof(coastline["side_depths"]) == TYPE_DICTIONARY:
            depth_lookup = coastline["side_depths"]
        var depth_limit: int = int(coastline.get("depth_limit", 0))
        if selected_sides is PackedInt32Array or typeof(selected_sides) == TYPE_ARRAY:
            var iterable: Array = []
            if selected_sides is PackedInt32Array:
                iterable = Array(selected_sides)
            else:
                iterable = selected_sides
            for side_value in iterable:
                var sea_side_index: int = int(side_value)
                if sea_side_index < 0 or sea_side_index >= direction_count:
                    continue
                sea_sides[sea_side_index] = true
                updated_modes[sea_side_index] = SIDE_TYPE_SEA
                var width_value: int = updated_widths[sea_side_index]
                if not depth_lookup.is_empty():
                    width_value = _dictionary_int_lookup(depth_lookup, sea_side_index, width_value)
                elif coastline.has("depth_limit"):
                    width_value = max(width_value, depth_limit)
                updated_widths[sea_side_index] = max(0, width_value)

    var ridge: Variant = terrain.get("ridge")
    if typeof(ridge) == TYPE_DICTIONARY:
        var ridge_sides: Variant = ridge.get("selected_sides")
        var ridge_widths: Dictionary = {}
        if ridge.has("side_widths") and typeof(ridge["side_widths"]) == TYPE_DICTIONARY:
            ridge_widths = ridge["side_widths"]
        if ridge_sides is PackedInt32Array or typeof(ridge_sides) == TYPE_ARRAY:
            var ridge_iterable: Array = []
            if ridge_sides is PackedInt32Array:
                ridge_iterable = Array(ridge_sides)
            else:
                ridge_iterable = ridge_sides
            for side_value in ridge_iterable:
                var ridge_side_index: int = int(side_value)
                if ridge_side_index < 0 or ridge_side_index >= direction_count:
                    continue
                if sea_sides.has(ridge_side_index):
                    continue
                updated_modes[ridge_side_index] = SIDE_TYPE_MOUNTAINS
                var ridge_width: int = updated_widths[ridge_side_index]
                if not ridge_widths.is_empty():
                    ridge_width = _dictionary_int_lookup(ridge_widths, ridge_side_index, ridge_width)
                updated_widths[ridge_side_index] = max(0, ridge_width)

    var jitter_changed: bool = false
    if typeof(coastline) == TYPE_DICTIONARY and coastline.has("jitter"):
        var jitter_value: float = float(coastline.get("jitter", _current_config.side_jitter))
        jitter_value = clampf(jitter_value, 0.0, 1.0)
        if not is_equal_approx(jitter_value, _current_config.side_jitter):
            _current_config.side_jitter = jitter_value
            jitter_changed = true

    var modes_changed: bool = updated_modes.size() != _current_config.side_modes.size()
    if not modes_changed:
        for side_index in range(updated_modes.size()):
            if side_index >= _current_config.side_modes.size():
                modes_changed = true
                break
            if String(_current_config.side_modes[side_index]) != updated_modes[side_index]:
                modes_changed = true
                break

    var widths_changed: bool = updated_widths.size() != _current_config.side_widths.size()
    if not widths_changed:
        for side_index in range(updated_widths.size()):
            if side_index >= _current_config.side_widths.size():
                widths_changed = true
                break
            if int(_current_config.side_widths[side_index]) != updated_widths[side_index]:
                widths_changed = true
                break

    if not modes_changed and not widths_changed and not jitter_changed:
        return

    if modes_changed:
        _current_config.side_modes = updated_modes
    if widths_changed:
        _current_config.side_widths = updated_widths

    var previous_flag: bool = _updating_controls
    _updating_controls = true
    _apply_side_config_to_controls()
    _updating_controls = previous_flag

func _dictionary_int_lookup(source: Dictionary, key: int, default_value: int) -> int:
    if source.has(key):
        return int(source.get(key, default_value))
    var string_key := str(key)
    if source.has(string_key):
        return int(source.get(string_key, default_value))
    return default_value

func _apply_side_config_to_controls() -> void:
    if _current_config == null:
        return
    if _side_type_options.is_empty():
        return
    var mode_count: int = _current_config.side_modes.size()
    var width_count: int = _current_config.side_widths.size()
    for side_index in range(_side_type_options.size()):
        var option: OptionButton = _side_type_options[side_index]
        if option == null:
            continue
        var mode: String = SIDE_TYPE_PLAINS
        if side_index < mode_count:
            mode = String(_current_config.side_modes[side_index])
        var selected_item: int = 0
        for item_index in range(option.item_count):
            if String(option.get_item_metadata(item_index)) == mode:
                selected_item = item_index
                break
        option.select(selected_item)
        if side_index < _side_width_spins.size():
            var spin: SpinBox = _side_width_spins[side_index]
            if spin != null:
                var width_value: int = 0
                if side_index < width_count:
                    width_value = int(_current_config.side_widths[side_index])
                spin.value = float(width_value)
    if _jitter_spinbox != null:
        _jitter_spinbox.value = float(_current_config.side_jitter)

func _side_type_label_key(mode: String) -> String:
    match mode:
        SIDE_TYPE_SEA:
            return "setup.legend.sea"
        SIDE_TYPE_MOUNTAINS:
            return "setup.legend.mountains"
        _:
            return "setup.legend.plains"
