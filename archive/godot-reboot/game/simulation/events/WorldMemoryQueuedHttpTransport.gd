class_name WorldMemoryQueuedHttpTransport
extends RefCounted

const ERROR_EMPTY_PAYLOAD: String = "empty_payload"
const ERROR_CONNECT_FAILED: String = "connect_failed"
const ERROR_CONNECT_TIMEOUT: String = "connect_timeout"
const ERROR_REQUEST_FAILED: String = "request_failed"
const ERROR_RESPONSE_TIMEOUT: String = "response_timeout"
const ERROR_HTTP_STATUS: String = "http_status"

var host: String = "127.0.0.1"
var port: int = 8011
var path: String = "/domain-events/ingest"
var use_tls: bool = false
var max_poll_iterations_per_request: int = 300
var max_steps_per_process: int = 20

var queued_payloads: Array[Dictionary] = []
var completed_results: Array[Dictionary] = []
var failed_results: Array[Dictionary] = []

var _active_client: HTTPClient = null
var _active_payload: Dictionary = {}
var _active_state: String = ""
var _active_response_body: PackedByteArray = PackedByteArray()
var _active_idle_body_polls: int = 0
var _active_poll_count: int = 0


func configure(new_host: String, new_port: int, new_path: String, new_use_tls: bool = false) -> void:
    host = new_host
    port = new_port
    path = new_path
    use_tls = new_use_tls


func send_domain_event(payload: Dictionary) -> Dictionary:
    if payload.is_empty():
        return _failed(ERROR_EMPTY_PAYLOAD, "WorldMemory payload is empty.")

    queued_payloads.append(payload.duplicate(true))
    return {
        "accepted": true,
        "queued": true
    }


func process_queue() -> void:
    for _step: int in range(max_steps_per_process):
        if _active_client == null:
            if queued_payloads.is_empty():
                return
            _start_next_request()

        if _active_client == null:
            continue

        _active_poll_count += 1
        if _active_poll_count > max_poll_iterations_per_request:
            _finish_failed(ERROR_RESPONSE_TIMEOUT, "WorldMemory queued request timed out.")
            continue

        _active_client.poll()
        if _active_state == "connecting":
            _process_connecting()
        elif _active_state == "receiving":
            _process_receiving()


func has_pending_work() -> bool:
    return not queued_payloads.is_empty() or _active_client != null


func has_failures() -> bool:
    return not failed_results.is_empty()


func _start_next_request() -> void:
    _active_payload = queued_payloads.pop_front()
    _active_client = HTTPClient.new()
    _active_client.set_blocking_mode(false)
    _active_response_body = PackedByteArray()
    _active_idle_body_polls = 0
    _active_poll_count = 0
    _active_state = "connecting"

    var connect_error: int = OK
    if use_tls:
        connect_error = _active_client.connect_to_host(host, port, TLSOptions.client())
    else:
        connect_error = _active_client.connect_to_host(host, port)
    if connect_error != OK:
        _finish_failed(ERROR_CONNECT_FAILED, "Could not connect to WorldMemory: %s." % connect_error)


func _process_connecting() -> void:
    var status: int = _active_client.get_status()
    if status == HTTPClient.STATUS_CONNECTED:
        var request_error: int = _active_client.request(
            HTTPClient.METHOD_POST,
            path,
            ["Content-Type: application/json"],
            JSON.stringify(_active_payload)
        )
        if request_error != OK:
            _finish_failed(ERROR_REQUEST_FAILED, "WorldMemory request failed: %s." % request_error)
            return
        _active_state = "receiving"
        return

    if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE:
        _finish_failed(ERROR_CONNECT_FAILED, "WorldMemory connection failed with status %s." % status)
        return

    if status == HTTPClient.STATUS_DISCONNECTED:
        _finish_failed(ERROR_CONNECT_TIMEOUT, "WorldMemory disconnected before request.")


func _process_receiving() -> void:
    var status: int = _active_client.get_status()
    if status == HTTPClient.STATUS_BODY:
        var chunk: PackedByteArray = _active_client.read_response_body_chunk()
        if chunk.size() > 0:
            _active_response_body.append_array(chunk)
            _active_idle_body_polls = 0
        else:
            _active_idle_body_polls += 1

        var response_length: int = _active_client.get_response_body_length()
        if response_length >= 0 and _active_response_body.size() >= response_length:
            _finish_response()
        elif response_length < 0 and _active_idle_body_polls >= 5:
            _finish_response()
        return

    if status == HTTPClient.STATUS_CONNECTED:
        var response_code: int = _active_client.get_response_code()
        if response_code > 0:
            _finish_response()
        return

    if status == HTTPClient.STATUS_DISCONNECTED:
        var disconnected_response_code: int = _active_client.get_response_code()
        if disconnected_response_code > 0:
            _finish_response()
        else:
            _finish_failed(ERROR_REQUEST_FAILED, "WorldMemory disconnected before response.")
        return

    if status == HTTPClient.STATUS_CONNECTION_ERROR:
        _finish_failed(ERROR_REQUEST_FAILED, "WorldMemory connection failed during response.")


func _finish_response() -> void:
    var status_code: int = _active_client.get_response_code()
    var response_body: String = _active_response_body.get_string_from_utf8()
    var result: Dictionary = {
        "accepted": status_code >= 200 and status_code < 300,
        "status_code": status_code,
        "response_body": response_body,
        "world_event_id": _world_event_id(_active_payload)
    }

    if bool(result.get("accepted", false)):
        completed_results.append(result)
    else:
        result["error_code"] = ERROR_HTTP_STATUS
        result["message"] = "WorldMemory returned HTTP status %s." % status_code
        failed_results.append(result)

    _clear_active_request()


func _finish_failed(error_code: String, message: String) -> void:
    failed_results.append({
        "accepted": false,
        "error_code": error_code,
        "message": message,
        "world_event_id": _world_event_id(_active_payload)
    })
    _clear_active_request()


func _clear_active_request() -> void:
    if _active_client != null:
        _active_client.close()
    _active_client = null
    _active_payload = {}
    _active_state = ""
    _active_response_body = PackedByteArray()
    _active_idle_body_polls = 0
    _active_poll_count = 0


func _world_event_id(payload: Dictionary) -> String:
    var world_event: Dictionary = payload.get("world_event", {})
    return str(world_event.get("id", ""))


func _failed(error_code: String, message: String) -> Dictionary:
    return {
        "accepted": false,
        "error_code": error_code,
        "message": message
    }
