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

var previous_state: String = Net.state
var _current_config: HexMapConfig
var _updating_controls: bool = false
var _rng := RandomNumberGenerator.new()
var _legend_title_label: Label
var _legend_entries_container: VBoxContainer
var _legend_rows: Dictionary = {}
var _legend_counts: Dictionary = {}

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
    for name in legacy_names:
        var node := params.get_node_or_null(name)
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

func _apply_config_to_controls() -> void:
    if _current_config == null:
        return
    _updating_controls = true
    seed_spinbox.value = float(_current_config.seed)
    kingdom_spinbox.value = float(_current_config.kingdom_count)
    rivers_spinbox.value = float(_current_config.rivers_cap)
    radius_spinbox.value = float(_current_config.map_radius)
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
    _current_config.seed = int(value)
    _regenerate_map()

func _on_random_seed_pressed() -> void:
    if _current_config == null:
        _current_config = HEX_MAP_CONFIG_SCRIPT.new() as HexMapConfig
    var new_seed := int(_rng.randi_range(1, 999_999_999))
    _current_config.seed = new_seed
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
