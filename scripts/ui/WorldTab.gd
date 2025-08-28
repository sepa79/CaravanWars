extends VBoxContainer

var players_tree: Tree
var markets_tree: Tree
var _last_sig: String = ""
var _legend_label: Label
var _goods_ids: Array = []

func _ready() -> void:
	# Wyczyść istniejące dzieci sceny WorldTab i zbuduj prosty UI od zera
	for c in get_children():
		c.queue_free()

	var players_label := Label.new()
	players_label.text = tr("Players")
	add_child(players_label)

	players_tree = Tree.new()
	players_tree.columns = 3
	players_tree.set_column_titles_visible(true)
	players_tree.set_column_title(0, tr("Player"))
	players_tree.set_column_title(1, tr("Gold"))
	players_tree.set_column_title(2, tr("Goods"))
	players_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_tree.custom_minimum_size = Vector2(0, 150)
	add_child(players_tree)

	var markets_label := Label.new()
	markets_label.text = tr("Markets")
	add_child(markets_label)

	markets_tree = Tree.new()
	markets_tree.set_column_titles_visible(true)
	markets_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	markets_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	markets_tree.custom_minimum_size = Vector2(0, 300)
	add_child(markets_tree)

	# Przygotuj kolumny rynku (Lokacja + kolumny per towar ID)
	_goods_ids = DB.goods_base_price.keys()
	_goods_ids.sort()
	_update_markets_columns()

	# Legenda pod tabelą: mapowanie ID -> nazwa towaru
	_legend_label = Label.new()
	add_child(_legend_label)
	_update_legend()

	# Reaguj na zdarzenia ViewModelu
	WorldViewModel.data_changed.connect(_refresh)

	# Dodatkowy bezpiecznik: periodyczne sprawdzenie zmian stanu
	var t := Timer.new()
	t.wait_time = 0.5
	t.one_shot = false
	t.autostart = true
	t.timeout.connect(_check_and_refresh)
	add_child(t)
	# Na start wypełnij danymi
	_refresh()

func _refresh() -> void:
	_populate_players()
	_update_markets_columns()
	_update_legend()
	_populate_markets()
	_last_sig = _signature()

func _populate_players() -> void:
	if players_tree == null:
		return
	players_tree.clear()
	var root = players_tree.create_item()
	var players: Array = WorldViewModel.get_players()
	# Posortuj po id dla stabilności
	players.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for p in players:
		var total_goods := 0
		for v in p.get("cargo", {}).values():
			total_goods += int(v)
		var it = players_tree.create_item(root)
		it.set_text(0, str(p.get("name", "")))
		it.set_text(1, str(int(p.get("gold", 0))))
		it.set_text(2, str(total_goods))

func _populate_markets() -> void:
	if markets_tree == null:
		return
	markets_tree.clear()
	var root = markets_tree.create_item()
	var locs: Array = WorldViewModel.get_locations()
	for l in locs:
		var loc_name := str(l.get("name", l.get("code", "")))
		var goods: Dictionary = l.get("goods", {})
		var it = markets_tree.create_item(root)
		it.set_text(0, loc_name)
		# Wypełnij kolumny per ID towaru: tekst "qty/price"
		for i in range(_goods_ids.size()):
			var gid = _goods_ids[i]
			var key_name := str(DB.goods_names.get(gid, gid))
			var data: Dictionary = goods.get(key_name, {})
			var qty: int = int(data.get("qty", 0))
			var price: int = int(data.get("price", 0))
			it.set_text(i + 1, "%d/%d" % [qty, price])

func _signature() -> String:
	# Zbuduj prosty podpis stanu, aby wykrywać zmiany
	var parts: Array = []
	for p in WorldViewModel.get_players():
		var total_goods := 0
		for v in p.get("cargo", {}).values():
			total_goods += int(v)
		parts.append("P:%s:%d:%d" % [str(p.get("name", "")), int(p.get("gold", 0)), total_goods])
	for l in WorldViewModel.get_locations():
		var loc_code := str(l.get("code", l.get("name", "")))
		var goods: Dictionary = l.get("goods", {})
		for gid in _goods_ids:
			var key_name := str(DB.goods_names.get(gid, gid))
			var d: Dictionary = goods.get(key_name, {})
			parts.append("L:%s:%s:%d:%d" % [loc_code, str(gid), int(d.get("qty", 0)), int(d.get("price", 0))])
	return ";".join(parts)

func _check_and_refresh() -> void:
	var sig := _signature()
	if sig != _last_sig:
		_refresh()

func _update_markets_columns() -> void:
	if markets_tree == null:
		return
	var cols := 1 + _goods_ids.size()
	markets_tree.columns = cols
	markets_tree.set_column_titles_visible(true)
	markets_tree.set_column_title(0, tr("Location"))
	for i in range(_goods_ids.size()):
		markets_tree.set_column_title(i + 1, str(_goods_ids[i]))

func _update_legend() -> void:
	if _legend_label == null:
		return
	var parts: Array = []
	for gid in _goods_ids:
		parts.append("%d=%s" % [int(gid), tr(str(DB.goods_names.get(gid, gid)))])
	_legend_label.text = tr("Legend") + ": " + ", ".join(parts)
