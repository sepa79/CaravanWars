extends VBoxContainer
signal ask_ai_pressed(player_id:int)

@onready var target_label: Label = $Target
@onready var goods_label: Label = $Goods
@onready var food_label: Label = $Food
@onready var speed_label: Label = $Speed
@onready var ask_ai_btn: Button = $AskAI

var selected_target: String = ""

func set_target(target_name:String):
	selected_target = target_name
	target_label.text = tr("Target: {name}").format({"name": target_name})

func _ready():
	ask_ai_btn.pressed.connect(func(): emit_signal("ask_ai_pressed", PlayerMgr.local_player_id))

func show_status(data:Dictionary) -> void:
	goods_label.text = tr("Goods: {goods}").format({"goods": str(data.get("goods", {}))})
	food_label.text = tr("Food/day: {rate}").format({"rate": str(data.get("food_rate", 0))})
	speed_label.text = tr("Speed: {value}").format({"value": str(data.get("speed", 0))})
