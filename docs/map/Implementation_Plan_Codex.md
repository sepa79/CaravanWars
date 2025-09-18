
# Zadania wdrożeniowe (Codex) — Generator + Widok Mapy

## Faza 0 — Struktura projektu
- [ ] Dodaj moduł `mapgen` (offline) i `mapview` (runtime) w Godot 4.
- [ ] Ustal format pliku `*.cwmap` = JSON `MapBundle` + sekcja `meta`.
- [ ] Dodaj loader `MapBundleLoader.gd` (walidacja vs `docs/MapBundle_Schema.json`).

## Faza 1 — Generator LEAN (Region-First)
- [ ] Wprowadź podział na tiles (`Grid`) i warstwę `RegionType` (Sea, Lake, Mountains, Hills, Plains, Valley).
- [ ] Coastline: generuj `sea_mask` z prostych kształtów (blob/spline) deterministycznie z `seed`.
- [ ] Rozsiej ziarna regionów po lądzie (wagi: mountains≈10%, lakes≈3%, reszta plains/valley/hills).
- [ ] Rozrost regionów: BFS/Voronoi + 1–2 relax; wymuś reguły sąsiedztwa (Valley przy Mountains/Hills, Lake w lokalnych minimach).
- [ ] Wylicz lekkie `elev` 0..1 z typu regionu (Sea 0.0 … Mountains 0.9) + drobny jitter.
- [ ] Rzeki: źródła w górach, A* po `elev` do morza/jeziora; łącz dopływy; korytowanie zmienia typ na Valley wzdłuż kanału.
- [ ] Biomy: temp = lat − lapse*elev; rain = noise prosty + boost przy rzekach/jeziorach − rain shadow; klasyfikacja macierzą.
- [ ] Granice: flood-fill wieloźródłowy z kosztami, preferuj rzeki jako granice przy małej różnicy kosztów.
- [ ] Miasta/Wsie: Poisson-disc; preferencje: Valley/Plains przy rzekach/jeziorach; porty na wybrzeżu.
- [ ] Drogi: MST miast → A* (kosz: typ terenu + crossing penalty); mosty/fordy na wąskich przejściach; nie rozcinaj na granicach.
- [ ] Forty: chokepointy (mosty, przełęcze, granice blisko dróg), limity per-królestwo i `fort_spacing`.


## Faza 2 — Widok mapy (Godot)
- [ ] Scena `MapRoot.tscn` z warstwami wg `docs/Rendering_Spec_Godot.md`.
- [ ] Import ikon (SVG) do `MultiMeshInstance2D` (miasta/wsie/forty/crossingi).
- [ ] Rysowanie dróg (Roman/Road/Path) i rzek (Curve2D).
- [ ] LOD: przełączanie widoczności warstw zależnie od zoomu.
- [ ] Interakcja: hover (podświetlenie krawędzi), selekcja (panel info).
- [ ] Filtry warstw (toggle biomy/granice/rzeki/Path).

## Faza 3 — Produkcja i gameplay
- [ ] Produkcja osad: baza × `prod_mod` z najbliższej `climate_cell`.
- [ ] Kontrola przejść granicznych i fortów (sprawdzaj crossing markers).
- [ ] Eksport/Import map (zip: `MapBundle.json` + `meta`).

## Faza 4 — QA / debug
- [ ] Tryb debug: ID węzłów, klasy krawędzi, crossing_id, nazwy królestw.
- [ ] Walidator spójności: brak krawędzi-sierot, minimalne kąty na węzłach, odstępy mostów.
