extends Control

var tick_label: Label
var loc_label: Label
var speed_label: Label
var cargo_label: Label
var econ_label: Label
var _labels: Array = []
var _base_font_size = 16

func _ready() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(vbox)

	tick_label = Label.new()
	loc_label = Label.new()
	speed_label = Label.new()
	cargo_label = Label.new()
	econ_label = Label.new()

	_labels = [tick_label, loc_label, speed_label, cargo_label, econ_label]
	for l in _labels:
		vbox.add_child(l)

	if UiManager.has_signal("window_scaled"):
		UiManager.window_scaled.connect(_on_window_scaled)
	_on_window_scaled(1.0)

	if Sim.has_signal("player_arrived"):
		Sim.player_arrived.connect(_on_player_arrived)
	if PlayerMgr.has_signal("player_changed"):
		PlayerMgr.player_changed.connect(_on_player_changed)
	elif WorldViewModel.has_signal("player_changed"):
		WorldViewModel.player_changed.connect(func(_d): _on_player_changed())

	refresh()

func refresh() -> void:
	var pid = PlayerMgr.local_player_id
	var p = PlayerMgr.players.get(pid, {})

	tick_label.text = "Tick: %d" % Sim.tick_count
	econ_label.text = "Econ tick: %d" % Sim.econ_every_n_ticks
	loc_label.text = "Loc: %s" % DB.get_loc_name(p.get("loc", ""))
	speed_label.text = "Speed: %s" % str(PlayerMgr.calc_speed(pid))
	var used = PlayerMgr.cargo_used(pid)
	var total = PlayerMgr.capacity_total(pid)
	cargo_label.text = "Cargo: %d/%d" % [used, total]

func _on_player_arrived(_id: int, _loc: String) -> void:
	refresh()

func _on_player_changed(_data = null) -> void:
	refresh()

func _on_window_scaled(scale: float) -> void:
	var size = int(_base_font_size * scale)
	for l in _labels:
		l.add_theme_font_size_override("font_size", size)
