extends Node

func _ready() -> void:
    pass

func goto_scene(path: String) -> void:
    get_tree().change_scene_to_file(path)

func goto_scene_instance(root: Node) -> void:
    if root == null:
        return
    var tree: SceneTree = get_tree()
    var current: Node = tree.current_scene
    if current != null:
        current.queue_free()
    tree.root.add_child(root)
    root.owner = tree.root
    tree.current_scene = root

