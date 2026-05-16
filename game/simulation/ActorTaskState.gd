class_name ActorTaskState
extends RefCounted

const TASK_TYPE_IDLE: String = "idle"
const TASK_TYPE_ASK_LOCAL_INFORMATION: String = "ask_local_information"
const TASK_TYPE_REPORT_BACK: String = "report_back"

const STATUS_NONE: String = "none"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_FAILED: String = "failed"

var actor_id: String = ""
var task_type: String = TASK_TYPE_IDLE
var status: String = STATUS_NONE
var party_id: String = ""
var location_id: String = ""
var query_type: String = ""
var goods_id: String = ""
var recipient_actor_id: String = ""
var recipient_owner_kind: String = "actor"
var max_entries: int = 0
var trust: float = 1.0
var distortion_noise: float = 0.0
var listener_interest_tags: Array[String] = []
var notes: String = ""
var requires_party_lock: bool = false
var remaining_days: float = 0.0
var total_days: float = 0.0
var started_day: float = 0.0
var issuer_actor_id: String = ""
var failure_code: String = ""
var failure_message: String = ""


func is_idle() -> bool:
    return task_type == TASK_TYPE_IDLE or status == STATUS_NONE or status == STATUS_COMPLETED or status == STATUS_FAILED


func start_ask_local_information(new_actor_id: String, new_party_id: String, new_location_id: String, new_query_type: String, new_goods_id: String, duration_days: float, new_started_day: float, new_issuer_actor_id: String, new_requires_party_lock: bool) -> void:
    actor_id = new_actor_id
    task_type = TASK_TYPE_ASK_LOCAL_INFORMATION
    status = STATUS_ACTIVE
    party_id = new_party_id
    location_id = new_location_id
    query_type = new_query_type
    goods_id = new_goods_id
    requires_party_lock = new_requires_party_lock
    remaining_days = duration_days
    total_days = duration_days
    started_day = new_started_day
    issuer_actor_id = new_issuer_actor_id
    failure_code = ""
    failure_message = ""


func start_report_back(new_actor_id: String, new_party_id: String, new_location_id: String, new_recipient_actor_id: String, new_recipient_owner_kind: String, new_max_entries: int, new_trust: float, new_distortion_noise: float, new_listener_interest_tags: Array[String], new_notes: String, duration_days: float, new_started_day: float, new_issuer_actor_id: String, new_requires_party_lock: bool) -> void:
    actor_id = new_actor_id
    task_type = TASK_TYPE_REPORT_BACK
    status = STATUS_ACTIVE
    party_id = new_party_id
    location_id = new_location_id
    query_type = ""
    goods_id = ""
    recipient_actor_id = new_recipient_actor_id
    recipient_owner_kind = new_recipient_owner_kind
    max_entries = new_max_entries
    trust = new_trust
    distortion_noise = new_distortion_noise
    listener_interest_tags = new_listener_interest_tags.duplicate()
    notes = new_notes
    requires_party_lock = new_requires_party_lock
    remaining_days = duration_days
    total_days = duration_days
    started_day = new_started_day
    issuer_actor_id = new_issuer_actor_id
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
    actor_id = ""
    task_type = TASK_TYPE_IDLE
    status = STATUS_NONE
    party_id = ""
    location_id = ""
    query_type = ""
    goods_id = ""
    recipient_actor_id = ""
    recipient_owner_kind = "actor"
    max_entries = 0
    trust = 1.0
    distortion_noise = 0.0
    listener_interest_tags.clear()
    notes = ""
    requires_party_lock = false
    remaining_days = 0.0
    total_days = 0.0
    started_day = 0.0
    issuer_actor_id = ""
    failure_code = ""
    failure_message = ""


func to_dictionary() -> Dictionary:
    return {
        "actor_id": actor_id,
        "task_type": task_type,
        "status": status,
        "party_id": party_id,
        "location_id": location_id,
        "query_type": query_type,
        "goods_id": goods_id,
        "recipient_actor_id": recipient_actor_id,
        "recipient_owner_kind": recipient_owner_kind,
        "max_entries": max_entries,
        "trust": trust,
        "distortion_noise": distortion_noise,
        "listener_interest_tags": listener_interest_tags.duplicate(),
        "notes": notes,
        "requires_party_lock": requires_party_lock,
        "remaining_days": remaining_days,
        "total_days": total_days,
        "started_day": started_day,
        "issuer_actor_id": issuer_actor_id,
        "failure_code": failure_code,
        "failure_message": failure_message
    }


static func from_dictionary(task_dictionary: Dictionary) -> RefCounted:
    var task: RefCounted = new()
    task.actor_id = str(task_dictionary.get("actor_id", ""))
    task.task_type = str(task_dictionary.get("task_type", TASK_TYPE_IDLE))
    task.status = str(task_dictionary.get("status", STATUS_NONE))
    task.party_id = str(task_dictionary.get("party_id", ""))
    task.location_id = str(task_dictionary.get("location_id", ""))
    task.query_type = str(task_dictionary.get("query_type", ""))
    task.goods_id = str(task_dictionary.get("goods_id", ""))
    task.recipient_actor_id = str(task_dictionary.get("recipient_actor_id", ""))
    task.recipient_owner_kind = str(task_dictionary.get("recipient_owner_kind", "actor"))
    task.max_entries = int(task_dictionary.get("max_entries", 0))
    task.trust = float(task_dictionary.get("trust", 1.0))
    task.distortion_noise = float(task_dictionary.get("distortion_noise", 0.0))
    task.listener_interest_tags = _string_array_from_variant(task_dictionary.get("listener_interest_tags", []))
    task.notes = str(task_dictionary.get("notes", ""))
    task.requires_party_lock = bool(task_dictionary.get("requires_party_lock", false))
    task.remaining_days = float(task_dictionary.get("remaining_days", 0.0))
    task.total_days = float(task_dictionary.get("total_days", 0.0))
    task.started_day = float(task_dictionary.get("started_day", 0.0))
    task.issuer_actor_id = str(task_dictionary.get("issuer_actor_id", ""))
    task.failure_code = str(task_dictionary.get("failure_code", ""))
    task.failure_message = str(task_dictionary.get("failure_message", ""))
    return task


static func _string_array_from_variant(value: Variant) -> Array[String]:
    var strings: Array[String] = []
    if typeof(value) != TYPE_ARRAY:
        return strings

    for item: Variant in value:
        strings.append(str(item))
    return strings
