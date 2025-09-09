extends Control

const MapGeneratorModule = preload("res://map/MapGenerator.gd")

@onready var title_label: Label = $VBox/Title
@onready var seed_label: Label = $VBox/Params/SeedLabel
@onready var seed_spin: SpinBox = $VBox/Params/SeedRow/Seed
@onready var random_seed_button: Button = $VBox/Params/SeedRow/RandomSeed
@onready var cities_label: Label = $VBox/Params/CitiesLabel
@onready var cities_spin: SpinBox = $VBox/Params/Cities
@onready var rivers_label: Label = $VBox/Params/RiversLabel
@onready var rivers_spin: SpinBox = $VBox/Params/Rivers
@onready var min_connections_label: Label = $VBox/Params/MinConnectionsLabel
@onready var min_connections_spin: SpinBox = $VBox/Params/MinConnections
@onready var max_connections_label: Label = $VBox/Params/MaxConnectionsLabel
@onready var max_connections_spin: SpinBox = $VBox/Params/MaxConnections
@onready var crossing_margin_label: Label = $VBox/Params/CrossingMarginLabel
@onready var crossing_margin_spin: SpinBox = $VBox/Params/CrossingMargin
@onready var map_view: MapView = $VBox/MapView
@onready var show_roads_check: CheckBox = $VBox/Layers/ShowRoads
@onready var show_rivers_check: CheckBox = $VBox/Layers/ShowRivers
@onready var show_cities_check: CheckBox = $VBox/Layers/ShowCities
@onready var show_crossings_check: CheckBox = $VBox/Layers/ShowCrossings
@onready var show_regions_check: CheckBox = $VBox/Layers/ShowRegions
@onready var start_button: Button = $VBox/Buttons/Start
@onready var back_button: Button = $VBox/Buttons/Back
@onready var main_ui: VBoxContainer = $VBox
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

var debounce_timer: Timer = Timer.new()

var current_map: Dictionary = {}
var previous_state: String = Net.state

func _ready() -> void:
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    add_child(connecting_ui)
    add_child(debounce_timer)
    debounce_timer.one_shot = true
    debounce_timer.wait_time = 0.3
    debounce_timer.timeout.connect(_generate_map)
    random_seed_button.pressed.connect(_on_random_seed_pressed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    seed_spin.value_changed.connect(_on_params_changed)
    cities_spin.value_changed.connect(_on_params_changed)
    rivers_spin.value_changed.connect(_on_params_changed)
    min_connections_spin.value_changed.connect(_on_params_changed)
    max_connections_spin.value_changed.connect(_on_params_changed)
    crossing_margin_spin.value_changed.connect(_on_params_changed)
    show_roads_check.toggled.connect(_on_show_roads_toggled)
    show_rivers_check.toggled.connect(_on_show_rivers_toggled)
    show_cities_check.toggled.connect(_on_show_cities_toggled)
    show_crossings_check.toggled.connect(_on_show_crossings_toggled)
    show_regions_check.toggled.connect(_on_show_regions_toggled)
    map_view.set_show_roads(show_roads_check.button_pressed)
    map_view.set_show_rivers(show_rivers_check.button_pressed)
    map_view.set_show_cities(show_cities_check.button_pressed)
    map_view.set_show_crossings(show_crossings_check.button_pressed)
    map_view.set_show_regions(show_regions_check.button_pressed)
    _update_texts()
    _generate_map()
    _on_net_state_changed(Net.state)

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    cities_label.text = I18N.t("setup.cities")
    rivers_label.text = I18N.t("setup.rivers")
    min_connections_label.text = I18N.t("setup.min_connections")
    max_connections_label.text = I18N.t("setup.max_connections")
    crossing_margin_label.text = I18N.t("setup.crossing_margin")
    show_roads_check.text = I18N.t("setup.show_roads")
    show_rivers_check.text = I18N.t("setup.show_rivers")
    show_cities_check.text = I18N.t("setup.show_cities")
    show_crossings_check.text = I18N.t("setup.show_crossings")
    show_regions_check.text = I18N.t("setup.show_regions")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")

func _generate_map() -> void:
    start_button.disabled = true
    var params := MapGeneratorModule.MapGenParams.new(
        int(seed_spin.value),
        int(cities_spin.value),
        int(rivers_spin.value),
        int(min_connections_spin.value),
        int(max_connections_spin.value),
        crossing_margin_spin.value
    )
    var max_possible := max(1, params.city_count - 1)
    min_connections_spin.max_value = max_possible
    max_connections_spin.max_value = max_possible
    if int(max_connections_spin.value) == params.max_connections and params.max_connections < max_possible:
        params.max_connections = max_possible
        max_connections_spin.set_block_signals(true)
        max_connections_spin.value = params.max_connections
        max_connections_spin.set_block_signals(false)
    if seed_spin.value != params.rng_seed:
        seed_spin.set_block_signals(true)
        seed_spin.value = params.rng_seed
        seed_spin.set_block_signals(false)
    if min_connections_spin.value != params.min_connections:
        min_connections_spin.set_block_signals(true)
        min_connections_spin.value = params.min_connections
        min_connections_spin.set_block_signals(false)
    if max_connections_spin.value != params.max_connections:
        max_connections_spin.set_block_signals(true)
        max_connections_spin.value = params.max_connections
        max_connections_spin.set_block_signals(false)
    var generator := MapGeneratorModule.new(params)
    current_map = generator.generate()
    map_view.set_map_data(current_map)
    start_button.disabled = false

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

func _on_random_seed_pressed() -> void:
    seed_spin.set_block_signals(true)
    var random_value: int = randi() % int(seed_spin.max_value)
    seed_spin.value = random_value
    seed_spin.set_block_signals(false)
    _on_params_changed(0.0)

func _on_start_pressed() -> void:
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
