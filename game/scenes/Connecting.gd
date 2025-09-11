extends Control

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var retry_button: Button = $Panel/VBoxContainer/Buttons/Retry
@onready var cancel_button: Button = $Panel/VBoxContainer/Buttons/Cancel

func _log(msg: String) -> void:
    print("[Connecting] %s" % msg)

func _ready() -> void:
    I18N.language_changed.connect(_update_texts)
    Net.state_changed.connect(_on_net_state_changed)
    _update_texts()
    _on_net_state_changed(Net.state)
    _log("ready")

func _update_texts() -> void:
    retry_button.text = I18N.t("common.retry")
    cancel_button.text = I18N.t("common.cancel")
    _update_status()

func _on_net_state_changed(state: String) -> void:
    _log("Net state changed to %s" % state)
    var should_show := state in [
        Net.STATE_CONNECTING_STARTING_HOST,
        Net.STATE_CONNECTING_JOINING_HOST,
        Net.STATE_CONNECTING_RETRYING,
        Net.STATE_FAILED,
    ]
    visible = should_show
    _update_status()

func _update_status() -> void:
    match Net.state:
        Net.STATE_CONNECTING_STARTING_HOST:
            status_label.text = I18N.t("net.hosting_session")
            retry_button.visible = false
            retry_button.disabled = true
        Net.STATE_CONNECTING_JOINING_HOST:
            status_label.text = I18N.t("net.connecting")
            retry_button.visible = false
            retry_button.disabled = true
        Net.STATE_CONNECTING_RETRYING:
            status_label.text = I18N.t("net.retrying")
            retry_button.visible = false
            retry_button.disabled = true
        Net.STATE_FAILED:
            status_label.text = I18N.t(Net.fail_reason)
            retry_button.visible = true
            retry_button.disabled = false
        _:
            status_label.text = ""
            retry_button.visible = false
            retry_button.disabled = true

func _on_retry_pressed() -> void:
    _log("retry pressed")
    Net.retry()

func _on_cancel_pressed() -> void:
    _log("cancel pressed")
    Net.reset()
