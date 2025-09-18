extends Control

const MAP_GENERATOR_SCRIPT_PATH := "res://map/generation/MapGenerator.gd"
const MapGenerationParamsScript := preload("res://map/generation/MapGenerationParams.gd")
const LegendIconButtonScript := preload("res://ui/LegendIconButton.gd")
const MapViewScript := preload("res://ui/MapView.gd")

const REGENERATE_DEBOUNCE_SECONDS := 0.3

const LEGEND_CONFIG := [
    {"layer": "roads", "icon": "road", "label": "setup.legend_roads"},
    {"layer": "rivers", "icon": "river", "label": "setup.legend_rivers"},
    {"layer": "cities", "icon": "city", "label": "setup.legend_cities"},
    {"layer": "villages", "icon": "village", "label": "setup.legend_villages"},
    {"layer": "forts", "icon": "fort", "label": "setup.legend_forts"},
    {"layer": "crossroads", "icon": "crossroad", "label": "setup.legend_crossroads"},
    {"layer": "bridges", "icon": "bridge", "label": "setup.legend_bridges"},
    {"layer": "fords", "icon": "ford", "label": "setup.legend_fords"},
    {"layer": "regions", "icon": "region", "label": "setup.legend_regions"},
]

@onready var start_button: Button = $HBox/ControlsScroll/Controls/Buttons/Start
@onready var back_button: Button = $HBox/ControlsScroll/Controls/Buttons/Back
@onready var main_ui: Control = $HBox
@onready var map_view: MapViewScript = $HBox/MapRow/MapView as MapViewScript
@onready var legend_panel: VBoxContainer = $HBox/MapRow/KingdomLegend

@onready var title_label: Label = $HBox/ControlsScroll/Controls/Title
@onready var seed_label: Label = $HBox/ControlsScroll/Controls/Params/SeedLabel
@onready var seed_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/SeedRow/Seed
@onready var random_seed_button: Button = $HBox/ControlsScroll/Controls/Params/SeedRow/RandomSeed

@onready var terrain_octaves_label: Label = $HBox/ControlsScroll/Controls/Params/CitiesLabel
@onready var terrain_octaves_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/Cities
@onready var terrain_roughness_label: Label = $HBox/ControlsScroll/Controls/Params/MinCitySpacingLabel
@onready var terrain_roughness_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/MinCitySpacing
@onready var mountain_scale_label: Label = $HBox/ControlsScroll/Controls/Params/MaxCitySpacingLabel
@onready var mountain_scale_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/MaxCitySpacing
@onready var sea_level_label: Label = $HBox/ControlsScroll/Controls/Params/RiversLabel
@onready var sea_level_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/Rivers
@onready var kingdoms_label: Label = $HBox/ControlsScroll/Controls/Params/KingdomsLabel
@onready var kingdoms_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/Kingdoms
@onready var road_aggressiveness_label: Label = $HBox/ControlsScroll/Controls/Params/MinConnectionsLabel
@onready var road_aggressiveness_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/MinConnections
@onready var fort_cap_label: Label = $HBox/ControlsScroll/Controls/Params/MaxConnectionsLabel
@onready var fort_cap_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/MaxConnections
@onready var fort_spacing_label: Label = $HBox/ControlsScroll/Controls/Params/CrossingMarginLabel
@onready var fort_spacing_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/CrossingMargin
@onready var map_size_label: Label = $HBox/ControlsScroll/Controls/Params/WidthLabel
@onready var map_size_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/Width
@onready var erosion_label: Label = $HBox/ControlsScroll/Controls/Params/HeightLabel
@onready var erosion_spin: SpinBox = $HBox/ControlsScroll/Controls/Params/Height

@onready var show_roads_checkbox: CheckBox = $Layers/ShowRoads
@onready var show_rivers_checkbox: CheckBox = $Layers/ShowRivers
@onready var show_cities_checkbox: CheckBox = $Layers/ShowCities
@onready var show_crossings_checkbox: CheckBox = $Layers/ShowCrossings
@onready var show_regions_checkbox: CheckBox = $Layers/ShowRegions
@onready var show_fertility_checkbox: CheckBox = $Layers/ShowFertility
@onready var show_roughness_checkbox: CheckBox = $Layers/ShowRoughness

