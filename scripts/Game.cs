using Godot;
using System;
using Godot.Collections;
using GodotArray = Godot.Collections.Array;

public partial class Game : Node
{
    private const string GAME_VERSION = "0.3.3-alpha";

    private Control mapNode;
    private Button zoomInBtn;
    private Button zoomOutBtn;
    private VBoxContainer tradePanel;
    private VBoxContainer caravanPanel;
    private RichTextLabel helpBox;
    private TabContainer tab;

    private Label goldLabel;
    private Label caravansLabel;
    private Label tickLabel;
    private Label locLabel;
    private Label capLabel;
    private Label speedLabel;

    private Button pauseBtn;
    private Button playBtn;
    private Button fastBtn;

    private OptionButton langOption;

    private RichTextLabel logLabel;
    private LineEdit cmdBox;
    private Timer tickTimer;

    private float timeFactor = 1.0f;

    private string lastLoc = "";
    private Dictionary lastStock = new Dictionary();
    private bool lastMoving = false;

    private Commander commander;

    public override void _Ready()
    {
        mapNode = GetNode<Control>("UI/Main/Left/MapBox/Map");
        zoomInBtn = GetNode<Button>("UI/Main/Left/MapBox/MapControls/ZoomIn");
        zoomOutBtn = GetNode<Button>("UI/Main/Left/MapBox/MapControls/ZoomOut");
        tradePanel = GetNode<VBoxContainer>("UI/Main/Right/Tabs/Trade/TradePanel");
        caravanPanel = GetNode<VBoxContainer>("UI/Main/Right/Tabs/Caravan/CaravanPanel");
        helpBox = GetNode<RichTextLabel>("UI/Main/Right/Tabs/HelpOptions/HelpText");
        tab = GetNode<TabContainer>("UI/Main/Right/Tabs");

        goldLabel = GetNode<Label>("UI/Status/Gold");
        caravansLabel = GetNode<Label>("UI/Status/Caravans");
        tickLabel = GetNode<Label>("UI/Status/Tick");
        locLabel = GetNode<Label>("UI/Status/Loc");
        capLabel = GetNode<Label>("UI/Status/Cap");
        speedLabel = GetNode<Label>("UI/Status/Speed");

        pauseBtn = GetNode<Button>("UI/Status/PauseBtn");
        playBtn = GetNode<Button>("UI/Status/PlayBtn");
        fastBtn = GetNode<Button>("UI/Status/FastBtn");

        langOption = GetNode<OptionButton>("UI/Main/Right/Tabs/HelpOptions/Lang");

        logLabel = GetNode<RichTextLabel>("UI/Main/Right/Log");
        cmdBox = GetNode<LineEdit>("UI/Main/Right/Cmd");
        tickTimer = GetNode<Timer>("Tick");

        commander = GetNode<Commander>("/root/Commander");
        commander.Log += OnLog;
        cmdBox.TextSubmitted += OnCmd;

        tickTimer.Timeout += OnTick;
        if (mapNode.HasSignal("location_clicked"))
        {
            mapNode.Connect("location_clicked", new Callable(this, nameof(OnLocationClick)));
            zoomInBtn.Pressed += () => mapNode.Call("zoom_in");
            zoomOutBtn.Pressed += () => mapNode.Call("zoom_out");
        }

        if (tradePanel.HasSignal("buy_request"))
            tradePanel.Connect("buy_request", new Callable(this, nameof(OnBuyRequest)));
        if (tradePanel.HasSignal("sell_request"))
            tradePanel.Connect("sell_request", new Callable(this, nameof(OnSellRequest)));

        if (caravanPanel.HasSignal("ask_ai_pressed"))
            caravanPanel.Connect("ask_ai_pressed", new Callable(this, nameof(OnAskAi)));
        var wvm = GetNodeOrNull<WorldViewModel>("/root/WorldViewModel");
        if (wvm != null && wvm.HasSignal("player_changed"))
            wvm.Connect("player_changed", new Callable(this, nameof(OnPlayerChanged)));

        FillHelp();
        SetupLanguageDropdown();
        SetupTimeControls();
        SetTabTitles();
        UpdateStatus();
        mapNode.QueueRedraw();
        SetTimeFactor(timeFactor);
        SetProcess(true);
        StoreTradeState();
    }

    private void FillHelp()
    {
        string t = "";
        t += "[b]" + Tr("Caravan Wars {version}").Replace("{version}", GAME_VERSION) + "[/b]\n";
        t += Tr("• Move by clicking on the map (your caravan travels between locations).") + "\n";
        t += Tr("• Trade only in the current location.") + "\n";
        t += Tr("• Console commands (EN codes only): [code]help, info, price <CODE>, move <CODE>[/code]") + "\n";
        t += Tr("Codes: HARBOR, CENTRAL_KEEP, SOUTHERN_SHRINE, FOREST_SPRING, MILLS, FOREST_HAVEN, MINE") + "\n";
        helpBox.BbcodeText = t;
    }

    private void SetupLanguageDropdown()
    {
        langOption.Clear();
        var langs = new Dictionary
        {
            {"en", Tr("English")},
            {"pl", Tr("Polski")}
        };
        foreach (string code in langs.Keys)
        {
            langOption.AddItem((string)langs[code]);
            langOption.SetItemMetadata(langOption.ItemCount - 1, code);
        }
        for (int i = 0; i < langOption.GetItemCount(); i++)
        {
            if ((string)langOption.GetItemMetadata(i) == DB.current_language)
            {
                langOption.Select(i);
                break;
            }
        }
        langOption.ItemSelected += (long i) =>
        {
            DB.SetLanguage((string)langOption.GetItemMetadata((int)i));
            FillHelp();
            SetTabTitles();
            caravanPanel.Call("set_target", caravanPanel.Get("selected_target"));
            var askBtn = caravanPanel.Get("ask_ai_btn") as Button;
            if (askBtn != null)
                askBtn.Text = Tr("Ask AI for advice");
            UpdateStatus();
            RefreshTradePanel();
            mapNode.QueueRedraw();
        };
    }

