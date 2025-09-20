extends Control

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"
const HEX_MAP_CONFIG_SCRIPT := preload("res://mapgen/HexMapConfig.gd")
const LAND_BASE_LEGEND_ID := "land_base"
const LAND_REGION_COUNT_IDS: Array = ["plains", "valley", "hills", "mountains"]

const REGION_LEGEND_ENTRIES: Array = [
    {
        "id": LAND_BASE_LEGEND_ID,
        "color": Color(0.52, 0.74, 0.31),
    },
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

const EDGE_OPTIONS: Array = [
    {
        "id": "east",
        "label_key": "setup.edge.east",
    },
    {
        "id": "north_east",
        "label_key": "setup.edge.north_east",
    },
    {
        "id": "north_west",
        "label_key": "setup.edge.north_west",
    },
    {
        "id": "west",
        "label_key": "setup.edge.west",
    },
    {
        "id": "south_west",
        "label_key": "setup.edge.south_west",
    },
    {
        "id": "south_east",
        "label_key": "setup.edge.south_east",
    },
]

const EDGE_TERRAIN_OPTIONS: Array = [
    {
        "id": "plains",
        "label_key": "setup.edge_terrain.plains",
    },
    {
        "id": "hills",
        "label_key": "setup.edge_terrain.hills",
    },
    {
        "id": "mountains",
        "label_key": "setup.edge_terrain.mountains",
    },
    {
        "id": "sea",
        "label_key": "setup.edge_terrain.sea",
    },
    {
        "id": "lake",
        "label_key": "setup.edge_terrain.lake",
    },
]

const FEATURE_DENSITY_OPTIONS: Array = [
    {
        "id": "none",
        "value": 0.0,
        "label_key": "setup.feature_density.none",
    },
    {
        "id": "low",
        "value": 0.05,
        "label_key": "setup.feature_density.low",
    },
    {
        "id": "medium",
        "value": 0.12,
        "label_key": "setup.feature_density.medium",
    },
    {
        "id": "high",
        "value": 0.2,
        "label_key": "setup.feature_density.high",
    },
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
@onready var layers_row: HBoxContainer = get_node_or_null("Layers")
@onready var params_grid: GridContainer = $HBox/ControlsScroll/Controls/Params

var previous_state: String = Net.state
var _current_config: HexMapConfig
var _updating_controls: bool = false
var _rng := RandomNumberGenerator.new()
var _legend_title_label: Label
var _legend_entries_container: VBoxContainer
var _legend_rows: Dictionary = {}
var _legend_counts: Dictionary = {}
var _edge_controls: Dictionary = {}
var _edge_jitter_label: Label
var _edge_jitter_spinbox: SpinBox
var _feature_density_label: Label
var _feature_density_option: OptionButton

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
    _ensure_edge_controls()
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
    radius_spinbox.min_value = max(1.0, min(6.0, float(HEX_MAP_CONFIG_SCRIPT.DEFAULT_MAP_RADIUS)))
    radius_spinbox.max_value = 48.0

func _ensure_edge_controls() -> void:
    if params_grid == null:
        return
    if _edge_controls.is_empty():
        for option in EDGE_OPTIONS:
            var edge_id := String(option.get("id", ""))
            if edge_id.is_empty():
                continue
            if _edge_controls.has(edge_id):
                continue
            var label := Label.new()
            label.name = "%sEdgeLabel" % edge_id.capitalize()
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            label.size_flags_horizontal = Control.SIZE_FILL
            params_grid.add_child(label)
            var row := HBoxContainer.new()
            row.name = "%sEdgeControls" % edge_id.capitalize()
            row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.alignment = BoxContainer.ALIGNMENT_BEGIN
            var type_button := OptionButton.new()
            type_button.name = "%sEdgeType" % edge_id.capitalize()
            type_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            _populate_edge_type_button(type_button)
            type_button.item_selected.connect(Callable(self, "_on_edge_type_selected").bind(edge_id))
            var width_spin := SpinBox.new()
            width_spin.name = "%sEdgeWidth" % edge_id.capitalize()
            width_spin.min_value = 0.0
            width_spin.max_value = radius_spinbox.max_value
            width_spin.step = 1.0
            width_spin.size_flags_horizontal = Control.SIZE_FILL
            width_spin.value_changed.connect(Callable(self, "_on_edge_width_changed").bind(edge_id))
            row.add_child(type_button)
            row.add_child(width_spin)
            params_grid.add_child(row)
            _edge_controls[edge_id] = {
                "label": label,
                "type": type_button,
                "width": width_spin,
            }
    else:
        for edge_id in _edge_controls.keys():
            var entry: Dictionary = _edge_controls[edge_id]
            var type_button: OptionButton = entry.get("type") as OptionButton
            if type_button != null and type_button.item_count == 0:
                _populate_edge_type_button(type_button)
            var label: Label = entry.get("label") as Label
            if label != null and label.get_parent() == null:
                params_grid.add_child(label)
            var width_spin: SpinBox = entry.get("width") as SpinBox
            if width_spin != null and width_spin.get_parent() == null:
                var row := HBoxContainer.new()
                row.name = "%sEdgeControls" % edge_id.capitalize()
                row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.alignment = BoxContainer.ALIGNMENT_BEGIN
                if type_button != null:
                    row.add_child(type_button)
                row.add_child(width_spin)
                params_grid.add_child(row)

    if _edge_jitter_label == null:
        _edge_jitter_label = Label.new()
        _edge_jitter_label.name = "EdgeJitterLabel"
        _edge_jitter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        _edge_jitter_label.size_flags_horizontal = Control.SIZE_FILL
    if _edge_jitter_label.get_parent() == null:
        params_grid.add_child(_edge_jitter_label)

    if _edge_jitter_spinbox == null:
        _edge_jitter_spinbox = SpinBox.new()
        _edge_jitter_spinbox.name = "EdgeJitter"
        _edge_jitter_spinbox.min_value = 0.0
        _edge_jitter_spinbox.max_value = radius_spinbox.max_value
        _edge_jitter_spinbox.step = 1.0
        _edge_jitter_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _edge_jitter_spinbox.value_changed.connect(Callable(self, "_on_edge_jitter_changed"))
    if _edge_jitter_spinbox.get_parent() == null:
        params_grid.add_child(_edge_jitter_spinbox)

    if _feature_density_label == null:
        _feature_density_label = Label.new()
        _feature_density_label.name = "FeatureDensityLabel"
        _feature_density_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        _feature_density_label.size_flags_horizontal = Control.SIZE_FILL
    if _feature_density_label.get_parent() == null:
        params_grid.add_child(_feature_density_label)

    if _feature_density_option == null:
        _feature_density_option = OptionButton.new()
        _feature_density_option.name = "FeatureDensityOption"
        _feature_density_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _populate_feature_density_options(_feature_density_option)
        _feature_density_option.item_selected.connect(Callable(self, "_on_feature_density_selected"))
    elif _feature_density_option.item_count == 0:
        _populate_feature_density_options(_feature_density_option)
    if _feature_density_option.get_parent() == null:
        params_grid.add_child(_feature_density_option)

    _update_edge_controls_texts()
    _update_edge_width_limits()

func _populate_edge_type_button(button: OptionButton) -> void:
    if button == null:
        return
    button.clear()
    var index := 0
    for option in EDGE_TERRAIN_OPTIONS:
        var option_id := String(option.get("id", ""))
        if option_id.is_empty():
            continue
        var label_key := String(option.get("label_key", ""))
        var text := option_id.capitalize()
        if not label_key.is_empty():
            text = I18N.t(label_key)
        button.add_item(text, index)
        button.set_item_metadata(index, option_id)
        index += 1

func _populate_feature_density_options(option_button: OptionButton) -> void:
    if option_button == null:
        return
    option_button.clear()
    var index := 0
    for option in FEATURE_DENSITY_OPTIONS:
        var option_id := String(option.get("id", ""))
        if option_id.is_empty():
            continue
        var label_key := String(option.get("label_key", ""))
        var text := option_id.capitalize()
        if not label_key.is_empty():
            text = I18N.t(label_key)
        option_button.add_item(text, index)
        option_button.set_item_metadata(index, {
            "id": option_id,
            "value": float(option.get("value", 0.0)),
        })
        index += 1

func _find_edge_option(option_id: String) -> Dictionary:
    for option in EDGE_TERRAIN_OPTIONS:
        if String(option.get("id", "")) == option_id:
            return option
    return {}

func _find_feature_density_option(option_id: String) -> Dictionary:
    for option in FEATURE_DENSITY_OPTIONS:
        if String(option.get("id", "")) == option_id:
            return option
    return {}

func _update_edge_controls_texts() -> void:
    for option in EDGE_OPTIONS:
        var edge_id := String(option.get("id", ""))
        if edge_id.is_empty():
            continue
        var entry: Dictionary = _edge_controls.get(edge_id, {})
        var label: Label = entry.get("label") as Label
        if label != null:
            var label_key := String(option.get("label_key", ""))
            if label_key.is_empty():
                label.text = edge_id.capitalize()
            else:
                label.text = I18N.t(label_key)
        var button: OptionButton = entry.get("type") as OptionButton
        if button != null:
            for index in range(button.item_count):
                var metadata: Variant = button.get_item_metadata(index)
                var terrain_id := String(metadata)
                var terrain_option := _find_edge_option(terrain_id)
                var terrain_label_key := String(terrain_option.get("label_key", ""))
                var text := terrain_id.capitalize()
                if not terrain_label_key.is_empty():
                    text = I18N.t(terrain_label_key)
                button.set_item_text(index, text)
    if _edge_jitter_label != null:
        _edge_jitter_label.text = I18N.t("setup.edge_jitter")
    if _feature_density_label != null:
        _feature_density_label.text = I18N.t("setup.feature_density")
    if _feature_density_option != null:
        for index in range(_feature_density_option.item_count):
            var metadata: Variant = _feature_density_option.get_item_metadata(index)
            var option_id := ""
            if typeof(metadata) == TYPE_DICTIONARY:
                option_id = String(metadata.get("id", ""))
            else:
                option_id = String(metadata)
            var option_data: Dictionary = _find_feature_density_option(option_id)
            var label_key := String(option_data.get("label_key", ""))
            var text := option_id.capitalize()
            if not label_key.is_empty():
                text = I18N.t(label_key)
            _feature_density_option.set_item_text(index, text)

func _apply_edge_settings_to_controls() -> void:
    var settings: Dictionary = {}
    if _current_config != null:
        settings = _current_config.get_all_edge_settings()
    for option in EDGE_OPTIONS:
        var edge_id := String(option.get("id", ""))
        if edge_id.is_empty():
            continue
        var entry: Dictionary = _edge_controls.get(edge_id, {})
        var type_button: OptionButton = entry.get("type") as OptionButton
        var width_spin: SpinBox = entry.get("width") as SpinBox
        var setting: Dictionary = settings.get(edge_id, {})
        var default_terrain := String(HEX_MAP_CONFIG_SCRIPT.DEFAULT_EDGE_TERRAINS.get(edge_id, HEX_MAP_CONFIG_SCRIPT.DEFAULT_EDGE_TYPE))
        var terrain_type := String(setting.get("type", default_terrain))
        var width_value := int(setting.get("width", 0))
        if type_button != null:
            _select_option_by_metadata(type_button, terrain_type)
        if width_spin != null:
            width_spin.value = float(width_value)

func _apply_edge_jitter_to_controls() -> void:
    if _edge_jitter_spinbox == null:
        return
    var jitter_value := 0
    if _current_config != null:
        jitter_value = _current_config.edge_jitter
    _edge_jitter_spinbox.value = float(jitter_value)

func _apply_feature_density_to_controls() -> void:
    if _feature_density_option == null:
        return
    var density_value := 0.0
    if _current_config != null:
        density_value = _current_config.random_feature_density
    _select_feature_density_option(density_value)

func _select_option_by_metadata(button: OptionButton, target_id: String) -> void:
    if button == null:
        return
    var normalized := String(target_id)
    for index in range(button.item_count):
        var metadata: Variant = button.get_item_metadata(index)
        if String(metadata) == normalized:
            button.select(index)
            return
    if button.item_count > 0:
        button.select(0)

func _select_feature_density_option(value: float) -> void:
    if _feature_density_option == null:
        return
    var best_index := -1
    for index in range(_feature_density_option.item_count):
        var metadata: Variant = _feature_density_option.get_item_metadata(index)
        var option_value := 0.0
        if typeof(metadata) == TYPE_DICTIONARY:
            option_value = float(metadata.get("value", 0.0))
        elif typeof(metadata) == TYPE_FLOAT or typeof(metadata) == TYPE_INT:
            option_value = float(metadata)
        if is_equal_approx(option_value, value):
            best_index = index
            break
    if best_index == -1 and _feature_density_option.item_count > 0:
        best_index = 0
    if best_index >= 0:
        _feature_density_option.select(best_index)

func _get_radius_limit() -> int:
    if _current_config != null:
        return max(1, _current_config.map_radius)
    if radius_spinbox != null:
        return max(1, int(round(radius_spinbox.value)))
    return HEX_MAP_CONFIG_SCRIPT.DEFAULT_MAP_RADIUS

func _update_edge_width_limits() -> void:
    var max_radius := _get_radius_limit()
    var previous_update_state := _updating_controls
    _updating_controls = true
    for edge_id in _edge_controls.keys():
        var entry: Dictionary = _edge_controls[edge_id]
        var width_spin: SpinBox = entry.get("width") as SpinBox
        if width_spin == null:
            continue
        width_spin.max_value = float(max_radius)
        if width_spin.value > width_spin.max_value:
            width_spin.value = width_spin.max_value
    if _edge_jitter_spinbox != null:
        _edge_jitter_spinbox.max_value = float(max_radius)
        if _edge_jitter_spinbox.value > _edge_jitter_spinbox.max_value:
            _edge_jitter_spinbox.value = _edge_jitter_spinbox.max_value
    _updating_controls = previous_update_state

func _clamp_edge_widths_to_radius() -> void:
    if _current_config == null:
        return
    var max_radius: int = max(1, _current_config.map_radius)
    for option in EDGE_OPTIONS:
        var edge_id := String(option.get("id", ""))
        if edge_id.is_empty():
            continue
        var setting: Dictionary = _current_config.get_edge_setting(edge_id)
        var width_value := int(setting.get("width", 0))
        var clamped_width := clampi(width_value, 0, max_radius)
        if clamped_width != width_value:
            var terrain_type := String(setting.get("type", "plains"))
            _current_config.set_edge_setting(edge_id, terrain_type, clamped_width)

func _on_edge_type_selected(index: int, edge_name: String) -> void:
    if _updating_controls:
        return
    var entry: Dictionary = _edge_controls.get(edge_name, {})
    var button: OptionButton = entry.get("type") as OptionButton
    if button == null:
        return
    var metadata: Variant = button.get_item_metadata(index)
    var terrain_type := String(metadata)
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    var setting: Dictionary = _current_config.get_edge_setting(edge_name)
    var width_value := int(setting.get("width", 0))
    _current_config.set_edge_setting(edge_name, terrain_type, width_value)
    _regenerate_map()

func _on_edge_width_changed(value: float, edge_name: String) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    var setting: Dictionary = _current_config.get_edge_setting(edge_name)
    var terrain_type := String(setting.get("type", "plains"))
    var width_value := clampi(int(round(value)), 0, _get_radius_limit())
    _current_config.set_edge_setting(edge_name, terrain_type, width_value)
    _regenerate_map()

func _on_edge_jitter_changed(value: float) -> void:
    if _updating_controls:
        return
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.edge_jitter = max(0, int(round(value)))
    _regenerate_map()

func _on_feature_density_selected(index: int) -> void:
    if _updating_controls:
        return
    if _feature_density_option == null:
        return
    var metadata: Variant = _feature_density_option.get_item_metadata(index)
    var selected_value := 0.0
    if typeof(metadata) == TYPE_DICTIONARY:
        selected_value = float(metadata.get("value", 0.0))
    elif typeof(metadata) == TYPE_FLOAT or typeof(metadata) == TYPE_INT:
        selected_value = float(metadata)
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    _current_config.random_feature_density = clampf(selected_value, 0.0, 1.0)
    _regenerate_map()
func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    kingdom_label.text = I18N.t("setup.kingdoms")
    rivers_label.text = I18N.t("setup.rivers")
    radius_label.text = I18N.t("setup.map_radius")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")
    _update_edge_controls_texts()
    _update_legend_texts()

func _apply_config_to_controls() -> void:
    if _current_config == null:
        return
    _updating_controls = true
    seed_spinbox.value = float(_current_config.map_seed)
    kingdom_spinbox.value = float(_current_config.kingdom_count)
    rivers_spinbox.value = float(_current_config.rivers_cap)
    radius_spinbox.value = float(_current_config.map_radius)
    _apply_edge_settings_to_controls()
    _apply_edge_jitter_to_controls()
    _apply_feature_density_to_controls()
    _update_edge_width_limits()
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
    _clamp_edge_widths_to_radius()
    _update_edge_width_limits()
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
    await get_tree().process_frame
    if not is_inside_tree():
        return
    _on_back_pressed()

func _ensure_legend_controls() -> void:
    if legend_container == null:
        return
    legend_container.visible = false
    legend_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var container_min := legend_container.custom_minimum_size
    if container_min.y < 400.0:
        container_min.y = 400.0
        legend_container.custom_minimum_size = container_min
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
            var base_color: Color = entry.get("color", Color.WHITE)
            var button := Button.new()
            button.name = "%sToggle" % entry_id.capitalize()
            button.toggle_mode = true
            button.button_pressed = true
            button.flat = true
            button.focus_mode = Control.FOCUS_NONE
            button.custom_minimum_size = Vector2(0.0, 32.0)
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            var row := HBoxContainer.new()
            row.name = "%sRow" % entry_id.capitalize()
            row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.alignment = BoxContainer.ALIGNMENT_BEGIN
            button.add_child(row)
            var swatch := ColorRect.new()
            swatch.custom_minimum_size = LEGEND_SWATCH_SIZE
            swatch.size_flags_vertical = Control.SIZE_FILL
            swatch.color = base_color
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            var label := Label.new()
            label.name = "%sLabel" % entry_id.capitalize()
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            row.add_child(swatch)
            row.add_child(label)
            _legend_entries_container.add_child(button)
            button.toggled.connect(_on_legend_entry_toggled.bind(entry_id))
            _legend_rows[entry_id] = {
                "label": label,
                "swatch": swatch,
                "button": button,
                "color": base_color,
            }
            _on_legend_entry_toggled(true, entry_id)
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
    var base_total := 0
    if typeof(map_dictionary) == TYPE_DICTIONARY:
        var terrain: Variant = map_dictionary.get("terrain")
        if typeof(terrain) == TYPE_DICTIONARY:
            var regions: Variant = terrain.get("regions")
            if typeof(regions) == TYPE_DICTIONARY:
                var counts: Variant = regions.get("counts")
                if typeof(counts) == TYPE_DICTIONARY:
                    for key in counts.keys():
                        var region_id := String(key)
                        var count_value := int(counts[key])
                        if _legend_counts.has(region_id):
                            _legend_counts[region_id] = count_value
                        if LAND_REGION_COUNT_IDS.has(region_id):
                            base_total += count_value
    if _legend_counts.has(LAND_BASE_LEGEND_ID):
        _legend_counts[LAND_BASE_LEGEND_ID] = base_total
    _update_legend_texts()
    if legend_container != null:
        legend_container.visible = _legend_has_any_counts()

func _legend_has_any_counts() -> bool:
    for value in _legend_counts.values():
        if int(value) > 0:
            return true
    return false

func _on_legend_entry_toggled(enabled: bool, entry_id: String) -> void:
    if map_view != null:
        if entry_id == LAND_BASE_LEGEND_ID:
            map_view.set_land_base_visibility(enabled)
        else:
            map_view.set_region_visibility(entry_id, enabled)
    _update_legend_entry_visual(entry_id)

func _update_legend_entry_visual(entry_id: String) -> void:
    var row_entry: Dictionary = _legend_rows.get(entry_id, {})
    var button: Button = null
    if row_entry.has("button") and row_entry["button"] is Button:
        button = row_entry["button"] as Button
    var swatch: ColorRect = null
    if row_entry.has("swatch") and row_entry["swatch"] is ColorRect:
        swatch = row_entry["swatch"] as ColorRect
    var label: Label = null
    if row_entry.has("label") and row_entry["label"] is Label:
        label = row_entry["label"] as Label
    var base_color: Color = row_entry.get("color", Color.WHITE)
    var is_enabled := true
    if button != null:
        is_enabled = button.button_pressed
    var alpha := 1.0 if is_enabled else 0.5
    if swatch != null:
        var color := base_color
        color.a = alpha
        swatch.color = color
    if label != null:
        label.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_enabled else Color(1.0, 1.0, 1.0, 0.65)

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
        _update_legend_entry_visual(entry_id)
