extends Control
class_name Hud

@onready var label:Label = Label.new()

func _ready() -> void:
    add_child(label)
    label.text = "No observation"

func show_observation(obs:Dictionary) -> void:
    label.text = JSON.stringify(obs, "\t")

func _input(event:InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_N:
        visible = not visible
