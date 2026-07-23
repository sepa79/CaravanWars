class_name CommandResult
extends RefCounted

const ERROR_NONE: String = ""

var accepted: bool = false
var error_code: String = ERROR_NONE
var message: String = ""
var details: Dictionary = {}


static func accepted_result() -> RefCounted:
    var result: RefCounted = new()
    result.accepted = true
    return result


static func rejected_result(result_error_code: String, result_message: String) -> RefCounted:
    var result: RefCounted = new()
    result.accepted = false
    result.error_code = result_error_code
    result.message = result_message
    return result
