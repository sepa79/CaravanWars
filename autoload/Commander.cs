using Godot;
using System;
using Godot.Collections;

public partial class Commander : Node
{
    public static Commander Instance { get; private set; }

    [Signal]
    public delegate void LogEventHandler(string msg);

    public override void _Ready()
    {
        Instance = this;
    }

    public void CmdMove(string arg)
    {
        string code;
        if (!string.IsNullOrWhiteSpace(arg))
            code = arg.Trim().ToUpper();
        else
            code = "HARBOR";

        if (!DB.positions.ContainsKey(code))
        {
            EmitSignal(SignalName.Log, "[color=red]Unknown code:[/color] " + code);
            return;
        }

        int pid = PlayerMgr.local_player_id;
        if (PlayerMgr.StartTravel(pid, code))
            EmitSignal(SignalName.Log, "Moving to " + DB.GetLocName(code));
    }

    public void CmdPrice(string arg)
    {
        string code = arg.Trim().ToUpper();
        if (!DB.locations.ContainsKey(code))
        {
            EmitSignal(SignalName.Log, "[color=red]Unknown market code:[/color] " + code);
            return;
        }
        EmitSignal(SignalName.Log, "Prices at " + DB.GetLocName(code));
        // TODO: print specific prices
    }

    public bool Buy(int pid, int good, int amount)
    {
        if (!PlayerMgr.players.ContainsKey(pid))
            return false;
        var p = PlayerMgr.players[pid] as Dictionary;
        if (p.ContainsKey("moving") && (bool)p["moving"])
            return false;

        string loc = p.ContainsKey("loc") ? p["loc"].ToString() : "";
        var market = DB.locations.ContainsKey(loc) ? DB.locations[loc] as Dictionary : new Dictionary();
        var stock = market.ContainsKey("stock") ? market["stock"] as Dictionary : new Dictionary();
        int available = stock.ContainsKey(good) ? Convert.ToInt32(stock[good]) : 0;
        if (available < amount)
        {
            EmitSignal(SignalName.Log, Tr("[color=red]Not enough goods in stock.[/color]"));
            return false;
        }

        var priceDict = Sim.price.ContainsKey(loc) ? Sim.price[loc] as Dictionary : new Dictionary();
        int price = priceDict.ContainsKey(good) ? Convert.ToInt32(priceDict[good]) : 0;
        int cost = price * amount;
        int gold = p.ContainsKey("gold") ? Convert.ToInt32(p["gold"]) : 0;
        if (gold < cost)
        {
            EmitSignal(SignalName.Log, Tr("[color=red]Not enough gold.[/color]"));
            return false;
        }
        if (PlayerMgr.CargoFree(pid) < amount)
        {
            EmitSignal(SignalName.Log, Tr("[color=red]Not enough cargo space.[/color]"));
            return false;
        }
        p["gold"] = gold - cost;
        var cargo = p["cargo"] as Dictionary;
        int current = cargo.ContainsKey(good) ? Convert.ToInt32(cargo[good]) : 0;
        cargo[good] = current + amount;
        stock[good] = available - amount;

        string goodName = DB.goods_names.ContainsKey(good) ? DB.goods_names[good].ToString() : good.ToString();
        EmitSignal(SignalName.Log, string.Format(Tr("[{0}] bought {1} {2} for {3}."),
            p["name"], amount, Tr(goodName), cost));
        return true;
    }

    public bool Sell(int pid, int good, int amount)
    {
        if (!PlayerMgr.players.ContainsKey(pid))
            return false;
        var p = PlayerMgr.players[pid] as Dictionary;
        if (p.ContainsKey("moving") && (bool)p["moving"])
            return false;

        var cargo = p.ContainsKey("cargo") ? p["cargo"] as Dictionary : new Dictionary();
        int have = cargo.ContainsKey(good) ? Convert.ToInt32(cargo[good]) : 0;
        if (have < amount)
        {
            EmitSignal(SignalName.Log, Tr("[color=red]Not enough goods to sell.[/color]"));
            return false;
        }
        string loc = p.ContainsKey("loc") ? p["loc"].ToString() : "";
        var priceDict = Sim.price.ContainsKey(loc) ? Sim.price[loc] as Dictionary : new Dictionary();
        int price = priceDict.ContainsKey(good) ? Convert.ToInt32(priceDict[good]) : 0;
        int revenue = price * amount;
        p["gold"] = Convert.ToInt32(p["gold"]) + revenue;
        cargo[good] = have - amount;
        if (Convert.ToInt32(cargo[good]) <= 0)
            cargo.Remove(good);
        var market = DB.locations.ContainsKey(loc) ? DB.locations[loc] as Dictionary : new Dictionary();
        var stock = market.ContainsKey("stock") ? market["stock"] as Dictionary : new Dictionary();
        int stockHave = stock.ContainsKey(good) ? Convert.ToInt32(stock[good]) : 0;
        stock[good] = stockHave + amount;

        string goodName = DB.goods_names.ContainsKey(good) ? DB.goods_names[good].ToString() : good.ToString();
        EmitSignal(SignalName.Log, string.Format(Tr("[{0}] sold {1} {2} for {3}."),
            p["name"], amount, Tr(goodName), revenue));
        return true;
    }
}
