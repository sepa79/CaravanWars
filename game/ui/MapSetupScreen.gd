extends Control

const MapGeneratorModule = preload("res://mapgen/MapGenerator.gd")
const RegionGeneratorModule = preload("res://mapgen/RegionGenerator.gd")
const RoadNetworkModule = preload("res://mapview/RoadNetwork.gd")
const MapSnapshotModule = preload("res://mapview/MapSnapshot.gd")
const MapValidatorModule = preload("res://mapgen/MapValidator.gd")
const MapBundleLoaderModule = preload("res://mapgen/MapBundleLoader.gd")

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
@onready var show_crossroads_check: CheckBox = $Layers/ShowCrossings
@onready var show_regions_check: CheckBox = $Layers/ShowRegions
@onready var show_fertility_check: CheckBox = $Layers/ShowFertility
@onready var show_roughness_check: CheckBox = $Layers/ShowRoughness
@onready var edit_cities_check: CheckBox = $Layers/EditCities
@onready var add_road_button: Button = $Layers/AddRoad
@onready var delete_road_button: Button = $Layers/DeleteRoad
@onready var validate_button: Button = $Layers/ValidateMap
@onready var layers: HBoxContainer = $Layers
var add_village_button: Button
var add_fort_button: Button
var road_class_selector: OptionButton
var finalize_button: Button
var export_button: Button
var import_button: Button
var max_forts_label: Label
var max_forts_spin: SpinBox
var min_villages_label: Label
var min_villages_spin: SpinBox
var max_villages_label: Label
var max_villages_spin: SpinBox
var village_threshold_label: Label
var village_threshold_spin: SpinBox
@onready var start_button: Button = $HBox/ControlsScroll/Controls/Buttons/Start
@onready var back_button: Button = $HBox/ControlsScroll/Controls/Buttons/Back
@onready var main_ui: HBoxContainer = $HBox
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

var debounce_timer: Timer = Timer.new()

