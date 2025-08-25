extends Node

const UI_ROOT_PATH := "/root/Game/UI" # <- wpisz ścieżkę do swojego Control z całym UI
const BASE_VP := Vector2i(1280, 720)
const MIN_FONT_SCALE := 0.85
const MAX_FONT_SCALE := 1.75

signal window_scaled(scale: float)

func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = BASE_VP
	win.size = Vector2i(1280, 720)
	win.min_size = Vector2i(1024, 576)
	win.mode = Window.MODE_WINDOWED
	win.borderless = false
	print("[UiManager] init, window:", win.size)
	win.size_changed.connect(_on_window_resized)
	_on_window_resized()

func _on_window_resized() -> void:
	var win := get_window()
	var scale := clampf(float(win.size.y) / float(BASE_VP.y), MIN_FONT_SCALE, MAX_FONT_SCALE)
	print("[UiManager] resized:", win.size, " scale:", scale)
	_apply_font_and_ui_scale(scale)
	emit_signal("window_scaled", scale)

func _apply_font_and_ui_scale(scale: float) -> void:
	var theme := get_tree().root.theme
	if theme:
		theme.default_font_size = int(round(18.0 * scale))
		print("[UiManager] theme.default_font_size =", theme.default_font_size)
	var ui := get_node_or_null(UI_ROOT_PATH)
	if ui and ui is CanvasItem:
		(ui as CanvasItem).scale = Vector2(scale, scale)
		print("[UiManager] ui scale set on:", ui.name)

func toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode != Window.MODE_FULLSCREEN:
		win.mode = Window.MODE_FULLSCREEN
		print("[UiManager] fullscreen ON")
	else:
		win.mode = Window.MODE_WINDOWED
		print("[UiManager] fullscreen OFF")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_fullscreen"):
		print("[UiManager] F11")
		toggle_fullscreen()
