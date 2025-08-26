using Godot;
using System;
using System.Collections.Generic;

public partial class Map : Control
{
    [Signal]
    public delegate void LocationClickedEventHandler(string locCode);

    [Export]
    public bool ShowGrid { get; set; } = true;

    private const int ImgWidth = 1536;
    private const int ImgHeight = 1024;

    private TextureRect _background;
    private Texture2D _backgroundTex;

    private float _scale = 1f;
    private Vector2 _offset = Vector2.Zero;
    private Vector2 _displaySize = Vector2.Zero;
    private float _playerBlink;
    private string _hoverLoc = "";
    private float _hoverScale = 1f;
    private Tween _hoverTween;
    private float _zoom = 1f;

    private const float ZoomStep = 1.25f;
    private const float ZoomMin = 1f;
    private const float ZoomMax = 4f;

    private readonly List<(Vector2 From, Vector2 To)> _routes = new();
    private readonly List<string> _locIds = new();

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Stop;
        _background = GetNodeOrNull<TextureRect>("Background");
        _backgroundTex = _background?.Texture;
        _background?.Hide();

        foreach (var r in DB.Routes)
        {
            if (DB.Positions.TryGetValue(r.From, out var a) &&
                DB.Positions.TryGetValue(r.To, out var b))
            {
                _routes.Add((a, b));
            }
        }

        _locIds.AddRange(DB.Positions.Keys);
        _locIds.Sort();

        UpdateLayout();
        Resized += () => { UpdateLayout(); QueueRedraw(); };
        SetProcess(true);

