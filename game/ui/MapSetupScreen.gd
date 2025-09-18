extends Control

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"

@onready var start_button: Button = $HBox/ControlsScroll/Controls/Buttons/Start
@onready var back_button: Button = $HBox/ControlsScroll/Controls/Buttons/Back
@onready var main_ui: Control = $HBox

var previous_state: String = Net.state

func _ready() -> void:
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    start_button.pressed.connect(_on_start_pressed)
    back_button.pressed.connect(_on_back_pressed)
    _strip_legacy_controls()
    _update_texts()
    if Net.run_mode == "single":
        World.prepare_map_for_run_mode(Net.run_mode, null, true)
    _on_net_state_changed(Net.state)
    if Net.run_mode == "single" and _should_drive_ci_singleplayer():
        await _ci_start_singleplayer_game()

func _strip_legacy_controls() -> void:
    var controls_container := $HBox/ControlsScroll/Controls
    for child in controls_container.get_children():
        if child.name != "Buttons":
            child.queue_free()
    var buttons := controls_container.get_node("Buttons")
    for child in buttons.get_children():
        if child != start_button and child != back_button:
            child.queue_free()
    var map_row := $HBox.get_node_or_null("MapRow")
    if map_row != null:
        for child in map_row.get_children():
            if child.name != "MapView":
                child.queue_free()
    var layers := get_node_or_null("Layers")
    if layers != null:
        layers.queue_free()

func _update_texts() -> void:
    start_button.text = I18N.t("setup.start")
    back_button.text = I18N.t("menu.back")

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
