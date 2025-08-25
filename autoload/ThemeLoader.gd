# res://autoload/ThemeLoader.gd
extends Node

@export var theme_path: String = "res://assets/ui/theme/caravan_theme.tres"
var theme: Theme

func _ready() -> void:
	load_and_apply(theme_path)

func load_and_apply(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res is Theme:
		theme = res
		var root := get_tree().root
		root.theme = theme
		_propagate_theme(root)
	else:
		push_warning("ThemeLoader: resource is not a Theme: " + path)

func _propagate_theme(node: Node) -> void:
	if node is Control and theme:
		var c := node as Control
		if c.theme != theme:
			c.theme = theme
	for child in node.get_children():
		_propagate_theme(child)

func set_default_theme(path: String) -> void:
	theme_path = path
	load_and_apply(theme_path)

func reload() -> void:
	load_and_apply(theme_path)

func set_font_size(size: int) -> void:
	if theme:
		theme.default_font_size = max(8, size)

func get_theme() -> Theme:
	return theme
