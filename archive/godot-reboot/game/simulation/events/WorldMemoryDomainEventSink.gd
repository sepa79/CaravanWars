class_name WorldMemoryDomainEventSink
extends RefCounted

const WORLD_MEMORY_EVENT_MAPPER_SCRIPT: GDScript = preload("res://simulation/events/WorldMemoryEventMapper.gd")

const ERROR_TRANSPORT_NOT_CONFIGURED: String = "transport_not_configured"
const ERROR_TRANSPORT_METHOD_MISSING: String = "transport_method_missing"

var transport: RefCounted = null
var exported_payloads: Array[Dictionary] = []
var failed_exports: Array[Dictionary] = []
var emit_godot_errors: bool = true


func configure(new_transport: RefCounted) -> void:
    transport = new_transport


func handle_event(simulation_event: RefCounted) -> void:
    var export_payload: Dictionary = WORLD_MEMORY_EVENT_MAPPER_SCRIPT.map_event(simulation_event)
    if export_payload.is_empty():
        return

    exported_payloads.append(export_payload.duplicate(true))
    if transport == null:
        _record_failure(export_payload, ERROR_TRANSPORT_NOT_CONFIGURED, "WorldMemory transport is not configured.")
        return

    if not transport.has_method("send_domain_event"):
        _record_failure(export_payload, ERROR_TRANSPORT_METHOD_MISSING, "WorldMemory transport does not implement send_domain_event.")
        return

    var transport_result: Dictionary = transport.send_domain_event(export_payload)
    if bool(transport_result.get("accepted", false)):
        return

    _record_failure(export_payload, str(transport_result.get("error_code", "transport_failed")), str(transport_result.get("message", "")))


func has_failures() -> bool:
    return not failed_exports.is_empty()


func _record_failure(export_payload: Dictionary, error_code: String, message: String) -> void:
    var world_event: Dictionary = export_payload.get("world_event", {})
    failed_exports.append({
        "world_event_id": str(world_event.get("id", "")),
        "event_type": str(world_event.get("event_type", "")),
        "error_code": error_code,
        "message": message
    })
    if emit_godot_errors:
        push_error("WorldMemory export failed for %s: %s" % [str(world_event.get("id", "")), error_code])