        var blink = CreateTween();
        blink.SetLoops();
        blink.TweenProperty(this, nameof(_playerBlink), 1.0f, 0.5f)
             .TweenProperty(this, nameof(_playerBlink), 0.0f, 0.5f);
    }

    private void UpdateLayout()
    {
        var panelSize = Size;
        var baseScale = Math.Min(
            panelSize.X / ImgWidth,
            panelSize.Y / ImgHeight
        );
        _scale = baseScale * _zoom;
        _displaySize = new Vector2(ImgWidth, ImgHeight) * _scale;
        _offset = (panelSize - _displaySize) * 0.5f;
    }

    private Vector2 ToImage(Vector2 screen)
    {
        var s = Math.Max(_scale, 0.00001f);
        return (screen - _offset) / s;
    }

    public override void _Draw()
    {
        if (_backgroundTex != null)
            DrawTextureRect(_backgroundTex, new Rect2(_offset, _displaySize), false);

        DrawSetTransform(_offset, 0f, new Vector2(_scale, _scale));

        if (ShowGrid)
            DrawGrid();
        DrawRoutes();
        DrawLocations();
        DrawCaravans();
        DrawPlayers();
    }

    private void DrawGrid()
    {
        const int step = 128;
        var col = new Color(0.1f, 0.1f, 0.1f, 0.5f);
        for (int x = 0; x <= ImgWidth; x += step)
            DrawLine(new Vector2(x, 0), new Vector2(x, ImgHeight), col);
        for (int y = 0; y <= ImgHeight; y += step)
            DrawLine(new Vector2(0, y), new Vector2(ImgWidth, y), col);
    }

    private void DrawRoutes()
    {
        var line = new Color(0.85f, 0.7f, 0.45f);
        var shadow = new Color(0, 0, 0, 0.25f);
        foreach (var (from, to) in _routes)
        {
            DrawLine(from + new Vector2(0, 1), to + new Vector2(0, 1), shadow, 4f);
            DrawLine(from, to, line, 3f);
        }
    }

    private void DrawLocations()
    {
        var font = GetThemeDefaultFont();
        foreach (var id in _locIds)
        {
            var pos = DB.Positions[id];
            float radius = id == _hoverLoc ? 10.5f * _hoverScale : 10.5f;
            if (id == _hoverLoc)
                DrawCircle(pos, radius + 2f, Colors.White);
            DrawCircle(pos, radius, new Color(0.95f, 0.3f, 0.2f, 0.9f));
            DrawCircle(pos, 3.75f, new Color(0.1f, 0.1f, 0.1f));
            var name = DB.GetLocName(id);
            var labelPos = pos + new Vector2(12, -8);
            DrawString(font, labelPos + Vector2.One, name, HorizontalAlignment.Left, -1, 16, new Color(0, 0, 0, 0.65f));
            DrawString(font, labelPos, name, HorizontalAlignment.Left, -1, 16, Colors.White);
        }
    }

    private void DrawCaravans()
    {
        var colBase = new Color(0.95f, 0.8f, 0.2f);
        var colAlt = new Color(0.95f, 0.2f, 0.2f);
        var col = colBase.Lerp(colAlt, _playerBlink);

        foreach (var p in PlayerMgr.Players.Values)
        {
            Vector2 pos;
            if (p.Moving &&
                DB.Positions.TryGetValue(p.From, out var fromPos) &&
                DB.Positions.TryGetValue(p.To, out var toPos))
            {
                pos = fromPos.Lerp(toPos, Mathf.Clamp(p.Progress, 0, 1));
                var dir = (toPos - fromPos).Normalized();
                var perp = dir.Orthogonal() * 6f;
                var tip = pos + dir * 12f;
                var tail = pos - dir * 12f;
                DrawColoredPolygon(new Vector2[] { tip, tail + perp, tail - perp }, col);
            }
            else if (!string.IsNullOrEmpty(p.Loc) && DB.Positions.TryGetValue(p.Loc, out pos))
            {
                DrawCircle(pos, 8f, col);
            }
        }
    }

    private void DrawPlayers()
    {
        var font = GetThemeDefaultFont();
        foreach (var p in PlayerMgr.Players.Values)
        {
            Vector2 pos;
            if (p.Moving &&
                DB.Positions.TryGetValue(p.From, out var fromPos) &&
                DB.Positions.TryGetValue(p.To, out var toPos))
            {
                pos = fromPos.Lerp(toPos, Mathf.Clamp(p.Progress, 0, 1));
            }
            else if (!string.IsNullOrEmpty(p.Loc) && DB.Positions.TryGetValue(p.Loc, out pos))
            {
            }
            else
                continue;

            var label = string.IsNullOrEmpty(p.Name) ? "P" : p.Name;
            DrawString(font, pos + new Vector2(12, -8), label, HorizontalAlignment.Left, -1, 16, Colors.White);
        }
    }

    public override void _GuiInput(InputEvent @event)
    {
        if (@event is InputEventMouseMotion motion)
        {
            var mousePos = ToImage(motion.Position);
            var found = "";
            foreach (var id in _locIds)
            {
                if (DB.Positions[id].DistanceTo(mousePos) <= 18f)
                {
                    found = id;
                    break;
                }
            }
            if (found != _hoverLoc)
            {
                _hoverLoc = found;
                _hoverTween?.Kill();
                _hoverTween = CreateTween();
                _hoverTween.TweenProperty(this, nameof(_hoverScale), found == "" ? 0f : 1f, 0.1f);
            }
            QueueRedraw();
        }
        else if (@event is InputEventMouseButton btn && btn.Pressed && btn.ButtonIndex == MouseButton.Left)
        {
            var clickPos = ToImage(btn.Position);
            foreach (var id in _locIds)
            {
                if (DB.Positions[id].DistanceTo(clickPos) <= 18f)
                {
                    EmitSignal(nameof(LocationClicked), id);
                    break;
                }
            }
        }
    }

    public void ZoomIn()
    {
        _zoom = Math.Min(_zoom * ZoomStep, ZoomMax);
        UpdateLayout();
        QueueRedraw();
    }

    public void ZoomOut()
    {
        _zoom = Math.Max(_zoom / ZoomStep, ZoomMin);
        UpdateLayout();
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        QueueRedraw();
    }
}
