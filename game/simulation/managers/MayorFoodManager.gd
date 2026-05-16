class_name MayorFoodManager
extends RefCounted

const DECLARE_LOCATION_NEED_COMMAND_SCRIPT: GDScript = preload("res://simulation/commands/DeclareLocationNeedCommand.gd")

const FOOD_GOODS_ID: String = "food"
const DEFAULT_FOOD_FLOOR: int = 30
const DEFAULT_DESIRED_FOOD: int = 80


func process(server: RefCounted, location_id: String) -> Dictionary:
    if not server.state.has_location(location_id):
        return _no_action("location_not_found")

    var location: RefCounted = server.state.get_location(location_id)
    var current_food: int = int(location.resources.get(FOOD_GOODS_ID, 0))
    if current_food >= DEFAULT_FOOD_FLOOR:
        return _no_action("food_above_floor")

    var command: RefCounted = DECLARE_LOCATION_NEED_COMMAND_SCRIPT.new()
    command.location_id = location.location_id
    command.issued_by_actor_id = location.manager_actor_id
    command.goods_id = FOOD_GOODS_ID
    command.current_amount = current_food
    command.desired_amount = DEFAULT_DESIRED_FOOD
    command.reason = "food_below_floor"
    var result: RefCounted = server.submit_declare_location_need(command)
    if not result.accepted:
        return {
            "action": "declare_need_rejected",
            "accepted": false,
            "error_code": result.error_code,
            "message": result.message
        }

    return {
        "action": "declare_food_need",
        "accepted": true,
        "location_id": location.location_id,
        "goods_id": FOOD_GOODS_ID,
        "current_amount": current_food,
        "desired_amount": DEFAULT_DESIRED_FOOD
    }


func _no_action(reason: String) -> Dictionary:
    return {
        "action": "none",
        "accepted": true,
        "reason": reason
    }
