using Godot;
using System;
using Godot.Collections;

public partial class Sim : Node
{
    public Dictionary price = new Dictionary();
    public Array caravans = new Array();
    public int tick_count = 0;

    public override void _Ready()
    {
        GD.Randomize();
        foreach (string loc in DB.locations.Keys)
        {
            price[loc] = new Dictionary();
            var pd = price[loc] as Dictionary;
            foreach (int g in DB.goods_base_price.Keys)
            {
                pd[g] = DB.goods_base_price[g];
            }
        }
    }

    public void Tick()
    {
        tick_count += 1;
        if (tick_count % 3 == 0)
            TickEconomy();
    }

    public void TickEconomy()
    {
        foreach (string loc in DB.locations.Keys)
        {
            var market = DB.locations[loc] as Dictionary;
            var st = market["stock"] as Dictionary;
            var dm = market.ContainsKey("demand") ? market["demand"] as Dictionary : new Dictionary();
            foreach (int g in DB.goods_base_price.Keys)
            {
                int basePrice = Convert.ToInt32(DB.goods_base_price[g]);
                float s = st.ContainsKey(g) ? Convert.ToSingle(st[g]) : 0f;
                float d = dm.ContainsKey(g) ? Convert.ToSingle(dm[g]) : 1f;
                float factor = Mathf.Clamp(d * (1.5f - Math.Min(s, 100f) / 200f), 0.5f, 2.0f);
                ((Dictionary)price[loc])[g] = Mathf.RoundToInt(basePrice * factor);
            }
        }
    }

    public void AdvancePlayers(float delta)
    {
        foreach (int id in PlayerMgr.order)
        {
            var p = PlayerMgr.players[id] as Dictionary;
            if (!p.ContainsKey("moving") || !(bool)p["moving"])
                continue;
            float etaLeft = Convert.ToSingle(p["eta_left"]);
            etaLeft = Math.Max(0.0f, etaLeft - delta);
            p["eta_left"] = etaLeft;
            float totalEta = Math.Max(0.001f, Convert.ToSingle(p["eta_total"]));
            float traveled = Convert.ToSingle(p["eta_total"]) - etaLeft;
            p["progress"] = Mathf.Clamp(traveled / totalEta, 0.0f, 1.0f);
            if (etaLeft <= 0.0f)
            {
                p["moving"] = false;
                p["loc"] = p["to"];
                p.Remove("from");
                p.Remove("to");
                p["progress"] = 0.0f;
                Commander.EmitSignal(Commander.SignalName.Log,
                    string.Format(Tr("[{0}] arrived at {1}."),
                        p["name"], DB.GetLocName(p["loc"].ToString())));
            }
        }
    }
}
