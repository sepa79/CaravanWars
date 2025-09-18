# Plan implementacji (Codex) — Hex + rzeki/drogi w kaflach

## Faza 0 — Struktura
- [ ] `mapgen` (offline) i `mapview` (runtime) w Godot 4.
- [ ] Format `*.cwmap` = JSON `MapBundle` + `meta` + zasoby.

## Faza 1 — Generator
- [ ] Hex grid (axial/offset). Kształt wybrzeża → Sea.
- [ ] Ziarna regionów i rozrost BFS/Voronoi (reguły: Valley przy Mountains/Hills; jeziora w obniżeniach).
- [ ] Lekkie `elev` 0..1 z typu regionu (+mały jitter).
- [ ] Rzeki w kaflach: źródła w górach, trasa w dół, ustaw `river_mask`, `river_class`; delta = kilka heksów wody.
- [ ] Biomy: N–S temp + wilgoć od wody + wysokość.
- [ ] Granice: flood-fill od stolic, snapping do rzek/gór. Granice na krawędziach.
- [ ] Miasta/wsie: Poisson-disc; preferencje Plains/Valley przy wodzie.
- [ ] Drogi w kaflach: MST + A*, `road_mask`, `road_class`, `bridge=true` gdzie przecinają rzekę.
- [ ] Forty: mosty/przełęcze/granice; limity i spacing.
- [ ] Eksport `MapBundle.json`.

## Faza 2 — Widok (Godot)
- [ ] Warstwy: hexy (terrain), rzeki/drogi (warianty kafli), granice (line na krawędziach), punkty (miasta/wsie/forty).
- [ ] Import atlasu/tilesetu (np. KayKit). Dobór kafla wg `*_mask` (prosta/łuk/T/krzyż/źródło/ujście).
- [ ] LOD: na daleko tylko tereny + cienkie rzeki/drogi; blisko – pełne warianty.
- [ ] Interakcja: hover/select; overlay granic; panele info.

## Faza 3 — QA/Debug
- [ ] Walidator: ujścia/outlety, spójność dróg, liczba królestw.
- [ ] Debug overlay: maski kierunkowe (6-bit), klasy rzek/dróg, crossing markers.
