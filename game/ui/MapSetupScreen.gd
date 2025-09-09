extends Control

const MapGeneratorModule = preload("res://map/MapGenerator.gd")

@onready var title_label: Label = $VBox/Title
@onready var seed_label: Label = $VBox/Params/SeedLabel
@onready var seed_spin: SpinBox = $VBox/Params/SeedRow/Seed
@onready var random_seed_button: Button = $VBox/Params/SeedRow/RandomSeed
@onready var nodes_label: Label = $VBox/Params/NodesLabel
@onready var nodes_spin: SpinBox = $VBox/Params/Nodes
@onready var cities_label: Label = $VBox/Params/CitiesLabel
@onready var cities_spin: SpinBox = $VBox/Params/Cities
@onready var rivers_label: Label = $VBox/Params/RiversLabel
@onready var rivers_spin: SpinBox = $VBox/Params/Rivers
@onready var map_view: MapView = $VBox/MapView
@onready var start_button: Button = $VBox/Buttons/Start
@onready var back_button: Button = $VBox/Buttons/Back
@onready var main_ui: VBoxContainer = $VBox
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

var current_map: Dictionary = {}
var previous_state: String = Net.state

func _ready() -> void:
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    add_child(connecting_ui)
    random_seed_button.pressed.connect(_on_random_seed_pressed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    seed_spin.value_changed.connect(_on_params_changed)
    nodes_spin.value_changed.connect(_on_params_changed)
    cities_spin.value_changed.connect(_on_params_changed)
    rivers_spin.value_changed.connect(_on_params_changed)
    _update_texts()
    _generate_map()
    _on_net_state_changed(Net.state)

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    seed_label.text = I18N.t("setup.seed")
    random_seed_button.text = I18N.t("setup.random_seed")
    nodes_label.text = I18N.t("setup.nodes")
    cities_label.text = I18N.t("setup.cities")
    rivers_label.text = I18N.t("setup.rivers")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")

func _generate_map() -> void:
    var params := MapGeneratorModule.MapGenParams.new(
        int(seed_spin.value),
        int(nodes_spin.value),
        int(cities_spin.value),
        int(rivers_spin.value)
    )
    if seed_spin.value != params.rng_seed:
        seed_spin.set_block_signals(true)
        seed_spin.value = params.rng_seed
        seed_spin.set_block_signals(false)
    var generator := MapGeneratorModule.new(params)
    current_map = generator.generate()
    map_view.set_map_data(current_map)

func _on_params_changed(_value: float) -> void:
    _generate_map()

func _on_random_seed_pressed() -> void:
    seed_spin.set_block_signals(true)
    var random_value: int = randi() % int(seed_spin.max_value)
    seed_spin.value = random_value
    seed_spin.set_block_signals(false)
    _generate_map()

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
