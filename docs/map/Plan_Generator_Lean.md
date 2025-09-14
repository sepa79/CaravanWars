
# Plan Generatora Mapy — LEAN (bez symulacji świata)

**Cel:** Szybko wygenerować świat z sensowną siecią **miast, dróg, wsi, przepraw, fortów i granic**, przy minimalnej złożoności.

## Wejście
- `seed` (liczby całkowite per warstwa: osady, drogi, rzeki)
- `map_size` (np. 150×150 w jednostkach U)
- `cities_target`, `village_density`
- opcjonalnie: `has_coast` (true/false), `river_count` (0–6)

## Etapy (proste)

1) **Pola pomocnicze (syntetyczne):**
   - `fertility` = 2–3 oktawy noise (0..1). 
   - `roughness` = różnica lokalna (proxy „trudności terenu”).  
   → Nie zapisujemy — użyte tylko w tej sesji generowania.

2) **Korytarze rzek (opcjonalnie):**
   - Wylosuj 0–6 splajnów z miejsc „wysokich” (fertility niskie/roughness niskie) do krawędzi mapy.
   - Zachowaj minimalne odległości między rzekami. Zapisz jako polilinie.

3) **Miasta:**
   - Kandydaci = lokalne maksima `fertility` na lądzie, min. odstęp `R_city`.
   - Miasta są ≥ 30 od krawędzi mapy (stały margines).
   - Preferencja: ≤ 3U od rzeki/wybrzeża, `roughness` poniżej progu.
   - Wybierz `cities_target` najlepszych. 1–3 z nich oznacz jako **stolice**.

4) **Drogi między miastami (Roman):**
   - Graf kandydatów: Delaunay → MST → kilka skrótów (k-nearest).
   - Trasa krawędzi: „najprostsza możliwa” (prosta + 1–2 punkty załamania, unikaj ostrych kątów).
   - Gdzie droga przecina rzekę → utwórz **crossing** (domyślnie **bridge**).

5) **Wsie i drogi lokalne:**
   - W pierścieniu 8–30U wokół miasta rozstaw **wsie** metodą Poisson; każda wieś musi pozostać w granicach regionu swojego miasta.
   - Selekcja kandydatów uwzględnia `fertility`, unika wysokiego `roughness` i preferuje bliskość dróg i rzek.
   - Każda wieś najpierw dołącza do najbliższej drogi typu **roman**; jeśli takiej nie ma, łączy się bezpośrednio z miastem.
   - Wsie łączą się między sobą tylko wtedy, gdy trasa istniejącą siecią dróg byłaby ponad dwukrotnie dłuższa niż połączenie bezpośrednie. Sąsiadujące regiony tego samego królestwa mogą łączyć najbliższe wsie, jeśli brak krótszej trasy.
   - Dziedziczenie klas: gałąź o **jeden poziom niżej** (Roman→Road→Path).

6) **Granice królestw:**
   - Voronoi od **stolic** → delikatne „snap” do rzek w pobliżu.
   - Dróg **nie tniemy** — tylko oznaczamy **border-gate** na istniejących krawędziach.

7) **Fortece:**
   - Kandidaci: mosty, przewężenia, styki granic.
   - Limity: globalny i per-kingdom (≈ #miast/2). 
   - Przy granicy: **para fortów** offsetem wzdłuż drogi (unikamy „vis-à-vis” na linii).

8) **Mini‑regiony klimatu/biomu (tylko pod gameplay):**
   - Podziel mapę na 8×8 komórek (lub Voronoi 32–64 pól).
   - Każdej przypisz 2–4 skalary: `temp`, `moisture`, `biome_id`, `prod_mod` (np. {food:+0.1, wood:-0.05}).
   - Wyznacz mody z `fertility` (dla food/wood) i współrzędnej Y (pseudo‑szerokość geograficzna).

## Wyjście
- **MapBundle** (patrz `MapBundle_Schema.json`): tylko punkty/linijki + kilka tablic skalarów.
