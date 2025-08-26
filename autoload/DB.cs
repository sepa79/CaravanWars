using Godot;
using System.Collections.Generic;

namespace CaravanWars
{
    public static class DB
    {
        public static readonly Dictionary<string, Vector2> Positions = new()
        {
            {"HARBOR",        new Vector2(1060, 840)},
            {"CENTRAL_KEEP",  new Vector2(910, 750)},
            {"SOUTHERN_SHRINE", new Vector2(350, 840)},
            {"FOREST_SPRING", new Vector2(690, 560)},
            {"MILLS",         new Vector2(1010, 185)},
            {"FOREST_HAVEN",  new Vector2(890, 360)},
            {"MINE",          new Vector2(440, 340)}
        };

        public record Route(string From, string To, float Risk, int Ticks);

        public static readonly List<Route> Routes = new()
        {
            new("FOREST_SPRING", "MINE", 0.00f, 2),
            new("MINE", "FOREST_SPRING", 0.00f, 2),
            new("HARBOR", "CENTRAL_KEEP", 0.05f, 3),
            new("CENTRAL_KEEP", "HARBOR", 0.05f, 3),
            new("CENTRAL_KEEP", "FOREST_SPRING", 0.05f, 3),
            new("FOREST_SPRING", "CENTRAL_KEEP", 0.05f, 3),
            new("FOREST_SPRING", "FOREST_HAVEN", 0.05f, 2),
            new("FOREST_HAVEN", "FOREST_SPRING", 0.05f, 2),
            new("CENTRAL_KEEP", "SOUTHERN_SHRINE", 0.07f, 3),
            new("SOUTHERN_SHRINE", "CENTRAL_KEEP", 0.07f, 3),
            new("MILLS", "FOREST_HAVEN", 0.06f, 3),
            new("FOREST_HAVEN", "MILLS", 0.06f, 3)
        };

        public static string GetLocName(string code) => code;
    }
}
