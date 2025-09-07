extends Node

static func _static_init() -> void:
    print("Module Logger loaded")

static func _srv() -> Node:
    var loop := Engine.get_main_loop()
    if loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("Server")
    return null

static func log(module: String, msg: String) -> void:
    var text := "[%s] %s" % [module, msg]
    print(text)
    var s := _srv()
    if s != null:
        s.call_deferred("broadcast_log", text)
