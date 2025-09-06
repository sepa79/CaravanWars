extends Node

const Logger = preload("res://scripts/Logger.gd")

const UI_ROOT_PATH := "/root/Game/UI" # <- wpisz ścieżkę do swojego Control z całym UI
const BASE_VP := Vector2i(1920, 1080)
const MIN_FONT_SCALE := 0.85
const MAX_FONT_SCALE := 1.75

signal window_scaled(scale: float)

func _ready() -> void:
    var win := get_window()
    win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
    win.content_scale_size = BASE_VP
    win.size = Vector2i(1920, 1080)
    win.min_size = Vector2i(1024, 576)
    win.mode = Window.MODE_WINDOWED
    win.borderless = false
    Logger.log("UiManager", "init, window: %s" % [str(win.size)])
    win.size_changed.connect(_on_window_resized)
    _on_window_resized()

func _on_window_resized() -> void:
    var win := get_window()
    var scale := clampf(float(win.size.y) / float(BASE_VP.y), MIN_FONT_SCALE, MAX_FONT_SCALE)
    Logger.log("UiManager", "resized: %s scale: %f" % [str(win.size), scale])
    _apply_font_and_ui_scale(scale)
    emit_signal("window_scaled", scale)

func _apply_font_and_ui_scale(scale: float) -> void:
    var theme := get_tree().root.theme
    if theme:
        Logger.log("UiManager", "theme.default_font_size = %d" % theme.default_font_size)
    var ui := get_node_or_null(UI_ROOT_PATH)
    if ui and ui is CanvasItem:
        Logger.log("UiManager", "ui scale target: %s" % ui.name)

func toggle_fullscreen() -> void:
    var win := get_window()
    if win.mode != Window.MODE_FULLSCREEN:
        win.mode = Window.MODE_FULLSCREEN
        Logger.log("UiManager", "fullscreen ON")
    else:
        win.mode = Window.MODE_WINDOWED
        Logger.log("UiManager", "fullscreen OFF")

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_fullscreen"):
        Logger.log("UiManager", "F11")
        toggle_fullscreen()
