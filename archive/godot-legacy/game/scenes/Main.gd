extends Node2D

func _ready() -> void:
    call_deferred("_load_start_menu")

func _load_start_menu() -> void:
    App.goto_scene("res://scenes/StartMenu.tscn")
