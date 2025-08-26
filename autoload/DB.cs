using Godot;
using System;
using Godot.Collections;

public partial class DB : Node
{
    public enum Good { FOOD, MEDS, ORE, TOOLS, LUX }

    public Dictionary goods_base_price = new Dictionary
    {
        { (int)Good.FOOD, 10 },
        { (int)Good.MEDS, 16 },
        { (int)Good.ORE, 20 },
        { (int)Good.TOOLS, 18 },
        { (int)Good.LUX, 40 }
    };

    public Dictionary goods_names = new Dictionary
    {
        { (int)Good.FOOD, "food" },
        { (int)Good.MEDS, "meds" },
        { (int)Good.ORE, "ore" },
        { (int)Good.TOOLS, "tools" },
        { (int)Good.LUX, "lux" }
    };

    public string current_language = "pl";

    public Dictionary loc_display = new Dictionary
    {
        { "HARBOR", new Dictionary { {"en", "Harbor"}, {"pl", "Port"} } },
        { "CENTRAL_KEEP", new Dictionary { {"en", "Central Keep"}, {"pl", "Twierdza Środkowa"} } },
        { "SOUTHERN_SHRINE", new Dictionary { {"en", "Southern Shrine"}, {"pl", "Świątynia Południowa"} } },
        { "FOREST_SPRING", new Dictionary { {"en", "Forest Spring"}, {"pl", "Źródło Leśne"} } },
        { "MILLS", new Dictionary { {"en", "Mills"}, {"pl", "Młyny"} } },
        { "FOREST_HAVEN", new Dictionary { {"en", "Forest Haven"}, {"pl", "Leśna Przystań"} } },
        { "MINE", new Dictionary { {"en", "Mine"}, {"pl", "Kopalnia"} } }
    };

    public override void _Ready()
    {
        var tr = GD.Load<Translation>("res://locale/translations.pl.tres");
        if (tr != null)
            TranslationServer.AddTranslation(tr);
        TranslationServer.SetLocale(current_language);
    }

    public Dictionary positions = new Dictionary
    {
        { "HARBOR", new Vector2(1060, 840) },
        { "CENTRAL_KEEP", new Vector2(910, 750) },
        { "SOUTHERN_SHRINE", new Vector2(350, 840) },
        { "FOREST_SPRING", new Vector2(690, 560) },
        { "MILLS", new Vector2(1010, 185) },
        { "FOREST_HAVEN", new Vector2(890, 360) },
        { "MINE", new Vector2(440, 340) }
    };

    public Dictionary routes = new Dictionary
    {
        { "FOREST_SPRING->MINE", new Dictionary { {"risk", 0.00}, {"ticks", 2} } },
        { "MINE->FOREST_SPRING", new Dictionary { {"risk", 0.00}, {"ticks", 2} } },

        { "HARBOR->CENTRAL_KEEP", new Dictionary { {"risk", 0.05}, {"ticks", 3} } },
        { "CENTRAL_KEEP->HARBOR", new Dictionary { {"risk", 0.05}, {"ticks", 3} } },

        { "CENTRAL_KEEP->FOREST_SPRING", new Dictionary { {"risk", 0.05}, {"ticks", 3} } },
        { "FOREST_SPRING->CENTRAL_KEEP", new Dictionary { {"risk", 0.05}, {"ticks", 3} } },

        { "FOREST_SPRING->FOREST_HAVEN", new Dictionary { {"risk", 0.05}, {"ticks", 2} } },
        { "FOREST_HAVEN->FOREST_SPRING", new Dictionary { {"risk", 0.05}, {"ticks", 2} } },

        { "CENTRAL_KEEP->SOUTHERN_SHRINE", new Dictionary { {"risk", 0.07}, {"ticks", 3} } },
        { "SOUTHERN_SHRINE->CENTRAL_KEEP", new Dictionary { {"risk", 0.07}, {"ticks", 3} } },

        { "MILLS->FOREST_HAVEN", new Dictionary { {"risk", 0.06}, {"ticks", 3} } },
        { "FOREST_HAVEN->MILLS", new Dictionary { {"risk", 0.06}, {"ticks", 3} } }
    };

