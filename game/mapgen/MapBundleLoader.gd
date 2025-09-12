extends RefCounted
class_name MapBundleLoader

const SchemaPath := "res://mapgen/MapBundle_Schema.json"
const MapNodeModule = preload("res://mapview/MapNode.gd")
const EdgeModule = preload("res://mapview/Edge.gd")
const RegionModule = preload("res://mapview/Region.gd")

func load(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Failed to open %s" % path)
        return {}
    var text := file.get_as_text()
    file.close()
    var data = JSON.parse_string(text)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid JSON in %s" % path)
        return {}
    var bundle: Dictionary = data
    if not _validate(bundle):
        push_error("Schema validation failed for %s" % path)
        return {}
    return _convert(bundle)

func _validate(bundle: Dictionary) -> bool:
    var schema_file := FileAccess.open(SchemaPath, FileAccess.READ)
    if schema_file:
        var schema_data = JSON.parse_string(schema_file.get_as_text())
        schema_file.close()
        if typeof(schema_data) == TYPE_DICTIONARY:
            var required: Array = schema_data.get("required", [])
            for key in required:
                if not bundle.has(key):
                    push_warning("Missing key %s" % key)
                    return false
            var meta_schema: Dictionary = schema_data.get("properties", {}).get("meta", {})
            var meta_required: Array = meta_schema.get("required", [])
            var meta: Dictionary = bundle.get("meta", {})
            for key in meta_required:
                if not meta.has(key):
                    push_warning("Missing meta.%s" % key)
                    return false
            return true
    # Fallback basic check
    var fallback := ["meta", "nodes", "edges", "cities", "villages", "crossings", "forts", "kingdoms", "climate_cells"]
    for key in fallback:
        if not bundle.has(key):
            push_warning("Missing key %s" % key)
            return false
    return bundle.get("meta", {}).has("version") and bundle.get("meta", {}).has("seed") and bundle.get("meta", {}).has("map_size")

func _convert(bundle: Dictionary) -> Dictionary:
    var map: Dictionary = {}
    var meta: Dictionary = bundle.get("meta", {})
    map["meta"] = meta
    var size: float = float(meta.get("map_size", 100))
    map["width"] = size
    map["height"] = size
    var nodes: Dictionary = {}
    for n in bundle.get("nodes", []):
        var id: int = int(n.get("id"))
        var pos := Vector2(n.get("x", 0.0), n.get("y", 0.0))
        nodes[id] = MapNodeModule.new(id, MapNodeModule.TYPE_CROSSROAD, pos, {})
    var cities: Array = []
    var capitals: Array[int] = []
    for c in bundle.get("cities", []):
        var id: int = int(c.get("id"))
        var pos := Vector2(c.get("x", 0.0), c.get("y", 0.0))
        var attrs: Dictionary = {
            "kingdom_id": c.get("kingdom_id", 0),
            "is_capital": c.get("is_capital", false),
        }
        nodes[id] = MapNodeModule.new(id, MapNodeModule.TYPE_CITY, pos, attrs)
        var city_index: int = cities.size()
        cities.append(pos)
        if attrs.get("is_capital", false):
            capitals.append(city_index)
    for v in bundle.get("villages", []):
        var id: int = int(v.get("id"))
        var pos := Vector2(v.get("x", 0.0), v.get("y", 0.0))
        nodes[id] = MapNodeModule.new(id, MapNodeModule.TYPE_VILLAGE, pos, {"city_id": v.get("city_id", 0), "road_node_id": v.get("road_node_id", 0), "production": v.get("production", {})})
    for cr in bundle.get("crossings", []):
        var id: int = int(cr.get("id"))
        var pos := Vector2(cr.get("x", 0.0), cr.get("y", 0.0))
        var ntype := MapNodeModule.TYPE_BRIDGE if cr.get("type", "bridge") == "bridge" else MapNodeModule.TYPE_FORD
        nodes[id] = MapNodeModule.new(id, ntype, pos, {"river_id": cr.get("river_id", null)})
    for f in bundle.get("forts", []):
        var id: int = int(f.get("id"))
        var pos := Vector2(f.get("x", 0.0), f.get("y", 0.0))
        nodes[id] = MapNodeModule.new(id, MapNodeModule.TYPE_FORT, pos, {"edge_id": f.get("edge_id", null), "crossing_id": f.get("crossing_id", null), "pair_id": f.get("pair_id", null)})
    var edges: Dictionary = {}
    for e in bundle.get("edges", []):
        var a: int = int(e.get("a"))
        var b: int = int(e.get("b"))
        var node_a = nodes.get(a)
        var node_b = nodes.get(b)
        if node_a == null or node_b == null:
            push_warning("Edge %s references missing node %s or %s" % [e.get("id"), a, b])
            continue
        var poly: Array[Vector2] = [node_a.pos2d, node_b.pos2d]
        var cls: String = String(e.get("class", "Road")).to_lower()
        var attrs: Dictionary = {}
        if e.has("crossing_id") and e.get("crossing_id") != null:
            attrs["crossing_id"] = e.get("crossing_id")
        var endpoints: Array[int] = [a, b]
        edges[int(e.get("id"))] = EdgeModule.new(int(e.get("id")), "road", poly, endpoints, cls, attrs)

    var max_node_id: int = 0
    for nid in nodes.keys():
        if nid > max_node_id:
            max_node_id = nid
    var max_edge_id: int = 0
    for eid in edges.keys():
        if eid > max_edge_id:
            max_edge_id = eid

    map["roads"] = {
        "nodes": nodes,
        "edges": edges,
        "next_node_id": max_node_id + 1,
        "next_edge_id": max_edge_id + 1,
    }
    map["cities"] = cities
    map["capitals"] = capitals
    var rivers: Array = []
    for r in bundle.get("rivers", []):
        var poly: Array = []
        for p in r.get("polyline", []):
            poly.append(Vector2(p[0], p[1]))
        rivers.append(poly)
    map["rivers"] = rivers
    var regions: Dictionary = {}
    var kingdom_names: Dictionary = {}
    var kingdom_capitals: Dictionary = {}
    for k in bundle.get("kingdoms", []):
        var poly: Array[Vector2] = []
        for p in k.get("polygon", []):
            poly.append(Vector2(p[0], p[1]))
        var rid: int = int(k.get("id"))
        var kid: int = int(k.get("kingdom_id", rid))
        var region := RegionModule.new(rid, poly, "", kid)
        regions[region.id] = region
        var name: String = String(k.get("name", "Kingdom %d" % kid))
        if name.is_empty():
            name = "Kingdom %d" % kid
        kingdom_names[kid] = name
        kingdom_capitals[kid] = int(k.get("capital_city_id", 0))
    map["regions"] = regions
    map["kingdom_names"] = kingdom_names
    map["kingdom_capitals"] = kingdom_capitals
    return map
