class_name WorldMemoryHttpTransport
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
var max_poll_iterations: int = 200


func configure(new_host: String, new_port: int, new_path: String, new_use_tls: bool = false) -> void:
    host = new_host
    port = new_port
    path = new_path
    use_tls = new_use_tls


func send_domain_event(payload: Dictionary) -> Dictionary:
    if payload.is_empty():
        return _failed(ERROR_EMPTY_PAYLOAD, "WorldMemory payload is empty.")

    var http_client: HTTPClient = HTTPClient.new()
    http_client.set_blocking_mode(false)
    var connect_error: int = OK
    if use_tls:
        connect_error = http_client.connect_to_host(host, port, TLSOptions.client())
    else:
        connect_error = http_client.connect_to_host(host, port)
    if connect_error != OK:
        return _failed(ERROR_CONNECT_FAILED, "Could not connect to WorldMemory: %s." % connect_error)

    var connect_result: Dictionary = _poll_until_connected(http_client)
    if not bool(connect_result.get("accepted", false)):
        return connect_result

    var request_body: String = JSON.stringify(payload)
    var request_error: int = http_client.request(
        HTTPClient.METHOD_POST,
        path,
        ["Content-Type: application/json"],
        request_body
    )
    if request_error != OK:
        return _failed(ERROR_REQUEST_FAILED, "WorldMemory request failed: %s." % request_error)

    var response_result: Dictionary = _poll_until_response(http_client)
    http_client.close()
    return response_result


func _poll_until_connected(http_client: HTTPClient) -> Dictionary:
    for _index: int in range(max_poll_iterations):
        http_client.poll()
        var status: int = http_client.get_status()
        if status == HTTPClient.STATUS_CONNECTED:
            return {"accepted": true}
        if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE:
            return _failed(ERROR_CONNECT_FAILED, "WorldMemory connection failed with status %s." % status)

    return _failed(ERROR_CONNECT_TIMEOUT, "WorldMemory connection timed out.")


func _poll_until_response(http_client: HTTPClient) -> Dictionary:
    var response_body: PackedByteArray = PackedByteArray()
    var idle_body_polls: int = 0
    for _index: int in range(max_poll_iterations):
        http_client.poll()
        var status: int = http_client.get_status()
        if status == HTTPClient.STATUS_BODY:
            var chunk: PackedByteArray = http_client.read_response_body_chunk()
            if chunk.size() > 0:
                response_body.append_array(chunk)
                idle_body_polls = 0
            else:
                idle_body_polls += 1

            var response_length: int = http_client.get_response_body_length()
            if response_length >= 0 and response_body.size() >= response_length:
                return _response_result(http_client.get_response_code(), response_body.get_string_from_utf8())
            if response_length < 0 and idle_body_polls >= 5:
                return _response_result(http_client.get_response_code(), response_body.get_string_from_utf8())
        if status == HTTPClient.STATUS_CONNECTED:
            return _response_result(http_client.get_response_code(), response_body.get_string_from_utf8())
        if status == HTTPClient.STATUS_CONNECTION_ERROR:
            return _failed(ERROR_REQUEST_FAILED, "WorldMemory connection failed during response.")

    return _failed(ERROR_RESPONSE_TIMEOUT, "WorldMemory response timed out.")


func _response_result(status_code: int, response_body: String) -> Dictionary:
    if status_code >= 200 and status_code < 300:
        return {
            "accepted": true,
            "status_code": status_code,
            "response_body": response_body
        }

    return {
        "accepted": false,
        "error_code": ERROR_HTTP_STATUS,
        "message": "WorldMemory returned HTTP status %s." % status_code,
        "status_code": status_code,
        "response_body": response_body
    }


func _failed(error_code: String, message: String) -> Dictionary:
    return {
        "accepted": false,
        "error_code": error_code,
        "message": message
    }
