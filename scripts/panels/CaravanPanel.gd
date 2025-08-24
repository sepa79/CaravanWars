extends VBoxContainer
signal ask_ai_pressed(player_id:int)

@onready var target_label: Label = $Target
@onready var ask_ai_btn: Button = $AskAI

var selected_target: String = ""

func set_target(name:String):
	selected_target = name
	target_label.text = "Target: " + name

func _ready():
	ask_ai_btn.pressed.connect(func(): emit_signal("ask_ai_pressed", PlayerMgr.local_player_id))
