extends VBoxContainer

signal buy_request(good: int, amount: int)
signal sell_request(good: int, amount: int)

@onready var grid: GridContainer = $Grid

func _ready() -> void:
    populate()

func populate() -> void:
    for c in grid.get_children():
        c.queue_free()

    var pid: int = PlayerMgr.local_player_id
    var p: Dictionary = PlayerMgr.players.get(pid, {})
    var moving: bool = p.get("moving", false)

    if moving:
        grid.columns = 1
        var msg := Label.new()
        msg.text = tr("Trading unavailable while traveling.")
        grid.add_child(msg)
        return

    grid.columns = 6

    var headers: Array = [tr("Good"), tr("Price"), tr("City stock"), tr("You"), tr("Qty"), tr("Action")]
    for h in headers:
        var l := Label.new()
        l.text = h
        grid.add_child(l)

    var loc: String = p.get("loc", "")
    var loc_obj = DB.get_loc(loc)
    if loc_obj == null:
        return

    # Only use data exposed by location methods
    for g in loc_obj.list_goods():
        var name: String = tr(DB.goods_names.get(g, str(g)))
        var price: int = loc_obj.get_price(g)
        var city_stock: int = loc_obj.get_stock(g)
        var you_have: int = p.get("cargo", {}).get(g, 0)

        var l1 := Label.new()
        l1.text = name
        grid.add_child(l1)
        var l2 := Label.new()
        l2.text = str(price)
        grid.add_child(l2)
        var l3 := Label.new()
        l3.text = str(city_stock)
        grid.add_child(l3)
        var l4 := Label.new()
        l4.text = str(you_have)
        grid.add_child(l4)

        var qty := SpinBox.new()
        qty.min_value = 1
        qty.max_value = 999
        qty.step = 1
        grid.add_child(qty)

        var hb := HBoxContainer.new()
        var b_buy := Button.new()
        b_buy.text = tr("Buy")
        var b_sell := Button.new()
        b_sell.text = tr("Sell")
        hb.add_child(b_buy)
        hb.add_child(b_sell)
        grid.add_child(hb)

        var good: int = g
        var qty_box := qty
        b_buy.pressed.connect(func(): emit_signal("buy_request", good, int(qty_box.value)))
        b_sell.pressed.connect(func(): emit_signal("sell_request", good, int(qty_box.value)))