    private void SetupTimeControls()
    {
        pauseBtn.Pressed += () => SetTimeFactor(0.0f);
        playBtn.Pressed += () => SetTimeFactor(1.0f);
        fastBtn.Pressed += () => SetTimeFactor(2.0f);
    }

    private void SetTimeFactor(float f)
    {
        timeFactor = f;
        if (f <= 0.0f)
            tickTimer.Stop();
        else
            tickTimer.Start(1.0f / f);
    }

    private void StoreTradeState()
    {
        var pid = PlayerMgr.local_player_id;
        var players = PlayerMgr.players;
        var p = players.ContainsKey(pid) ? (Dictionary)players[pid] : new Dictionary();
        lastLoc = p.ContainsKey("loc") ? p["loc"].ToString() : "";
        lastMoving = p.ContainsKey("moving") && (bool)p["moving"];
        var locations = DB.locations;
        var locData = locations.ContainsKey(lastLoc) ? (Dictionary)locations[lastLoc] : new Dictionary();
        lastStock = locData.ContainsKey("stock") ? ((Dictionary)locData["stock"]).Duplicate() : new Dictionary();
    }

    private void RefreshTradePanel()
    {
        tradePanel.CallDeferred("populate");
        StoreTradeState();
    }

    private void CheckTradeRefresh()
    {
        var pid = PlayerMgr.local_player_id;
        var players = PlayerMgr.players;
        var p = players.ContainsKey(pid) ? (Dictionary)players[pid] : null;
        if (p == null)
            return;
        var loc = p.ContainsKey("loc") ? p["loc"].ToString() : "";
        var moving = p.ContainsKey("moving") && (bool)p["moving"];
        var locations = DB.locations;
        var locData = locations.ContainsKey(loc) ? (Dictionary)locations[loc] : new Dictionary();
        var stock = locData.ContainsKey("stock") ? ((Dictionary)locData["stock"]).Duplicate() : new Dictionary();
        if (moving != lastMoving || loc != lastLoc || !stock.Equals(lastStock))
            RefreshTradePanel();
    }

    private void UpdateStatus()
    {
        var pid = PlayerMgr.local_player_id;
        var players = PlayerMgr.players;
        var p = players.ContainsKey(pid) ? (Dictionary)players[pid] : null;
        if (p == null)
            return;
        var locCode = p.ContainsKey("loc") ? p["loc"].ToString() : "";
        locLabel.Text = Tr("Location: {loc}").Replace("{loc}", DB.GetLocName(locCode));
        speedLabel.Text = Tr("Speed: {value}").Replace("{value}", PlayerMgr.CalcSpeed(pid).ToString());
        tickLabel.Text = Tr("Tick: {value}").Replace("{value}", Sim.tick_count.ToString());
        var used = PlayerMgr.CargoUsed(pid).ToString();
        var total = PlayerMgr.CapacityTotal(pid).ToString();
        capLabel.Text = Tr("Cargo: {used}/{total}").Replace("{used}", used).Replace("{total}", total);
        goldLabel.Text = Tr("Gold: {value}").Replace("{value}", p.ContainsKey("gold") ? p["gold"].ToString() : "0");
        var units = p.ContainsKey("units") ? (GodotArray)p["units"] : new GodotArray();
        caravansLabel.Text = Tr("Caravans: {value}").Replace("{value}", units.Count.ToString());
    }

    private void SetTabTitles()
    {
        tab.SetTabTitle(0, Tr("Chronicle"));
        tab.SetTabTitle(1, Tr("Caravan"));
        tab.SetTabTitle(2, Tr("Trade"));
        tab.SetTabTitle(3, Tr("World"));
        tab.SetTabTitle(4, Tr("Narrator"));
        tab.SetTabTitle(5, Tr("Help"));
    }

    public override void _Process(double delta)
    {
        Sim.AdvancePlayers((float)delta * timeFactor);
        UpdateStatus();
        CheckTradeRefresh();
    }

    private void OnLocationClick(string locCode)
    {
        var pid = PlayerMgr.local_player_id;
        if (PlayerMgr.StartTravel(pid, locCode))
        {
            UpdateStatus();
            mapNode.QueueRedraw();
            RefreshTradePanel();
        }
    }

    private void OnBuyRequest(int good, int amount)
    {
        var pid = PlayerMgr.local_player_id;
        if (commander.Buy(pid, good, amount))
        {
            UpdateStatus();
            RefreshTradePanel();
        }
    }

    private void OnSellRequest(int good, int amount)
    {
        var pid = PlayerMgr.local_player_id;
        if (commander.Sell(pid, good, amount))
        {
            UpdateStatus();
            RefreshTradePanel();
        }
    }

    private void OnAskAi(int playerId)
    {
        var aibr = GetNodeOrNull<Node>("/root/AiBridge");
        if (aibr != null)
            aibr.Call("suggest_for_player", playerId);
    }

    private void OnTick()
    {
        Sim.Tick();
        UpdateStatus();
        mapNode.QueueRedraw();
    }

    private void OnCmd(string text)
    {
        var t = text.Trim();
        if (t == "")
            return;
        cmdBox.Text = "";
        commander.Call("exec", t);
    }

    private void OnLog(string msg)
    {
        logLabel.AppendText(msg + "\n");
    }

    private void OnPlayerChanged(Dictionary data)
    {
        UpdateStatus();
        RefreshTradePanel();
        mapNode.QueueRedraw();
    }
}
