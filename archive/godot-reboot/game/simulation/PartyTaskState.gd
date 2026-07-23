class_name PartyTaskState
extends RefCounted

const TASK_TYPE_IDLE: String = "idle"
const TASK_TYPE_ASK_LOCAL_INFORMATION: String = "ask_local_information"

const STATUS_NONE: String = "none"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_FAILED: String = "failed"

var task_type: String = TASK_TYPE_IDLE
var status: String = STATUS_NONE
var location_id: String = ""
var query_type: String = ""
var goods_id: String = ""
var remaining_days: float = 0.0
var total_days: float = 0.0
var failure_code: String = ""
var failure_message: String = ""


func is_idle() -> bool:
    return task_type == TASK_TYPE_IDLE or status == STATUS_NONE or status == STATUS_COMPLETED or status == STATUS_FAILED


func start_ask_local_information(new_location_id: String, new_query_type: String, new_goods_id: String, duration_days: float) -> void:
    task_type = TASK_TYPE_ASK_LOCAL_INFORMATION
    status = STATUS_ACTIVE
    location_id = new_location_id
    query_type = new_query_type
    goods_id = new_goods_id
    remaining_days = duration_days
    total_days = duration_days
    failure_code = ""
    failure_message = ""


func tick(days: float) -> void:
    if status != STATUS_ACTIVE:
        return
    remaining_days = maxf(0.0, remaining_days - days)


func mark_completed() -> void:
    status = STATUS_COMPLETED
    remaining_days = 0.0
    failure_code = ""
    failure_message = ""


func mark_failed(new_failure_code: String, new_failure_message: String) -> void:
    status = STATUS_FAILED
    remaining_days = 0.0
    failure_code = new_failure_code
    failure_message = new_failure_message


func clear() -> void:
    task_type = TASK_TYPE_IDLE
    status = STATUS_NONE
    location_id = ""
    query_type = ""
    goods_id = ""
    remaining_days = 0.0
    total_days = 0.0
    failure_code = ""
    failure_message = ""


func to_dictionary() -> Dictionary:
    return {
        "task_type": task_type,
        "status": status,
        "location_id": location_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "remaining_days": remaining_days,
        "total_days": total_days,
        "failure_code": failure_code,
        "failure_message": failure_message
    }


static func from_dictionary(task_dictionary: Dictionary) -> RefCounted:
    var task: RefCounted = new()
    task.task_type = str(task_dictionary.get("task_type", TASK_TYPE_IDLE))
    task.status = str(task_dictionary.get("status", STATUS_NONE))
    task.location_id = str(task_dictionary.get("location_id", ""))
    task.query_type = str(task_dictionary.get("query_type", ""))
    task.goods_id = str(task_dictionary.get("goods_id", ""))
    task.remaining_days = float(task_dictionary.get("remaining_days", 0.0))
    task.total_days = float(task_dictionary.get("total_days", 0.0))
    task.failure_code = str(task_dictionary.get("failure_code", ""))
    task.failure_message = str(task_dictionary.get("failure_message", ""))
    return task
