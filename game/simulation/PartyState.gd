class_name PartyState
extends RefCounted

const PARTY_COMPOSITION_SCRIPT: GDScript = preload("res://simulation/PartyComposition.gd")
const PARTY_KNOWLEDGE_STATE_SCRIPT: GDScript = preload("res://simulation/PartyKnowledgeState.gd")
const PARTY_ORDER_STATE_SCRIPT: GDScript = preload("res://simulation/PartyOrderState.gd")
const PARTY_TASK_STATE_SCRIPT: GDScript = preload("res://simulation/PartyTaskState.gd")

const TRAVEL_STATE_IDLE: String = "idle"
const TRAVEL_STATE_TRAVELING: String = "traveling"

var party_id: String = ""
var party_type: String = ""
var manager_actor_id: String = ""
var authorized_issuer_actor_ids: Array[String] = []
var current_node_id: String = ""
var travel_state: String = TRAVEL_STATE_IDLE
var origin_node_id: String = ""
var destination_node_id: String = ""
var travel_progress_km: float = 0.0
var travel_distance_km: float = 0.0
var travel_speed_km_per_day: float = 0.0
var travel_intent_destination_node_id: String = ""
var travel_path_node_ids: Array[String] = []
var travel_path_edge_ids: Array[String] = []
var travel_path_index: int = 0
var composition: RefCounted = PARTY_COMPOSITION_SCRIPT.new()
var cargo: Dictionary[String, int] = {}
var knowledge: RefCounted = PARTY_KNOWLEDGE_STATE_SCRIPT.new()
var order: RefCounted = PARTY_ORDER_STATE_SCRIPT.new()
var task: RefCounted = PARTY_TASK_STATE_SCRIPT.new()
var actor_tasks_by_actor_id: Dictionary[String, RefCounted] = {}


func is_idle() -> bool:
    return travel_state == TRAVEL_STATE_IDLE and task.is_idle() and not has_active_party_lock_actor_task()


func can_receive_order_from(actor_id: String) -> bool:
    return actor_id == manager_actor_id or authorized_issuer_actor_ids.has(actor_id)


func set_actor_task(actor_task: RefCounted) -> void:
    actor_tasks_by_actor_id[actor_task.actor_id] = actor_task


func has_actor_task(actor_id: String) -> bool:
    return actor_tasks_by_actor_id.has(actor_id)


func get_actor_task(actor_id: String) -> RefCounted:
    return actor_tasks_by_actor_id.get(actor_id)


func has_active_actor_task(actor_id: String) -> bool:
    if not actor_tasks_by_actor_id.has(actor_id):
        return false
    var actor_task: RefCounted = actor_tasks_by_actor_id.get(actor_id)
    return not actor_task.is_idle()


func has_active_party_lock_actor_task() -> bool:
    for actor_task: RefCounted in actor_tasks_by_actor_id.values():
        if actor_task.requires_party_lock and not actor_task.is_idle():
            return true
    return false


func to_actor_task_dictionaries() -> Array[Dictionary]:
    var actor_ids: Array[String] = actor_tasks_by_actor_id.keys()
    actor_ids.sort()

    var actor_tasks: Array[Dictionary] = []
    for actor_id: String in actor_ids:
        var actor_task: RefCounted = actor_tasks_by_actor_id.get(actor_id)
        actor_tasks.append(actor_task.to_dictionary())
    return actor_tasks


func start_travel(origin_id: String, destination_id: String, distance_km: float, speed_km_per_day: float) -> void:
    travel_state = TRAVEL_STATE_TRAVELING
    origin_node_id = origin_id
    destination_node_id = destination_id
    travel_distance_km = distance_km
    travel_speed_km_per_day = speed_km_per_day
    travel_progress_km = 0.0


func set_travel_plan(intent_destination_node_id: String, path_node_ids: Array[String], path_edge_ids: Array[String]) -> void:
    travel_intent_destination_node_id = intent_destination_node_id
    travel_path_node_ids = path_node_ids.duplicate()
    travel_path_edge_ids = path_edge_ids.duplicate()
    travel_path_index = 0


func clear_travel_plan() -> void:
    travel_intent_destination_node_id = ""
    travel_path_node_ids.clear()
    travel_path_edge_ids.clear()
    travel_path_index = 0


func tick_travel(days: float) -> void:
    if travel_state != TRAVEL_STATE_TRAVELING:
        return

    travel_progress_km += travel_speed_km_per_day * days
    if travel_progress_km >= travel_distance_km:
        current_node_id = destination_node_id
        travel_state = TRAVEL_STATE_IDLE
        origin_node_id = ""
        destination_node_id = ""
        travel_progress_km = 0.0
        travel_distance_km = 0.0
        travel_speed_km_per_day = 0.0


func to_dictionary() -> Dictionary:
    return {
        "party_id": party_id,
        "party_type": party_type,
        "manager_actor_id": manager_actor_id,
        "authorized_issuer_actor_ids": authorized_issuer_actor_ids.duplicate(),
        "current_node_id": current_node_id,
        "travel_state": travel_state,
        "origin_node_id": origin_node_id,
        "destination_node_id": destination_node_id,
        "travel_progress_km": travel_progress_km,
        "travel_distance_km": travel_distance_km,
        "travel_speed_km_per_day": travel_speed_km_per_day,
        "travel_intent_destination_node_id": travel_intent_destination_node_id,
        "travel_path_node_ids": travel_path_node_ids,
        "travel_path_edge_ids": travel_path_edge_ids,
        "travel_path_index": travel_path_index,
        "composition": composition.to_dictionary(),
        "cargo": cargo.duplicate(),
        "knowledge": knowledge.to_dictionary(),
        "order": order.to_dictionary(),
        "task": task.to_dictionary(),
        "actor_tasks": to_actor_task_dictionaries()
    }