var current_map: Dictionary = {}
var previous_state: String = Net.state
var app_version: String = ""
var legend_labels: Dictionary = {}

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
    max_forts_label = Label.new()
    params.add_child(max_forts_label)
    max_forts_spin = SpinBox.new()
    max_forts_spin.min_value = 0
    max_forts_spin.max_value = 10
    max_forts_spin.value = 1
    params.add_child(max_forts_spin)
    max_forts_spin.value_changed.connect(_on_params_changed)
    min_villages_label = Label.new()
    params.add_child(min_villages_label)
    min_villages_spin = SpinBox.new()
    min_villages_spin.min_value = 0
    min_villages_spin.max_value = 10
    params.add_child(min_villages_spin)
    min_villages_spin.value_changed.connect(_on_params_changed)
    max_villages_label = Label.new()
    params.add_child(max_villages_label)
    max_villages_spin = SpinBox.new()
    max_villages_spin.min_value = 0
    max_villages_spin.max_value = 10
    max_villages_spin.value = 2
    params.add_child(max_villages_spin)
    max_villages_spin.value_changed.connect(_on_params_changed)
    village_threshold_label = Label.new()
    params.add_child(village_threshold_label)
    village_threshold_spin = SpinBox.new()
    village_threshold_spin.min_value = 1
    village_threshold_spin.max_value = 5
    village_threshold_spin.value = 1
    params.add_child(village_threshold_spin)
    village_threshold_spin.value_changed.connect(_on_params_changed)
    show_roads_check.toggled.connect(_on_show_roads_toggled)
    show_rivers_check.toggled.connect(_on_show_rivers_toggled)
    show_cities_check.toggled.connect(_on_show_cities_toggled)
    show_crossroads_check.toggled.connect(_on_show_crossroads_toggled)
    show_regions_check.toggled.connect(_on_show_regions_toggled)
    show_fertility_check.toggled.connect(_on_show_fertility_toggled)
    show_roughness_check.toggled.connect(_on_show_roughness_toggled)
    edit_cities_check.toggled.connect(_on_edit_cities_toggled)
    add_road_button.toggled.connect(_on_add_road_toggled)
    delete_road_button.toggled.connect(_on_delete_road_toggled)
    validate_button.pressed.connect(_on_validate_map_pressed)
    add_village_button = Button.new()
    add_village_button.toggle_mode = true
    layers.add_child(add_village_button)
    add_village_button.toggled.connect(_on_add_village_toggled)
    add_fort_button = Button.new()
    add_fort_button.toggle_mode = true
    layers.add_child(add_fort_button)
    add_fort_button.toggled.connect(_on_add_fort_toggled)
    road_class_selector = OptionButton.new()
    road_class_selector.add_item(I18N.t("setup.road_class_path"))
    road_class_selector.add_item(I18N.t("setup.road_class_road"))
    road_class_selector.add_item(I18N.t("setup.road_class_roman"))
    road_class_selector.select(1)
    layers.add_child(road_class_selector)
    road_class_selector.item_selected.connect(_on_road_class_selected)
    map_view.set_road_class("road")
    finalize_button = Button.new()
    layers.add_child(finalize_button)
    finalize_button.pressed.connect(_on_finalize_map_pressed)
    export_button = Button.new()
    layers.add_child(export_button)
    export_button.pressed.connect(_on_export_map_pressed)
    import_button = Button.new()
    layers.add_child(import_button)
    import_button.pressed.connect(_on_import_map_pressed)
    show_roads_check.button_pressed = true
    show_rivers_check.button_pressed = true
    show_cities_check.button_pressed = true
    show_crossroads_check.button_pressed = true
    show_regions_check.button_pressed = true
    show_roads_check.hide()
    show_rivers_check.hide()
    show_cities_check.hide()
    show_crossroads_check.hide()
    show_regions_check.hide()
    map_view.set_show_roads(true)
    map_view.set_show_rivers(true)
    map_view.set_show_cities(true)
    map_view.set_show_crossroads(true)
    map_view.set_show_bridges(true)
    map_view.set_show_fords(true)
    map_view.set_show_regions(true)
    map_view.set_show_villages(true)
    map_view.set_show_forts(true)
    map_view.set_show_fertility(false)
    map_view.set_show_roughness(false)
    map_view.cities_changed.connect(_on_cities_changed)
    var entity_legend := VBoxContainer.new()
    $HBox/MapRow.add_child(entity_legend)
    var items := [
        {"key": "setup.legend_roads", "type": "road", "func": Callable(map_view, "set_show_roads")},
        {"key": "setup.legend_rivers", "type": "river", "func": Callable(map_view, "set_show_rivers")},
        {"key": "setup.legend_cities", "type": "city", "func": Callable(map_view, "set_show_cities")},
        {"key": "setup.legend_villages", "type": "village", "func": Callable(map_view, "set_show_villages")},
        {"key": "setup.legend_forts", "type": "fort", "func": Callable(map_view, "set_show_forts")},
        {"key": "setup.legend_crossroads", "type": "crossroad", "func": Callable(map_view, "set_show_crossroads")},
        {"key": "setup.legend_bridges", "type": "bridge", "func": Callable(map_view, "set_show_bridges")},
        {"key": "setup.legend_fords", "type": "ford", "func": Callable(map_view, "set_show_fords")},
        {"key": "setup.legend_regions", "type": "region", "func": Callable(map_view, "set_show_regions")},
    ]
    for item in items:
        var row := HBoxContainer.new()
        var icon := LegendIconButton.new()
        icon.icon_type = item.type
        icon.custom_minimum_size = Vector2(24, 24)
        icon.toggled.connect(item.func)
        row.add_child(icon)
        var lbl := Label.new()
        lbl.text = I18N.t(item.key)
        row.add_child(lbl)
        entity_legend.add_child(row)
        legend_labels[item.key] = lbl
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
    crossing_margin_label.text = I18N.t("setup.crossroad_margin")
    width_label.text = I18N.t("setup.width")
    height_label.text = I18N.t("setup.height")
    show_roads_check.text = I18N.t("setup.show_roads")
    show_rivers_check.text = I18N.t("setup.show_rivers")
    show_cities_check.text = I18N.t("setup.show_cities")
    show_crossroads_check.text = I18N.t("setup.show_crossroads")
    show_regions_check.text = I18N.t("setup.show_regions")
    show_fertility_check.text = I18N.t("setup.show_fertility")
    show_roughness_check.text = I18N.t("setup.show_roughness")
    edit_cities_check.text = I18N.t("setup.edit_cities")
    add_road_button.text = I18N.t("setup.add_road")
    delete_road_button.text = I18N.t("setup.delete_road")
    validate_button.text = I18N.t("setup.validate_map")
    add_village_button.text = I18N.t("setup.add_village")
    add_fort_button.text = I18N.t("setup.add_fort")
    finalize_button.text = I18N.t("setup.finalize_map")
    export_button.text = I18N.t("setup.export")
    import_button.text = I18N.t("setup.import")
    max_forts_label.text = I18N.t("setup.max_forts_per_kingdom")
    min_villages_label.text = I18N.t("setup.min_villages_per_city")
    max_villages_label.text = I18N.t("setup.max_villages_per_city")
    village_threshold_label.text = I18N.t("setup.village_path_threshold")
    road_class_selector.set_item_text(0, I18N.t("setup.road_class_path"))
    road_class_selector.set_item_text(1, I18N.t("setup.road_class_road"))
    road_class_selector.set_item_text(2, I18N.t("setup.road_class_roman"))
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")
    for key in legend_labels.keys():
        legend_labels[key].text = I18N.t(key)

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
        kingdoms,
        int(max_forts_spin.value),
        int(min_villages_spin.value),
        int(max_villages_spin.value),
        int(village_threshold_spin.value)
    )
    kingdoms_spin.max_value = map_params.city_count
    if int(kingdoms_spin.value) != map_params.kingdom_count:
        kingdoms_spin.set_block_signals(true)
        kingdoms_spin.value = map_params.kingdom_count
        kingdoms_spin.set_block_signals(false)
    var max_possible: int = min(7, max(1, map_params.city_count - 1))
    max_connections_spin.max_value = max_possible
    if map_params.max_connections > max_possible:
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
    if max_forts_spin.value != map_params.max_forts_per_kingdom:
        max_forts_spin.set_block_signals(true)
        max_forts_spin.value = map_params.max_forts_per_kingdom
        max_forts_spin.set_block_signals(false)
    if min_villages_spin.value != map_params.min_villages_per_city:
        min_villages_spin.set_block_signals(true)
        min_villages_spin.value = map_params.min_villages_per_city
        min_villages_spin.set_block_signals(false)
    if max_villages_spin.value != map_params.max_villages_per_city:
        max_villages_spin.set_block_signals(true)
        max_villages_spin.value = map_params.max_villages_per_city
        max_villages_spin.set_block_signals(false)
    max_villages_spin.min_value = min_villages_spin.value
    min_villages_spin.max_value = max_villages_spin.value
    if village_threshold_spin.value != map_params.village_downgrade_threshold:
        village_threshold_spin.set_block_signals(true)
        village_threshold_spin.value = map_params.village_downgrade_threshold
        village_threshold_spin.set_block_signals(false)
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
    map_view.queue_redraw()

