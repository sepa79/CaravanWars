extends Node2D

@export var base_world_size: Vector2 = Vector2(1920, 1080)
@export_range(0.25, 4.0, 0.01) var zoom: float = 1.0
@export var fit_mode: String = "fit_height" # "fit_height" | "fit_width" | "none"

func _ready() -> void:
	var win := get_window()
	if win:
		win.size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var win := get_window()
	if not win:
		return
	var sx := float(win.size.x) / base_world_size.x
	var sy := float(win.size.y) / base_world_size.y
	var s := 1.0
	if fit_mode == "fit_height":
		s = sy
	elif fit_mode == "fit_width":
		s = sx
	elif fit_mode == "none":
		s = 1.0
	scale = Vector2(s * zoom, s * zoom)
