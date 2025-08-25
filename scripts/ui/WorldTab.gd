extends VBoxContainer

@onready var player_sel: OptionButton = $PlayerSel/Select
@onready var player_info: RichTextLabel = $PlayerInfo
@onready var loc_sel: OptionButton = $LocationSel/Select
@onready var loc_info: RichTextLabel = $LocationInfo

func _ready() -> void:
        var c = get_theme_color("font_color", "Label")
        player_info.add_theme_color_override("default_color", c)
        loc_info.add_theme_color_override("default_color", c)
        var paper := get_theme_stylebox("panel", "Panel").duplicate()
        for b in [player_sel, loc_sel]:
                b.add_theme_stylebox_override("normal", paper)
                b.add_theme_stylebox_override("hover", paper)
                b.add_theme_stylebox_override("pressed", paper)
                b.add_theme_stylebox_override("focus", paper)
                for col in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
                        b.add_theme_color_override(col, c)
                        b.get_popup().add_theme_color_override(col, c)
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
                return
        var text := "[b]%s[/b]\n%s\n\n%s: %d\n%s:\n" % [
                player.get("name", ""),
                player.get("info", ""),
                tr("Gold"),
                player.get("gold", 0),
                tr("Goods")
        ]
        var cargo: Dictionary = player.get("cargo", {})
        if cargo.is_empty():
                text += "-\n"
        else:
                for g in cargo.keys():
                        text += " - %s: %d\n" % [g, cargo[g]]
        player_info.bbcode_text = text

func _update_location_info(loc: Dictionary) -> void:
        if loc.is_empty():
                loc_info.bbcode_text = tr("No location selected")
                return
        var text := "[b]%s[/b]\n%s\n\n%s:\n" % [
                loc.get("name", ""),
                loc.get("info", ""),
                tr("Goods")
        ]
        var goods: Dictionary = loc.get("goods", {})
        if goods.is_empty():
                text += "-\n"
        else:
                for g in goods.keys():
                        var data: Dictionary = goods[g]
                        text += " - %s: %d (%s %d)\n" % [g, data.get("qty", 0), tr("Price"), data.get("price", 0)]
        loc_info.bbcode_text = text