var previous_state: String = Net.state
var _regeneration_pending: bool = false
var _regeneration_timer: Timer
var _syncing_layers: bool = false
var _legend_buttons: Dictionary = {}
var _layer_checkboxes: Dictionary = {}
var _legend_header_label: Label
var _legend_button_container: VBoxContainer
var _kingdom_header_label: Label
var _kingdom_container: VBoxContainer
var _last_map_data: Dictionary = {}
var _ui_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    _ui_rng.randomize()
    _initialize_regeneration_timer()
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    random_seed_button.pressed.connect(_on_random_seed_pressed)
    _configure_controls()
    _setup_layer_toggles()
    _setup_legend_panel()
    _connect_parameter_inputs()
    _update_texts()
    _apply_initial_layer_state()
    _schedule_regenerate()
    _on_net_state_changed(Net.state)

func _configure_controls() -> void:
    seed_spin.min_value = 0
    seed_spin.max_value = 1_000_000_000
    seed_spin.step = 1
    seed_spin.value = 12345

    map_size_spin.min_value = 256
    map_size_spin.max_value = 4096
    map_size_spin.step = 64
    map_size_spin.value = 256
    if OS.has_environment("MAP_SMOKE_TEST"):
        map_size_spin.value = map_size_spin.min_value

    kingdoms_spin.min_value = 1
    kingdoms_spin.max_value = 12
    kingdoms_spin.step = 1
    kingdoms_spin.value = 3

    sea_level_spin.min_value = 0.05
    sea_level_spin.max_value = 0.95
    sea_level_spin.step = 0.01
    sea_level_spin.value = 0.32

    terrain_octaves_spin.min_value = 1
    terrain_octaves_spin.max_value = 8
    terrain_octaves_spin.step = 1
    terrain_octaves_spin.value = 6

    terrain_roughness_spin.min_value = 0.0
    terrain_roughness_spin.max_value = 1.0
    terrain_roughness_spin.step = 0.01
    terrain_roughness_spin.value = 0.5

    mountain_scale_spin.min_value = 0.0
    mountain_scale_spin.max_value = 1.5
    mountain_scale_spin.step = 0.05
    mountain_scale_spin.value = 0.8

    erosion_spin.min_value = 0.0
    erosion_spin.max_value = 1.0
    erosion_spin.step = 0.05
    erosion_spin.value = 0.1

    road_aggressiveness_spin.min_value = 0.0
    road_aggressiveness_spin.max_value = 1.0
    road_aggressiveness_spin.step = 0.05
    road_aggressiveness_spin.value = 0.25

    fort_cap_spin.min_value = 0
    fort_cap_spin.max_value = 200
    fort_cap_spin.step = 1
    fort_cap_spin.value = 24

    fort_spacing_spin.min_value = 20
    fort_spacing_spin.max_value = 600
    fort_spacing_spin.step = 5
    fort_spacing_spin.value = 150

func _connect_parameter_inputs() -> void:
    var spin_controls: Array[SpinBox] = [
        seed_spin,
        map_size_spin,
        kingdoms_spin,
        sea_level_spin,
        terrain_octaves_spin,
        terrain_roughness_spin,
        mountain_scale_spin,
        erosion_spin,
        road_aggressiveness_spin,
        fort_cap_spin,
        fort_spacing_spin,
    ]
    for spin in spin_controls:
        spin.value_changed.connect(_on_parameter_changed)

func _initialize_regeneration_timer() -> void:
    _regeneration_timer = Timer.new()
    _regeneration_timer.one_shot = true
    _regeneration_timer.wait_time = REGENERATE_DEBOUNCE_SECONDS
    add_child(_regeneration_timer)
    _regeneration_timer.timeout.connect(_on_regeneration_timer_timeout)

func _setup_layer_toggles() -> void:
    _layer_checkboxes = {
        "roads": show_roads_checkbox,
        "rivers": show_rivers_checkbox,
        "cities": show_cities_checkbox,
        "crossroads": show_crossings_checkbox,
        "regions": show_regions_checkbox,
        "fertility": show_fertility_checkbox,
        "roughness": show_roughness_checkbox,
    }
    for layer_key in _layer_checkboxes.keys():
        var checkbox: CheckBox = _layer_checkboxes[layer_key]
        var captured_layer: String = String(layer_key)
        checkbox.toggled.connect(func(pressed: bool) -> void:
            _on_layer_checkbox_toggled(captured_layer, pressed)
        )

