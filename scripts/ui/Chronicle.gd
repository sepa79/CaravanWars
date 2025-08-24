extends Control
class_name Chronicle

@onready var tabs:TabContainer = TabContainer.new()
@onready var observation_label:RichTextLabel = RichTextLabel.new()
@onready var knowledge_label:RichTextLabel = RichTextLabel.new()
@onready var log_label:RichTextLabel = RichTextLabel.new()

func _ready() -> void:
    tabs.set_anchors_and_margins_preset(Control.PRESET_FULL_RECT)
    add_child(tabs)
    var obs_panel := Control.new()
    obs_panel.name = "Observation"
    observation_label.set_anchors_and_margins_preset(Control.PRESET_FULL_RECT)
    obs_panel.add_child(observation_label)
    tabs.add_child(obs_panel)
    observation_label.text = "No observation"

    var knowledge_panel := Control.new()
    knowledge_panel.name = "Knowledge"
    knowledge_label.set_anchors_and_margins_preset(Control.PRESET_FULL_RECT)
    knowledge_panel.add_child(knowledge_label)
    tabs.add_child(knowledge_panel)
    knowledge_label.text = "No knowledge"

    var log_panel := Control.new()
    log_panel.name = "Log"
    log_label.set_anchors_and_margins_preset(Control.PRESET_FULL_RECT)
    log_panel.add_child(log_label)
    tabs.add_child(log_panel)
    log_label.text = "No events"

func show_observation(obs:Dictionary) -> void:
    observation_label.text = JSON.stringify(obs, "\t")

func show_knowledge(markets:Dictionary) -> void:
    knowledge_label.text = JSON.stringify(markets, "\t")

func add_log_entry(text:String) -> void:
    log_label.append_text(text + "\n")

func _input(event:InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_N:
        visible = not visible
