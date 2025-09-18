
# Zadania wdrożeniowe (Codex) — Generator + Widok Mapy

## Faza 0 — Struktura projektu
- [ ] Dodaj moduł `mapgen` (offline) i `mapview` (runtime) w Godot 4.
- [ ] Ustal format pliku `*.cwmap` = JSON `MapBundle` + sekcja `meta`.
- [ ] Dodaj loader `MapBundleLoader.gd` (walidacja vs `docs/MapBundle_Schema.json`).

## Faza 1 — Generator LEAN
- [ ] Implementuj noise `fertility` i `roughness` (OpenSimplex, 2–3 oktawy).
- [ ] Wygeneruj kandydatów miast (lokalne maksima, min. odstęp).
- [ ] Wybierz `cities_target` i wylosuj stolice (1–3).
- [ ] Zbuduj graf kandydatów dróg (Delaunay → MST → skróty).
- [ ] Wyznacz trasy Roman (prosta + 1–2 załamania, unikaj ostrych kątów).
- [ ] (Opcja) Rzeki jako 0–6 splajnów; dodaj crossingi (bridge).
- [ ] Rozstaw wsie Poisson w pierścieniu 8–40U, z biasem na drogi/mosty.
- [ ] Połącz wsie (MST + 20% skrótów); klasy gałęzi: Roman→Road→Path.
- [ ] Granice (Voronoi od stolic) + border-gate na przecinanych drogach.
- [ ] Fortece na mostach/przewężeniach; kapy globalne i per-kingdom.
- [ ] Mini‑regiony 8×8: temp/moist/biome_id/prod_mod z prostych heurystyk.
- [ ] Zapisz `MapBundle.json` (zgodnie ze schematem).

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
