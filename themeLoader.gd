# ThemeLoader.gd
extends Node

const THEME_PATH: String = "res://themes/CaravanUI.tres"

func _ready() -> void:
	var theme := load(THEME_PATH)
	if theme is Theme:
		var root := get_tree().root # Window
		root.theme = theme
		print("[ThemeLoader] Applied theme to root window: %s" % THEME_PATH)
	else:
		push_warning("[ThemeLoader] Theme not found at %s" % THEME_PATH)
