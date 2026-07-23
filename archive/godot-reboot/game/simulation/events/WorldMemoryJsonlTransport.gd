class_name WorldMemoryJsonlTransport
extends RefCounted

const ERROR_PATH_NOT_CONFIGURED: String = "path_not_configured"
const ERROR_OPEN_FAILED: String = "open_failed"

var output_path: String = ""


func configure(new_output_path: String) -> void:
    output_path = new_output_path


func send_domain_event(payload: Dictionary) -> Dictionary:
    if output_path.is_empty():
        return _failed(ERROR_PATH_NOT_CONFIGURED, "WorldMemory JSONL output path is not configured.")

    var output_file: FileAccess = FileAccess.open(output_path, FileAccess.READ_WRITE)
    if output_file == null:
        output_file = FileAccess.open(output_path, FileAccess.WRITE)
    if output_file == null:
        return _failed(ERROR_OPEN_FAILED, "Could not open WorldMemory JSONL output path: %s." % output_path)

    output_file.seek_end()
    output_file.store_line(JSON.stringify(payload))
    output_file.close()
    return {"accepted": true}


func _failed(error_code: String, message: String) -> Dictionary:
    return {
        "accepted": false,
        "error_code": error_code,
        "message": message
    }
