extends Control

@onready var title_label: Label = $Title
@onready var main_menu: VBoxContainer = $MainMenu
@onready var multiplayer_menu: VBoxContainer = $MultiplayerMenu
@onready var not_available_panel: Panel = $NotAvailable
@onready var not_available_label: Label = $NotAvailable/Label
@onready var version_label: Label = $Version
@onready var connecting_ui: Control = preload("res://scenes/Connecting.tscn").instantiate()

func _ready() -> void:
    I18N.language_changed.connect(update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    add_child(connecting_ui)
    update_texts()

func update_texts() -> void:
    title_label.text = I18N.t("menu.title")
    main_menu.get_node("SinglePlayer").text = I18N.t("menu.start_single")
    main_menu.get_node("Multiplayer").text = I18N.t("menu.start_multi")
    main_menu.get_node("Settings").text = I18N.t("menu.settings")
    var lang_text := I18N.t("menu.language_en") if I18N.current_lang == I18N.LANG_EN else I18N.t("menu.language_pl")
    main_menu.get_node("Language").text = "%s: %s" % [I18N.t("menu.language"), lang_text]
    main_menu.get_node("Quit").text = I18N.t("menu.quit")
    multiplayer_menu.get_node("Host").text = I18N.t("menu.host")
    multiplayer_menu.get_node("Join").text = I18N.t("menu.join")
    multiplayer_menu.get_node("Back").text = I18N.t("menu.back")
    not_available_label.text = I18N.t("menu.not_available")
    var build_type := "Debug" if OS.is_debug_build() else "Release"
    version_label.text = "%s %s\n%s %s" % [I18N.t("menu.version"), ProjectSettings.get_setting("application/config/version"), I18N.t("menu.build_type"), build_type]

func _on_single_player_pressed() -> void:
    Net.start_singleplayer()

func _on_multiplayer_pressed() -> void:
    main_menu.visible = false
    multiplayer_menu.visible = true
    not_available_panel.visible = false
    multiplayer_menu.get_node("Host").grab_focus()

func _on_settings_pressed() -> void:
    show_not_available()

func _on_language_pressed() -> void:
    I18N.toggle_language()

func _on_quit_pressed() -> void:
    get_tree().quit()

func _on_host_pressed() -> void:
    Net.start_host()

func _on_join_pressed() -> void:
    Net.start_join("")

func _on_back_pressed() -> void:
    multiplayer_menu.visible = false
    main_menu.visible = true
    not_available_panel.visible = false
    main_menu.get_node("Multiplayer").grab_focus()

func show_not_available() -> void:
    not_available_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and multiplayer_menu.visible:
        _on_back_pressed()

func _on_net_state_changed(state: String) -> void:
    if state == Net.STATE_MENU:
        main_menu.visible = true
        multiplayer_menu.visible = false
    else:
        main_menu.visible = false
        multiplayer_menu.visible = false
        not_available_panel.visible = false
