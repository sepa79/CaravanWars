extends VBoxContainer
signal buy_request(good:int, amount:int)
signal sell_request(good:int, amount:int)

@onready var grid: GridContainer = $Grid

func _ready():
	populate()

func populate():
	for c in grid.get_children():
		c.queue_free()
	grid.columns = 6

	var h = ["Good","Price","City stock","You","Qty","Action"]
	for i in h:
		var l = Label.new(); l.text = i; grid.add_child(l)

	var pid = PlayerMgr.local_player_id
	var p = PlayerMgr.players[pid]
	var loc = p["loc"]
	var moving = p.get("moving", false)

	for g in DB.goods_base_price.keys():
		var name = DB.goods_names[g]
		var price = Sim.price[loc][g]
		var city_stock = DB.locations[loc]["stock"].get(g, 0)
		var you_have = p["cargo"].get(g, 0)

		var l1 = Label.new(); l1.text = name; grid.add_child(l1)
		var l2 = Label.new(); l2.text = str(price); grid.add_child(l2)
		var l3 = Label.new(); l3.text = str(city_stock); grid.add_child(l3)
		var l4 = Label.new(); l4.text = str(you_have); grid.add_child(l4)

		var qty = SpinBox.new(); qty.min_value = 1; qty.max_value = 999; qty.step = 1; grid.add_child(qty)

		var hb = HBoxContainer.new()
		var b_buy = Button.new(); b_buy.text = "Buy"; b_buy.disabled = moving
		var b_sell = Button.new(); b_sell.text = "Sell"; b_sell.disabled = moving
		hb.add_child(b_buy); hb.add_child(b_sell)
		grid.add_child(hb)

		b_buy.pressed.connect(func(): emit_signal("buy_request", g, int(qty.value)))
		b_sell.pressed.connect(func(): emit_signal("sell_request", g, int(qty.value)))
