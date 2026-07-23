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

    var model: RefCounted = scene.get("model")
    if model == null or not model.get("nodes_by_id").has("wroclaw") or not model.get("nodes_by_id").has("opole"):
        push_error("Sketch map did not load the main Silesia region graph.")
        quit(1)
        return

    if model.get("terrain_areas_by_id").size() < 1 or model.get("landmarks_by_id").size() < 1:
        push_error("Sketch map did not load Silesia physical layers.")
        quit(1)
        return

    if model.get("map_terrain_areas").size() < 1 or model.get("map_landmarks").size() < 1:
        push_error("Sketch map did not observe any physical layer marks.")
        quit(1)
        return

    var has_route_geometry: bool = false
    for edge: Dictionary in model.get("edges"):
        if str(edge.get("id", "")) == "wroclaw_opole" and edge.get("route_points", []).size() == 3:
            has_route_geometry = true
            break

    if not has_route_geometry:
        push_error("Sketch map did not load Wroclaw-Opole route geometry.")
        quit(1)
        return

    print("Sketch map smoke OK")
    quit(0)
