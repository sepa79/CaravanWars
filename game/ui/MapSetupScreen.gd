extends Control

const MapGeneratorModule = preload("res://map/MapGenerator.gd")

@onready var title_label: Label = $VBox/Title
@onready var map_view: MapView = $VBox/MapView
@onready var generate_button: Button = $VBox/Buttons/Generate
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
    generate_button.pressed.connect(_on_generate_pressed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    _update_texts()
    _generate_map()
    _on_net_state_changed(Net.state)

func _update_texts() -> void:
    title_label.text = I18N.t("setup.title")
    generate_button.text = I18N.t("setup.generate")
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")

func _generate_map() -> void:
    var map_seed: int = Time.get_ticks_msec()
    var generator := MapGeneratorModule.new(map_seed)
    current_map = generator.generate()
    map_view.set_map_data(current_map)

func _on_generate_pressed() -> void:
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
