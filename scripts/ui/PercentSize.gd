extends Control
@tool

@export_range(0.0, 1.0, 0.01) var percent_width: float  = 0.85
@export_range(0.0, 1.0, 0.01) var percent_height: float = 0.85
@export_range(0.0, 1.0, 0.01) var anchor_left: float = 0.075
@export_range(0.0, 1.0, 0.01) var anchor_top: float  = 0.075
@export var keep_centered: bool = true

func _ready() -> void:
	_apply_percent_size()
	var win := get_window()
	if win:
		win.size_changed.connect(_apply_percent_size)

func _apply_percent_size() -> void:
	var left := anchor_left
	var top := anchor_top
	var right := left + percent_width
	var bottom := top + percent_height
	if keep_centered:
		left = (1.0 - percent_width) * 0.5
		right = left + percent_width
		top = (1.0 - percent_height) * 0.5
		bottom = top + percent_height
	anchor_left = clampf(left, 0.0, 1.0)
	anchor_top = clampf(top, 0.0, 1.0)
	anchor_right = clampf(right, 0.0, 1.0)
	anchor_bottom = clampf(bottom, 0.0, 1.0)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