    public Dictionary locations = new Dictionary
    {
        { "CENTRAL_KEEP", new Dictionary { {"stock", new Dictionary { { (int)Good.FOOD, 30 }, { (int)Good.MEDS, 10 } } }, {"demand", new Dictionary { { (int)Good.FOOD, 1.0 }, { (int)Good.MEDS, 1.1 }, { (int)Good.TOOLS, 1.2 } } } } },
        { "MINE", new Dictionary { {"stock", new Dictionary { { (int)Good.ORE, 60 } } }, {"demand", new Dictionary { { (int)Good.FOOD, 1.1 }, { (int)Good.TOOLS, 1.2 } } } } },
        { "HARBOR", new Dictionary { {"stock", new Dictionary { { (int)Good.LUX, 6 } } }, {"demand", new Dictionary { { (int)Good.FOOD, 1.2 }, { (int)Good.MEDS, 1.1 }, { (int)Good.ORE, 1.3 }, { (int)Good.TOOLS, 1.2 } } } } },
        { "MILLS", new Dictionary { {"stock", new Dictionary { { (int)Good.FOOD, 40 } } }, {"demand", new Dictionary { { (int)Good.MEDS, 1.2 }, { (int)Good.TOOLS, 1.1 } } } } },
        { "FOREST_HAVEN", new Dictionary { {"stock", new Dictionary { { (int)Good.TOOLS, 8 } } }, {"demand", new Dictionary { { (int)Good.FOOD, 1.1 }, { (int)Good.MEDS, 1.2 } } } } },
        { "FOREST_SPRING", new Dictionary { {"stock", new Dictionary { { (int)Good.FOOD, 10 } } }, {"demand", new Dictionary { { (int)Good.TOOLS, 1.1 } } } } },
        { "SOUTHERN_SHRINE", new Dictionary { {"stock", new Dictionary { { (int)Good.MEDS, 20 } } }, {"demand", new Dictionary { { (int)Good.FOOD, 1.2 }, { (int)Good.TOOLS, 1.3 } } } } }
    };

    public Dictionary unit_defs = new Dictionary
    {
        { "hand_cart", new Dictionary { {"name", "Hand Cart"}, {"speed", 1.0}, {"capacity", 10}, {"upkeep_gold", 0}, {"upkeep_food", 1} } },
        { "horse_cart", new Dictionary { {"name", "Horse Cart"}, {"speed", 2.0}, {"capacity", 25}, {"upkeep_gold", 1}, {"upkeep_food", 2} } },
        { "guard", new Dictionary { {"name", "Guard"}, {"speed", 1.0}, {"capacity", 0}, {"upkeep_gold", 1}, {"upkeep_food", 1}, {"power", 2} } }
    };

    public void SetLanguage(string lang)
    {
        if (lang == "pl" || lang == "en")
        {
            current_language = lang;
            TranslationServer.SetLocale(lang);
        }
    }

    public string GetLocName(string code)
    {
        if (!loc_display.ContainsKey(code))
            return code;
        var names = loc_display[code] as Dictionary;
        if (names.ContainsKey(current_language))
            return names[current_language].ToString();
        return code;
    }

    public string RouteKey(string a, string b)
    {
        return $"{a}->{b}";
    }

    public Vector2 GetPos(string code)
    {
        if (positions.ContainsKey(code))
            return (Vector2)positions[code];
        return Vector2.Zero;
    }

    public bool HasRoute(string a, string b)
    {
        return routes.ContainsKey(RouteKey(a, b));
    }

    public Dictionary GetRoute(string a, string b)
    {
        if (routes.ContainsKey(RouteKey(a, b)))
            return routes[RouteKey(a, b)] as Dictionary;
        return new Dictionary();
    }
}