func _setup_legend_panel() -> void:
    for child in legend_panel.get_children():
        child.queue_free()
    _legend_header_label = Label.new()
    legend_panel.add_child(_legend_header_label)
    _legend_button_container = VBoxContainer.new()
    _legend_button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    legend_panel.add_child(_legend_button_container)
    _kingdom_header_label = Label.new()
    legend_panel.add_child(_kingdom_header_label)
    _kingdom_container = VBoxContainer.new()
    _kingdom_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    legend_panel.add_child(_kingdom_container)
    _build_legend_buttons()

func _build_legend_buttons() -> void:
    _legend_buttons.clear()
    for child in _legend_button_container.get_children():
        child.queue_free()
    for entry in LEGEND_CONFIG:
        var layer: String = String(entry.get("layer", ""))
        if layer.is_empty():
            continue
        var button := LegendIconButtonScript.new()
        button.icon_type = entry.get("icon", "")
        var pressed := true
        if _layer_checkboxes.has(layer):
            var checkbox: CheckBox = _layer_checkboxes[layer]
            pressed = checkbox.button_pressed
        button.set_pressed_no_signal(pressed)
        button.queue_redraw()
        button.text = I18N.t(entry.get("label", ""))
        var captured_layer: String = layer
        button.toggled.connect(func(value: bool) -> void:
            _on_legend_button_toggled(captured_layer, value)
        )
        _legend_button_container.add_child(button)
        _legend_buttons[layer] = button

func _apply_initial_layer_state() -> void:
    _syncing_layers = true
    for layer_key in _legend_buttons.keys():
        var button: LegendIconButton = _legend_buttons[layer_key]
        map_view.set_layer_visible(layer_key, button.button_pressed)
        if _layer_checkboxes.has(layer_key):
            var checkbox: CheckBox = _layer_checkboxes[layer_key]
            checkbox.set_pressed_no_signal(button.button_pressed)
    for layer_key in _layer_checkboxes.keys():
        if _legend_buttons.has(layer_key):
            continue
        var checkbox: CheckBox = _layer_checkboxes[layer_key]
        map_view.set_layer_visible(layer_key, checkbox.button_pressed)
    _syncing_layers = false
    map_view.queue_redraw()

func _on_parameter_changed(_value: float) -> void:
    _schedule_regenerate()

func _on_random_seed_pressed() -> void:
    var new_seed := _ui_rng.randi_range(0, 1_000_000_000)
    seed_spin.value = new_seed
    _schedule_regenerate()

func _on_layer_checkbox_toggled(layer: String, pressed: bool) -> void:
    if _syncing_layers:
        return
    _syncing_layers = true
    map_view.set_layer_visible(layer, pressed)
    if _legend_buttons.has(layer):
        var button: LegendIconButton = _legend_buttons[layer]
        button.set_pressed_no_signal(pressed)
        button.queue_redraw()
    _syncing_layers = false

func _on_legend_button_toggled(layer: String, pressed: bool) -> void:
    if _syncing_layers:
        return
    _syncing_layers = true
    map_view.set_layer_visible(layer, pressed)
    if _layer_checkboxes.has(layer):
        var checkbox: CheckBox = _layer_checkboxes[layer]
        checkbox.set_pressed_no_signal(pressed)
    _syncing_layers = false

func _schedule_regenerate() -> void:
    if _regeneration_timer == null:
        _regenerate_map()
        return
    _regeneration_pending = true
    _regeneration_timer.start()

func _on_regeneration_timer_timeout() -> void:
    _regenerate_map()

