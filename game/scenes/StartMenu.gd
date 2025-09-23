extends Control

const CI_AUTO_SINGLEPLAYER_ENV := "CI_AUTO_SINGLEPLAYER"
const CI_AUTO_QUIT_ENV := "CI_AUTO_QUIT"
const MAP_DEBUG_SCREEN_SCRIPT := preload("res://ui/MapDebugScreen.gd")

static var _ci_has_driven_singleplayer: bool = false
static var _ci_quit_scheduled: bool = false

@onready var title_label: Label = $Title
@onready var main_menu: VBoxContainer = $MainMenu
@onready var multiplayer_menu: VBoxContainer = $MultiplayerMenu
@onready var not_available_panel: Panel = $NotAvailable
@onready var not_available_label: Label = $NotAvailable/Label
@onready var join_address_panel: Panel = $JoinAddress
@onready var join_address_label: Label = $JoinAddress/VBoxContainer/AddressLabel
@onready var join_address_input: LineEdit = $JoinAddress/VBoxContainer/AddressInput
@onready var join_address_join_button: Button = $JoinAddress/VBoxContainer/Buttons/Join
@onready var join_address_cancel_button: Button = $JoinAddress/VBoxContainer/Buttons/Cancel
@onready var version_label: Label = $Version
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

var _map_debug_button: Button

func _log(msg: String) -> void:
    print("[StartMenu] %s" % msg)