func _on_show_roads_toggled(pressed: bool) -> void:
    map_view.set_show_roads(pressed)

func _on_show_rivers_toggled(pressed: bool) -> void:
    map_view.set_show_rivers(pressed)

func _on_show_cities_toggled(pressed: bool) -> void:
    map_view.set_show_cities(pressed)

func _on_show_crossroads_toggled(pressed: bool) -> void:
    map_view.set_show_crossroads(pressed)

func _on_show_regions_toggled(pressed: bool) -> void:
    map_view.set_show_regions(pressed)

func _on_show_fertility_toggled(pressed: bool) -> void:
    map_view.set_show_fertility(pressed)

func _on_show_roughness_toggled(pressed: bool) -> void:
    map_view.set_show_roughness(pressed)

func _on_edit_cities_toggled(pressed: bool) -> void:
    map_view.set_edit_mode(pressed)

func _on_add_road_toggled(pressed: bool) -> void:
    if pressed:
        delete_road_button.button_pressed = false
        add_village_button.button_pressed = false
        add_fort_button.button_pressed = false
        map_view.set_road_mode("add")
    else:
        map_view.set_road_mode("")

func _on_delete_road_toggled(pressed: bool) -> void:
    if pressed:
        add_road_button.button_pressed = false
        add_village_button.button_pressed = false
        add_fort_button.button_pressed = false
        map_view.set_road_mode("delete")
    else:
        map_view.set_road_mode("")

