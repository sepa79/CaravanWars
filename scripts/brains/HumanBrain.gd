extends IPlayerBrain
class_name HumanBrain

const Logger = preload("res://scripts/Logger.gd")

func _init() -> void:
    print("Module HumanBrain loaded")

func think(observation:Dictionary) -> Array[Dictionary]:
    Logger.log("HumanBrain", "Received observation for peer %d" % observation.get("self_id", 0))
    return []
