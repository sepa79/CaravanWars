extends Node

func _ready() -> void:
    pass

func goto_scene(path: String) -> void:
    get_tree().change_scene_to_file(path)