func _ready() -> void:
    I18N.language_changed.connect(update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    add_child(connecting_ui)
    _ensure_map_debug_button()
    update_texts()
    main_menu.get_node("Multiplayer").grab_focus()
    _log("ready")
    if _should_drive_ci_singleplayer() and not _ci_has_driven_singleplayer:
        _ci_has_driven_singleplayer = true
        await _ci_drive_to_singleplayer()
    elif _should_quit_after_ci_flow():
        _schedule_ci_quit()

func update_texts() -> void:
    title_label.text = I18N.t("menu.title")
    main_menu.get_node("SinglePlayer").text = I18N.t("menu.start_single")
    main_menu.get_node("Multiplayer").text = I18N.t("menu.start_multi")
    main_menu.get_node("Settings").text = I18N.t("menu.settings")
    if _map_debug_button != null:
        _map_debug_button.text = I18N.t("menu.map_debugger")
    var lang_text := I18N.t("menu.language_en") if I18N.current_lang == I18N.LANG_EN else I18N.t("menu.language_pl")
    main_menu.get_node("Language").text = "%s: %s" % [I18N.t("menu.language"), lang_text]
    main_menu.get_node("Quit").text = I18N.t("menu.quit")
    multiplayer_menu.get_node("Host").text = I18N.t("menu.host")
    multiplayer_menu.get_node("Join").text = I18N.t("menu.join")
    multiplayer_menu.get_node("Back").text = I18N.t("menu.back")
    not_available_label.text = I18N.t("menu.not_available")
    join_address_label.text = I18N.t("menu.address")
    join_address_join_button.text = I18N.t("menu.join")
    join_address_cancel_button.text = I18N.t("common.cancel")
    var build_type := "Debug" if OS.is_debug_build() else "Release"
    version_label.text = "%s %s\n%s %s" % [I18N.t("menu.version"), ProjectSettings.get_setting("application/config/version"), I18N.t("menu.build_type"), build_type]

func _ensure_map_debug_button() -> void:
    if main_menu == null:
        return
    if _map_debug_button != null and is_instance_valid(_map_debug_button):
        return
    var existing: Node = main_menu.get_node_or_null("MapDebug")
    if existing is Button:
        _map_debug_button = existing as Button
    else:
        var button := Button.new()
        button.name = "MapDebug"
        button.focus_mode = Control.FOCUS_ALL
        main_menu.add_child(button)
        var quit_button: Button = main_menu.get_node_or_null("Quit") as Button
        if quit_button != null:
            main_menu.move_child(button, quit_button.get_index())
        _map_debug_button = button
    if not _map_debug_button.pressed.is_connected(_on_map_debug_pressed):
        _map_debug_button.pressed.connect(_on_map_debug_pressed)

func _on_single_player_pressed() -> void:
    _log("single player pressed")
    Net.run_mode = "single"
    World.prepare_and_generate_map(Net.run_mode, null, true)
    App.goto_scene("res://ui/MapSetupScreen.tscn")

func _on_multiplayer_pressed() -> void:
    _log("multiplayer pressed")
    main_menu.visible = false
    multiplayer_menu.visible = true
    join_address_panel.visible = false
    not_available_panel.visible = false
    multiplayer_menu.get_node("Host").grab_focus()

func _on_settings_pressed() -> void:
    _log("settings pressed")
    show_not_available()

func _on_map_debug_pressed() -> void:
    _log("map debug pressed")
    Net.run_mode = ""
    if MAP_DEBUG_SCREEN_SCRIPT == null:
        return
    var debug_screen: Control = MAP_DEBUG_SCREEN_SCRIPT.new()
    if debug_screen == null:
        return
    App.goto_scene_instance(debug_screen)

func _on_language_pressed() -> void:
    _log("language pressed")
    I18N.toggle_language()

func _on_quit_pressed() -> void:
    _log("quit pressed")
    get_tree().quit()

func _on_host_pressed() -> void:
    _log("host pressed")
    Net.run_mode = "host"
    World.prepare_and_generate_map(Net.run_mode, null, true)
    App.goto_scene("res://ui/MapSetupScreen.tscn")

func _on_join_pressed() -> void:
    _log("join pressed")
    if join_address_panel.visible:
        var address := join_address_input.text.strip_edges()
        join_address_panel.visible = false
        Net.start_join(address)
    else:
        multiplayer_menu.visible = false
        join_address_panel.visible = true
        join_address_input.text = ""
        join_address_input.grab_focus()

func _on_back_pressed() -> void:
    _log("back pressed")
    join_address_panel.visible = false
    multiplayer_menu.visible = false
    main_menu.visible = true
    not_available_panel.visible = false
    main_menu.get_node("Multiplayer").grab_focus()

func _on_join_cancel_pressed() -> void:
    _log("join cancel pressed")
    join_address_panel.visible = false
    join_address_input.text = ""
    multiplayer_menu.visible = true
    multiplayer_menu.get_node("Join").grab_focus()

func show_not_available() -> void:
    _log("show_not_available")
    not_available_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if join_address_panel.visible:
            _on_join_cancel_pressed()
        elif multiplayer_menu.visible:
            _on_back_pressed()

func _on_net_state_changed(state: String) -> void:
    _log("Net state changed to %s" % state)
    if state == Net.STATE_MENU:
        main_menu.visible = true
        multiplayer_menu.visible = false
        join_address_panel.visible = false
        main_menu.get_node("Multiplayer").grab_focus()
    elif state == Net.STATE_READY:
        main_menu.visible = false
        multiplayer_menu.visible = false
        join_address_panel.visible = false
        not_available_panel.visible = false
        App.goto_scene("res://scenes/Game.tscn")
    else:
        main_menu.visible = false
        multiplayer_menu.visible = false
        join_address_panel.visible = false
        not_available_panel.visible = false

func _should_drive_ci_singleplayer() -> bool:
    return OS.has_environment(CI_AUTO_SINGLEPLAYER_ENV) or OS.has_environment(CI_AUTO_QUIT_ENV)

func _ci_drive_to_singleplayer() -> void:
    await get_tree().process_frame
    if not is_inside_tree():
        return
    _log("CI auto flow: enter single player")
    _on_single_player_pressed()

func _should_quit_after_ci_flow() -> bool:
    if not _should_drive_ci_singleplayer():
        return false
    return _ci_has_driven_singleplayer

func _schedule_ci_quit() -> void:
    if _ci_quit_scheduled:
        return
    _ci_quit_scheduled = true
    call_deferred("_ci_quit_after_ci_flow")

func _ci_quit_after_ci_flow() -> void:
    await get_tree().process_frame
    if not is_inside_tree():
        return
    _log("CI auto flow: quit after map setup preview")
    get_tree().quit()
