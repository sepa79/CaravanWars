extends HBoxContainer

@onready var player_sel: OptionButton = $PlayerColumn/PlayerSel
@onready var player_info: RichTextLabel = $PlayerColumn/PlayerInfo
@onready var loc_sel: OptionButton = $LocationColumn/LocationSel
@onready var loc_info: RichTextLabel = $LocationColumn/LocationInfo

func _ready() -> void:
	player_sel.item_selected.connect(_on_player_selected)
	loc_sel.item_selected.connect(_on_location_selected)
	WorldViewModel.player_changed.connect(_update_player_info)
	WorldViewModel.location_changed.connect(_update_location_info)
	_populate_selectors()
	_update_player_info(WorldViewModel.get_selected_player())
	_update_location_info(WorldViewModel.get_selected_location())

func _populate_selectors() -> void:
	player_sel.clear()
	for p in WorldViewModel.get_players():
		player_sel.add_item(p["name"])
	player_sel.select(-1)

	loc_sel.clear()
	for l in WorldViewModel.get_locations():
		loc_sel.add_item(l["name"])
	loc_sel.select(-1)

func _on_player_selected(index: int) -> void:
	WorldViewModel.set_player(index)

func _on_location_selected(index: int) -> void:
	WorldViewModel.set_location(index)

func _update_player_info(player: Dictionary) -> void:
	if player.is_empty():
		player_info.bbcode_text = tr("No player selected")
	else:
		player_info.bbcode_text = "[b]%s[/b]\n%s" % [player.get("name", ""), player.get("info", "")]

func _update_location_info(loc: Dictionary) -> void:
	if loc.is_empty():
		loc_info.bbcode_text = tr("No location selected")
	else:
		loc_info.bbcode_text = "[b]%s[/b]\n%s" % [loc.get("name", ""), loc.get("info", "")]
