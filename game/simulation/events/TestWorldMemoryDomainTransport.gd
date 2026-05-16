class_name TestWorldMemoryDomainTransport
extends RefCounted

var sent_payloads: Array[Dictionary] = []
var fail_next_send: bool = false


func send_domain_event(payload: Dictionary) -> Dictionary:
    sent_payloads.append(payload.duplicate(true))
    if fail_next_send:
        fail_next_send = false
        return {
            "accepted": false,
            "error_code": "test_transport_failed",
            "message": "Test transport failure."
        }

    return {
        "accepted": true,
        "status_code": 200,
        "response_body": "{}"
    }
