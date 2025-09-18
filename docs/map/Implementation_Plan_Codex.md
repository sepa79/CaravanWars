# Plan implementacji (Codex) — Generator i Widok Mapy (Hex)

## Faza 0 — Struktura
- [ ] Moduł `mapgen` (offline) i `mapview` (runtime) w Godot 4.
- [ ] Format `*.cwmap` = JSON `MapBundle` + `meta`.
- [ ] Loader `MapBundleLoader.gd` (walidacja wg `docs/MapBundle_Schema.json`).

## Faza 1 — Generator Hex Region-First
- [ ] Hex grid (axial/offset).
- [ ] Morze/ląd: wybrzeże → Sea.
- [ ] Ziarna regionów i rozrost BFS/Voronoi (reguły sąsiedztwa).
- [ ] Lekkie `elev` 0..1 z typu regionu.
- [ ] Rzeki na krawędziach: źródła w górach, spływ do morza/jeziora, outlet.
- [ ] Biomy: N–S temp, wilgoć od wody, wysokość.
- [ ] Granice: flood-fill od stolic, preferuj rzeki/góry.
- [ ] Miasta/wsie: Poisson, preferencje Valley/Plains przy wodzie.
- [ ] Drogi: MST → trasy po krawędziach, mosty na rzekach.
- [ ] Forty: mosty/przełęcze/granice; limity i spacing.
- [ ] Eksport `MapBundle.json`.

## Faza 2 — Widok (Godot)
- [ ] Warstwy: hexy, rzeki, drogi, granice, punkty.
- [ ] Ikony (SVG) w MultiMeshInstance2D.
- [ ] Curve2D dla dróg/rzek po krawędziach.
- [ ] LOD, hover, selekcja, filtry warstw.

## Faza 3 — Gameplay/Produkcja
- [ ] Produkcja osad: mod z najbliższego hexa/biomu.
- [ ] Kontrola crossingów i fortów.
- [ ] Import/Export map (zip).

## Faza 4 — QA/Debug
- [ ] Debug overlay: ID hexów/krawędzi, crossing_id, nazwy.
- [ ] Walidator: brak krawędzi-sierot, minimalne kąty, odstępy mostów.
