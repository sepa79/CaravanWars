extends VBoxContainer
class_name WorldTab

@onready var loc_sel:OptionButton = OptionButton.new()
@onready var info_label:RichTextLabel = RichTextLabel.new()

func _ready() -> void:
    loc_sel.item_selected.connect(_on_loc_selected)
    add_child(loc_sel)
    add_child(info_label)
    info_label.set_anchors_and_margins_preset(Control.PRESET_FULL_RECT)
    info_label.text = tr("No location selected")

func set_locations(names:Array) -> void:
    loc_sel.clear()
    for n in names:
        loc_sel.add_item(n)
    if loc_sel.item_count > 0:
        loc_sel.select(0)
        _on_loc_selected(0)

func _on_loc_selected(index:int) -> void:
    var name = loc_sel.get_item_text(index)
    info_label.text = tr("Status for {name}").format({"name": name})
