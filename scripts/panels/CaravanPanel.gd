extends VBoxContainer

@onready var target_label: Label = $Target
@onready var goods_label: Label = $Goods
@onready var food_label: Label = $Food
@onready var speed_label: Label = $Speed

var selected_target: String = ""

func set_target(name: String) -> void:
        selected_target = name
        target_label.text = tr("Target: {name}").format({"name": name})

func show_status(data: Dictionary) -> void:
        goods_label.text = tr("Goods: {goods}").format({"goods": str(data.get("goods", {}))})
        food_label.text = tr("Food/day: {rate}").format({"rate": str(data.get("food_rate", 0))})
        speed_label.text = tr("Speed: {value}").format({"value": str(data.get("speed", 0))})
