using System.Collections.Generic;

namespace CaravanWars
{
    public class Player
    {
        public string Name { get; set; } = "P";
        public bool Moving { get; set; }
        public string From { get; set; } = "";
        public string To { get; set; } = "";
        public float Progress { get; set; }
        public string Loc { get; set; } = "";
    }

    public static class PlayerMgr
    {
        public static readonly Dictionary<int, Player> Players = new();
    }
}
