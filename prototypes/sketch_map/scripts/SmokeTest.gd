extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed: PackedScene = load("res://SketchMapDemo.tscn")
    if packed == null:
        push_error("SketchMapDemo.tscn did not load.")
        quit(1)
        return

    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame

    var canvas: Node = scene.find_child("sketch_map_canvas", true, false)
    if canvas == null:
        push_error("Sketch map canvas was not created.")
        quit(1)
        return

    var symbol_textures: Dictionary = canvas.get("_symbol_textures")
    if symbol_textures.size() < 6:
        push_error("Sketch map symbol set did not load enough textures.")
        quit(1)
        return

    print("Sketch map smoke OK")
    quit(0)
