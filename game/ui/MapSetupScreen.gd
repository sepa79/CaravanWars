extends Control

const MapGeneratorModule = preload("res://map/MapGenerator.gd")
const RegionGeneratorModule = preload("res://map/RegionGenerator.gd")
const RoadNetworkModule = preload("res://map/RoadNetwork.gd")
const MapSnapshotModule = preload("res://map/MapSnapshot.gd")

@onready var title_label: Label = $HBox/ControlsScroll/Controls/Title
@onready var params: GridContainer = $HBox/ControlsScroll/Controls/Params
@onready var seed_label: Label = params.get_node("SeedLabel")
@onready var seed_spin: SpinBox = params.get_node("SeedRow/Seed")
@onready var random_seed_button: Button = params.get_node("SeedRow/RandomSeed")
@onready var cities_label: Label = params.get_node("CitiesLabel")
@onready var cities_spin: SpinBox = params.get_node("Cities")
@onready var min_city_spacing_label: Label = params.get_node("MinCitySpacingLabel")
@onready var min_city_spacing_spin: SpinBox = params.get_node("MinCitySpacing")
@onready var max_city_spacing_label: Label = params.get_node("MaxCitySpacingLabel")
@onready var max_city_spacing_spin: SpinBox = params.get_node("MaxCitySpacing")
@onready var rivers_label: Label = params.get_node("RiversLabel")
@onready var rivers_spin: SpinBox = params.get_node("Rivers")
@onready var kingdoms_label: Label = params.get_node("KingdomsLabel")
@onready var kingdoms_spin: SpinBox = params.get_node("Kingdoms")
@onready var min_connections_label: Label = params.get_node("MinConnectionsLabel")
@onready var min_connections_spin: SpinBox = params.get_node("MinConnections")
@onready var max_connections_label: Label = params.get_node("MaxConnectionsLabel")
@onready var max_connections_spin: SpinBox = params.get_node("MaxConnections")
@onready var crossing_margin_label: Label = params.get_node("CrossingMarginLabel")
@onready var crossing_margin_spin: SpinBox = params.get_node("CrossingMargin")
@onready var width_label: Label = params.get_node("WidthLabel")
@onready var width_spin: SpinBox = params.get_node("Width")
@onready var height_label: Label = params.get_node("HeightLabel")
@onready var height_spin: SpinBox = params.get_node("Height")
@onready var map_view: MapView = $HBox/MapRow/MapView
@onready var kingdom_legend: VBoxContainer = $HBox/MapRow/KingdomLegend
@onready var show_roads_check: CheckBox = $Layers/ShowRoads
@onready var show_rivers_check: CheckBox = $Layers/ShowRivers
@onready var show_cities_check: CheckBox = $Layers/ShowCities
@onready var show_crossings_check: CheckBox = $Layers/ShowCrossings
@onready var show_regions_check: CheckBox = $Layers/ShowRegions
@onready var edit_cities_check: CheckBox = $Layers/EditCities
@onready var start_button: Button = $HBox/ControlsScroll/Controls/Buttons/Start
@onready var back_button: Button = $HBox/ControlsScroll/Controls/Buttons/Back
@onready var main_ui: HBoxContainer = $HBox
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

var debounce_timer: Timer = Timer.new()

var current_map: Dictionary = {}
var previous_state: String = Net.state
var app_version: String = ""