func _regenerate_map() -> void:
    _regeneration_pending = false
    var generation_params := _build_generation_params()
    if OS.has_environment("MAP_SMOKE_TEST"):
        print("[MapSetup] Generating map with size %d" % generation_params.map_size)
    var generator_script := load(MAP_GENERATOR_SCRIPT_PATH) as Script
    if generator_script == null:
        push_error("Failed to load MapGenerator script from %s." % MAP_GENERATOR_SCRIPT_PATH)
        _last_map_data = {}
        return
    var generator_object: Object = generator_script.new()
    if generator_object == null:
        push_error("Failed to instantiate MapGenerator script.")
        _last_map_data = {}
        return
    if not generator_object.has_method("generate"):
        push_error("MapGenerator instance missing generate().")
        _last_map_data = {}
        return
    generator_object.set("params", generation_params)
    var generated_variant: Variant = generator_object.call("generate")
    if generated_variant is Dictionary:
        _last_map_data = generated_variant
    else:
        push_error("MapGenerator.generate() did not return a Dictionary.")
        _last_map_data = {}
        return
    if OS.has_environment("MAP_SMOKE_TEST"):
        print("[MapSetup] Map generation complete with %d keys." % _last_map_data.keys().size())
    map_view.set_map_data(_last_map_data)
    _update_kingdom_legend()

func _build_generation_params() -> MapGenerationParams:
    return MapGenerationParamsScript.new(
        int(seed_spin.value),
        int(map_size_spin.value),
        int(kingdoms_spin.value),
        float(sea_level_spin.value),
        int(terrain_octaves_spin.value),
        float(terrain_roughness_spin.value),
        float(mountain_scale_spin.value),
        float(erosion_spin.value),
        32.0,
        0.55,
        float(road_aggressiveness_spin.value),
        int(fort_cap_spin.value),
        int(fort_spacing_spin.value),
        MapGenerationParams.DEFAULT_CITY_MIN_DISTANCE,
        MapGenerationParams.DEFAULT_VILLAGE_MIN_DISTANCE
    )

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    terrain_octaves_label.text = I18N.t("setup.terrain_octaves")
    terrain_roughness_label.text = I18N.t("setup.terrain_roughness")
    mountain_scale_label.text = I18N.t("setup.mountain_scale")
    sea_level_label.text = I18N.t("setup.sea_level")
    kingdoms_label.text = I18N.t("setup.kingdoms")
    road_aggressiveness_label.text = I18N.t("setup.road_aggressiveness")
    fort_cap_label.text = I18N.t("setup.fort_global_cap")
    fort_spacing_label.text = I18N.t("setup.fort_spacing")
    map_size_label.text = I18N.t("setup.map_size")
    erosion_label.text = I18N.t("setup.erosion_strength")
    show_roads_checkbox.text = I18N.t("setup.show_roads")
    show_rivers_checkbox.text = I18N.t("setup.show_rivers")
    show_cities_checkbox.text = I18N.t("setup.show_cities")
    show_crossings_checkbox.text = I18N.t("setup.show_crossroads")
    show_regions_checkbox.text = I18N.t("setup.show_regions")
    show_fertility_checkbox.text = I18N.t("setup.show_fertility")
    show_roughness_checkbox.text = I18N.t("setup.show_roughness")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")
    if _legend_header_label != null:
        _legend_header_label.text = I18N.t("setup.legend_header")
    if _kingdom_header_label != null:
        _kingdom_header_label.text = I18N.t("setup.legend_regions")
    for entry in LEGEND_CONFIG:
        var layer := String(entry.get("layer", ""))
        if layer.is_empty():
            continue
        if _legend_buttons.has(layer):
            var button: LegendIconButton = _legend_buttons[layer]
            button.text = I18N.t(entry.get("label", ""))
    _update_kingdom_legend()

func _update_kingdom_legend() -> void:
    if _kingdom_container == null:
        return
    for child in _kingdom_container.get_children():
        child.queue_free()
    var colors: Dictionary = map_view.get_kingdom_colors()
    if colors.is_empty():
        return
    var ids: Array = colors.keys()
    ids.sort()
    for id_value in ids:
        var kingdom_id := int(id_value)
        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var swatch := ColorRect.new()
        swatch.custom_minimum_size = Vector2(24, 16)
        swatch.color = colors[kingdom_id]
        swatch.size_flags_horizontal = Control.SIZE_FILL
        swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(swatch)
        var label := Label.new()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var template := I18N.t("setup.legend_kingdom")
        label.text = template.format({"number": kingdom_id + 1})
        row.add_child(label)
        _kingdom_container.add_child(row)

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
