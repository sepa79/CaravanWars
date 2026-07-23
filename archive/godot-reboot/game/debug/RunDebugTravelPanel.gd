extends SceneTree

const DEBUG_TRAVEL_PANEL_SCRIPT: GDScript = preload("res://debug/DebugTravelPanel.gd")
const LOCAL_GAME_BOOTSTRAP_SCRIPT: GDScript = preload("res://simulation/LocalGameBootstrap.gd")


func _initialize() -> void:
    root.title = "CaravanWars Reboot - Debug Travel Panel"

    var panel: Control = DEBUG_TRAVEL_PANEL_SCRIPT.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.bind_server(LOCAL_GAME_BOOTSTRAP_SCRIPT.create_local_server())
    root.add_child(panel)