func _ready() -> void:
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    add_child(connecting_ui)
    add_child(debounce_timer)
    debounce_timer.one_shot = true
    debounce_timer.wait_time = 0.3
    debounce_timer.timeout.connect(_generate_map)
    var vf := FileAccess.open("res://VERSION", FileAccess.READ)
    if vf:
        app_version = vf.get_as_text().strip_edges()
        vf.close()
    random_seed_button.pressed.connect(_on_random_seed_pressed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    seed_spin.value_changed.connect(_on_params_changed)
    cities_spin.value_changed.connect(_on_params_changed)
    rivers_spin.value_changed.connect(_on_params_changed)
    kingdoms_spin.value_changed.connect(_on_params_changed)
    min_connections_spin.value_changed.connect(_on_params_changed)
    max_connections_spin.value_changed.connect(_on_params_changed)
    min_city_spacing_spin.value_changed.connect(_on_params_changed)
    max_city_spacing_spin.value_changed.connect(_on_params_changed)
    crossing_margin_spin.value_changed.connect(_on_params_changed)
    width_spin.value_changed.connect(_on_params_changed)
    height_spin.value_changed.connect(_on_params_changed)
    show_roads_check.toggled.connect(_on_show_roads_toggled)
    show_rivers_check.toggled.connect(_on_show_rivers_toggled)
    show_cities_check.toggled.connect(_on_show_cities_toggled)
    show_crossings_check.toggled.connect(_on_show_crossings_toggled)
    show_regions_check.toggled.connect(_on_show_regions_toggled)
    edit_cities_check.toggled.connect(_on_edit_cities_toggled)
    map_view.set_show_roads(show_roads_check.button_pressed)
    map_view.set_show_rivers(show_rivers_check.button_pressed)
    map_view.set_show_cities(show_cities_check.button_pressed)
    map_view.set_show_crossings(show_crossings_check.button_pressed)
    map_view.set_show_regions(show_regions_check.button_pressed)
    map_view.cities_changed.connect(_on_cities_changed)
    _update_texts()
    _generate_map()
    _on_net_state_changed(Net.state)

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    cities_label.text = I18N.t("setup.cities")
    min_city_spacing_label.text = I18N.t("setup.min_city_spacing")
    max_city_spacing_label.text = I18N.t("setup.max_city_spacing")
    rivers_label.text = I18N.t("setup.rivers")
    kingdoms_label.text = I18N.t("setup.kingdoms")
    min_connections_label.text = I18N.t("setup.min_connections")
    max_connections_label.text = I18N.t("setup.max_connections")
    crossing_margin_label.text = I18N.t("setup.crossing_margin")
    width_label.text = I18N.t("setup.width")
    height_label.text = I18N.t("setup.height")
    show_roads_check.text = I18N.t("setup.show_roads")
    show_rivers_check.text = I18N.t("setup.show_rivers")
    show_cities_check.text = I18N.t("setup.show_cities")
    show_crossings_check.text = I18N.t("setup.show_crossings")
    show_regions_check.text = I18N.t("setup.show_regions")
    edit_cities_check.text = I18N.t("setup.edit_cities")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")

func _generate_map() -> void:
    start_button.disabled = true
    var city_count := int(cities_spin.value)
    var kingdoms := int(min(kingdoms_spin.value, city_count))
    var map_params := MapGeneratorModule.MapGenParams.new(
        int(seed_spin.value),
        city_count,
        int(rivers_spin.value),
        int(min_connections_spin.value),
        int(max_connections_spin.value),
        min_city_spacing_spin.value,
        max_city_spacing_spin.value,
        crossing_margin_spin.value,
        width_spin.value,
        height_spin.value,
        kingdoms
    )
    kingdoms_spin.max_value = map_params.city_count
    if int(kingdoms_spin.value) != map_params.kingdom_count:
        kingdoms_spin.set_block_signals(true)
        kingdoms_spin.value = map_params.kingdom_count
        kingdoms_spin.set_block_signals(false)
    var max_possible: int = max(1, map_params.city_count - 1)
    var prev_max_possible: int = int(max_connections_spin.max_value)
    max_connections_spin.max_value = max_possible
    if int(max_connections_spin.value) == prev_max_possible and prev_max_possible < max_possible:
        map_params.max_connections = max_possible
        max_connections_spin.set_block_signals(true)
        max_connections_spin.value = map_params.max_connections
        max_connections_spin.set_block_signals(false)
    max_connections_spin.min_value = map_params.min_connections
    min_connections_spin.max_value = map_params.max_connections
    max_city_spacing_spin.min_value = map_params.min_city_distance
    min_city_spacing_spin.max_value = map_params.max_city_distance
    if seed_spin.value != map_params.rng_seed:
        seed_spin.set_block_signals(true)
        seed_spin.value = map_params.rng_seed
        seed_spin.set_block_signals(false)
    if min_connections_spin.value != map_params.min_connections:
        min_connections_spin.set_block_signals(true)
        min_connections_spin.value = map_params.min_connections
        min_connections_spin.set_block_signals(false)
    if max_connections_spin.value != map_params.max_connections:
        max_connections_spin.set_block_signals(true)
        max_connections_spin.value = map_params.max_connections
        max_connections_spin.set_block_signals(false)
    if min_city_spacing_spin.value != map_params.min_city_distance:
        min_city_spacing_spin.set_block_signals(true)
        min_city_spacing_spin.value = map_params.min_city_distance
        min_city_spacing_spin.set_block_signals(false)
    if max_city_spacing_spin.value != map_params.max_city_distance:
        max_city_spacing_spin.set_block_signals(true)
        max_city_spacing_spin.value = map_params.max_city_distance
        max_city_spacing_spin.set_block_signals(false)
    if width_spin.value != map_params.width:
        width_spin.set_block_signals(true)
        width_spin.value = map_params.width
        width_spin.set_block_signals(false)
    if height_spin.value != map_params.height:
        height_spin.set_block_signals(true)
        height_spin.value = map_params.height
        height_spin.set_block_signals(false)
    var generator := MapGeneratorModule.new(map_params)
    current_map = generator.generate()
    map_view.set_map_data(current_map)
    var actual_city_count: int = current_map.get("cities", []).size()
    kingdoms_spin.max_value = actual_city_count
    if int(kingdoms_spin.value) > actual_city_count:
        kingdoms_spin.set_block_signals(true)
        kingdoms_spin.value = actual_city_count
        kingdoms_spin.set_block_signals(false)
    _populate_kingdom_legend()
    start_button.disabled = false
    _update_snapshot()

func _on_params_changed(_value: float) -> void:
    start_button.disabled = true
    debounce_timer.stop()
    debounce_timer.start()

func _on_show_roads_toggled(pressed: bool) -> void:
    map_view.set_show_roads(pressed)

func _on_show_rivers_toggled(pressed: bool) -> void:
    map_view.set_show_rivers(pressed)

func _on_show_cities_toggled(pressed: bool) -> void:
    map_view.set_show_cities(pressed)

func _on_show_crossings_toggled(pressed: bool) -> void:
    map_view.set_show_crossings(pressed)

func _on_show_regions_toggled(pressed: bool) -> void:
    map_view.set_show_regions(pressed)

func _on_edit_cities_toggled(pressed: bool) -> void:
    map_view.set_edit_mode(pressed)

func _on_random_seed_pressed() -> void:
    seed_spin.set_block_signals(true)
    var random_value: int = randi_range(1, int(seed_spin.max_value))
    seed_spin.value = random_value
    seed_spin.set_block_signals(false)
    _on_params_changed(0.0)

func _on_start_pressed() -> void:
    _update_snapshot()
    match Net.run_mode:
        "single":
            Net.start_singleplayer()
        "host":
            Net.start_host()
    # other modes ignored

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

func _populate_kingdom_legend() -> void:
    for child in kingdom_legend.get_children():
        child.queue_free()
    var colors: Dictionary = map_view.get_kingdom_colors()
    if not current_map.has("kingdom_names"):
        current_map["kingdom_names"] = {}
    var names: Dictionary = current_map["kingdom_names"]
    for kingdom_id in colors.keys():
        var entry := HBoxContainer.new()
        entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        kingdom_legend.add_child(entry)
        var swatch := ColorRect.new()
        swatch.custom_minimum_size = Vector2(16, 16)
        swatch.color = colors[kingdom_id]
        entry.add_child(swatch)
        var name_edit := LineEdit.new()
        name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_edit.text = names.get(kingdom_id, "Kingdom %d" % kingdom_id)
        name_edit.text_changed.connect(_on_kingdom_name_changed.bind(kingdom_id))
        entry.add_child(name_edit)

func _on_kingdom_name_changed(text: String, kingdom_id: int) -> void:
    if not current_map.has("kingdom_names"):
        current_map["kingdom_names"] = {}
    current_map["kingdom_names"][kingdom_id] = text

func _on_cities_changed(cities: Array) -> void:
    current_map["cities"] = cities
    var region_stage = RegionGeneratorModule.new()
    var regions = region_stage.generate_regions(cities, int(kingdoms_spin.value), current_map.get("width", 100.0), current_map.get("height", 100.0))
    current_map["regions"] = regions
    var rng := RandomNumberGenerator.new()
    rng.seed = int(seed_spin.value)
    var road_stage := RoadNetworkModule.new(rng)
    var roads = road_stage.build_roads(cities, int(min_connections_spin.value), int(max_connections_spin.value), crossing_margin_spin.value)
    current_map["roads"] = roads
    map_view.set_map_data(current_map)
    _update_snapshot()

func _update_snapshot() -> void:
    var snapshot := MapSnapshotModule.from_map(current_map, int(seed_spin.value), app_version)
    current_map["snapshot"] = snapshot.to_dict()
