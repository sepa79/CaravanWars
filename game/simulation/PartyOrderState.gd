class_name PartyOrderState
extends RefCounted

const ORDER_TYPE_IDLE: String = "idle"
const ORDER_TYPE_TRAVEL_TO: String = "travel_to"
const ORDER_TYPE_PROCURE_GOODS: String = "procure_goods"

const STATUS_NONE: String = "none"
const STATUS_ASSIGNED: String = "assigned"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_FAILED: String = "failed"
const STATUS_CANCELLED: String = "cancelled"
const STATUS_INTERRUPTED: String = "interrupted"

var order_type: String = ORDER_TYPE_IDLE
var status: String = STATUS_NONE
var target_node_id: String = ""
var target_location_id: String = ""
var goods_id: String = ""
var amount: int = 0
var route_node_ids: Array[String] = []
var issued_by_actor_id: String = ""
var failure_code: String = ""
var failure_message: String = ""
var cancel_reason: String = ""
var interrupt_reason: String = ""


func is_idle() -> bool:
    return order_type == ORDER_TYPE_IDLE or status == STATUS_NONE or status == STATUS_COMPLETED or status == STATUS_FAILED or status == STATUS_CANCELLED or status == STATUS_INTERRUPTED


func assign_travel_to(new_target_node_id: String, new_issued_by_actor_id: String) -> void:
    order_type = ORDER_TYPE_TRAVEL_TO
    status = STATUS_ASSIGNED
    target_node_id = new_target_node_id
    target_location_id = ""
    goods_id = ""
    amount = 0
    route_node_ids.clear()
    issued_by_actor_id = new_issued_by_actor_id
    failure_code = ""
    failure_message = ""
    cancel_reason = ""
    interrupt_reason = ""


func assign_procure_goods(new_target_location_id: String, new_goods_id: String, new_amount: int, new_issued_by_actor_id: String) -> void:
    order_type = ORDER_TYPE_PROCURE_GOODS
    status = STATUS_ASSIGNED
    target_node_id = ""
    target_location_id = new_target_location_id
    goods_id = new_goods_id
    amount = new_amount
    route_node_ids.clear()
    issued_by_actor_id = new_issued_by_actor_id
    failure_code = ""
    failure_message = ""
    cancel_reason = ""
    interrupt_reason = ""


func mark_active() -> void:
    status = STATUS_ACTIVE


func mark_completed() -> void:
    status = STATUS_COMPLETED
    failure_code = ""
    failure_message = ""


func mark_failed(new_failure_code: String, new_failure_message: String) -> void:
    status = STATUS_FAILED
    failure_code = new_failure_code
    failure_message = new_failure_message
    cancel_reason = ""
    interrupt_reason = ""


func mark_cancelled(new_cancel_reason: String) -> void:
    status = STATUS_CANCELLED
    failure_code = ""
    failure_message = ""
    cancel_reason = new_cancel_reason
    interrupt_reason = ""


func mark_interrupted(new_interrupt_reason: String) -> void:
    status = STATUS_INTERRUPTED
    failure_code = ""
    failure_message = ""
    cancel_reason = ""
    interrupt_reason = new_interrupt_reason


func to_dictionary() -> Dictionary:
    return {
        "order_type": order_type,
        "status": status,
        "target_node_id": target_node_id,
        "target_location_id": target_location_id,
        "goods_id": goods_id,
        "amount": amount,
        "route_node_ids": route_node_ids.duplicate(),
        "issued_by_actor_id": issued_by_actor_id,
        "failure_code": failure_code,
        "failure_message": failure_message,
        "cancel_reason": cancel_reason,
        "interrupt_reason": interrupt_reason
    }


static func from_dictionary(order_dictionary: Dictionary) -> RefCounted:
    var order: RefCounted = new()
    order.order_type = str(order_dictionary.get("order_type", ORDER_TYPE_IDLE))
    order.status = str(order_dictionary.get("status", STATUS_NONE))
    order.target_node_id = str(order_dictionary.get("target_node_id", ""))
    order.target_location_id = str(order_dictionary.get("target_location_id", ""))
    order.goods_id = str(order_dictionary.get("goods_id", ""))
    order.amount = int(order_dictionary.get("amount", 0))
    order.route_node_ids = _string_array_from_variant(order_dictionary.get("route_node_ids", []))
    order.issued_by_actor_id = str(order_dictionary.get("issued_by_actor_id", ""))
    order.failure_code = str(order_dictionary.get("failure_code", ""))
    order.failure_message = str(order_dictionary.get("failure_message", ""))
    order.cancel_reason = str(order_dictionary.get("cancel_reason", ""))
    order.interrupt_reason = str(order_dictionary.get("interrupt_reason", ""))
    return order


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
