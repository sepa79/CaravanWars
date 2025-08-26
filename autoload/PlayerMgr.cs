using Godot;
using System;
using Godot.Collections;
using GodotArray = Godot.Collections.Array;

public partial class PlayerMgr : Node
{
    public enum Kind { HUMAN, AI, NARRATOR }

    public static Dictionary players = new Dictionary();
    public static GodotArray order = new GodotArray();
    public static int local_player_id = 1;

    public override void _Ready()
    {
        AddPlayer(1, "Player A", (int)Kind.HUMAN, "CENTRAL_KEEP");
        AddPlayer(2, "Player B", (int)Kind.HUMAN, "HARBOR");
        AddPlayer(101, "Guild AI", (int)Kind.AI, "MINE");
        order = new GodotArray { 1, 2, 101 };
    }

    public static void AddPlayer(int id, string name, int kind, string startLoc)
    {
        players[id] = new Dictionary
        {
            {"name", name},
            {"kind", kind},
            {"loc", startLoc},
            {"gold", 150},
            {"units", new GodotArray { "hand_cart" }},
            {"cargo", new Dictionary()},
            {"moving", false},
            {"progress", 0.0 }
        };
    }

    public static bool IsMoving(int id)
    {
        if (!players.ContainsKey(id))
            return false;
        var p = players[id] as Dictionary;
        return p.ContainsKey("moving") && (bool)p["moving"];
    }

    public static float CalcSpeed(int id)
    {
        var p = players[id] as Dictionary;
        var defs = DB.unit_defs;
        float sp = 9999.0f;
        var units = p["units"] as GodotArray;
        foreach (var uObj in units)
        {
            string u = uObj.ToString();
            if (!defs.ContainsKey(u))
                continue;
            var d = defs[u] as Dictionary;
            float speed = d.ContainsKey("speed") ? Convert.ToSingle(d["speed"]) : 1.0f;
            sp = Math.Min(sp, speed);
        }
        if (sp == 9999.0f)
            sp = 1.0f;
        return sp;
    }

    public static int CapacityTotal(int id)
    {
        var p = players[id] as Dictionary;
        var defs = DB.unit_defs;
        int cap = 0;
        var units = p["units"] as GodotArray;
        foreach (var uObj in units)
        {
            string u = uObj.ToString();
            if (!defs.ContainsKey(u))
                continue;
            var d = defs[u] as Dictionary;
            cap += d.ContainsKey("capacity") ? Convert.ToInt32(d["capacity"]) : 0;
        }
        return cap;
    }

    public static int CargoUsed(int id)
    {
        var p = players[id] as Dictionary;
        int used = 0;
        var cargo = p["cargo"] as Dictionary;
        foreach (var key in cargo.Keys)
        {
            used += Convert.ToInt32(cargo[key]);
        }
        return used;
    }

    public static int CargoFree(int id)
    {
        return Math.Max(0, CapacityTotal(id) - CargoUsed(id));
    }

    public static bool StartTravel(int id, string toLoc)
    {
        var p = players[id] as Dictionary;
        if (p.ContainsKey("moving") && (bool)p["moving"])
            return false;
        string fromLoc = p["loc"].ToString();
        if (fromLoc == toLoc)
            return false;
        string key = $"{fromLoc}->{toLoc}";
        if (!DB.routes.ContainsKey(key))
            return false;
        int baseTicks = Convert.ToInt32((DB.routes[key] as Dictionary)["ticks"]) * 5;
        float speed = Math.Max(0.1f, CalcSpeed(id));
        float eta = baseTicks / speed;
        p["moving"] = true;
        p["from"] = fromLoc;
        p["to"] = toLoc;
        p["eta_left"] = eta;
        p["eta_total"] = eta;
        p["progress"] = 0.0f;
        Commander.Instance.EmitSignal(Commander.SignalName.Log,
            string.Format("[{0}] traveling {1} -> {2} (ETA {3:0.0}).",
                p["name"], DB.GetLocName(fromLoc), DB.GetLocName(toLoc), eta));
        return true;
    }
}