func _on_add_village_toggled(pressed: bool) -> void:
    if pressed:
        add_road_button.button_pressed = false
        delete_road_button.button_pressed = false
        add_fort_button.button_pressed = false
        map_view.set_road_mode("village")
    else:
        map_view.set_road_mode("")

func _on_add_fort_toggled(pressed: bool) -> void:
    if pressed:
        add_road_button.button_pressed = false
        delete_road_button.button_pressed = false
        add_village_button.button_pressed = false
        map_view.set_road_mode("fort")
    else:
        map_view.set_road_mode("")

func _on_road_class_selected(index: int) -> void:
    var cls: String = "path"
    if index == 1:
        cls = "road"
    elif index == 2:
        cls = "roman"
    map_view.set_road_class(cls)

func _on_finalize_map_pressed() -> void:
    var validator: MapGenValidator = MapValidatorModule.new()
    var errors: Array[String] = validator.validate(current_map["roads"], current_map.get("rivers", []))
    if errors.is_empty():
        var helper: MapViewRoadNetwork = RoadNetworkModule.new(RandomNumberGenerator.new())
        helper.cleanup(current_map["roads"])
        map_view.set_map_data(current_map)
        map_view.set_edit_mode(false)
        map_view.set_road_mode("")
        edit_cities_check.disabled = true
        add_road_button.disabled = true
        delete_road_button.disabled = true
        add_village_button.disabled = true
        add_fort_button.disabled = true
        road_class_selector.disabled = true
        validate_button.disabled = true
        _update_snapshot()
        # Placeholder for sending snapshot to host
    else:
        for err in errors:
            push_warning(err)

func _on_validate_map_pressed() -> void:
    var validator: MapGenValidator = MapValidatorModule.new()
    var errors: Array[String] = validator.validate(current_map["roads"], current_map.get("rivers", []))
    if errors.is_empty():
        var road_helper: MapViewRoadNetwork = RoadNetworkModule.new(RandomNumberGenerator.new())
        road_helper.cleanup(current_map["roads"])
        map_view.set_map_data(current_map)
        map_view.queue_redraw()
        _update_snapshot()
    else:
        for err in errors:
            push_warning(err)

func _on_export_map_pressed() -> void:
    MapGeneratorModule.export_bundle("user://MapBundle.json", current_map, int(seed_spin.value), app_version, width_spin.value, height_spin.value)

func _on_import_map_pressed() -> void:
    var loader: MapBundleLoader = MapBundleLoaderModule.new()
    var data: Dictionary = loader.load("user://MapBundle.json")
    if data.is_empty():
        return
    current_map = data
    seed_spin.set_block_signals(true)
    seed_spin.value = current_map.get("meta", {}).get("seed", seed_spin.value)
    seed_spin.set_block_signals(false)
    map_view.set_map_data(current_map)
    _populate_kingdom_legend()
    _update_snapshot()

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
    for idx in current_map.get("capitals", []):
        var nid: int = idx + 1
        var node: MapViewNode = (roads.get("nodes", {}) as Dictionary).get(nid, null)
        if node != null:
            node.attrs["is_capital"] = true
    current_map["roads"] = roads
    map_view.set_map_data(current_map)
    _update_snapshot()

func _update_snapshot() -> void:
    var snapshot := MapSnapshotModule.from_map(current_map, int(seed_spin.value), app_version)
    current_map["snapshot"] = snapshot.to_dict()
