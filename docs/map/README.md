
# CaravanWars — Pakiet Mapy (Generator + Gra) — v1

Zawartość:
- **assets/icons/** — zestaw wektorowych ikonek (monochromatyczne + kolorowe).
- **docs/** — plan generatora (LEAN), spec rysowania w Godot, schemat MapBundle, zadania wdrożeniowe (Codex).
- **examples/** — przykładowy `MapBundle.json` do testów widoku.

## Szybki start
1) W grze ładujemy wyłącznie **MapBundle** (bez region layers, klimatu, etc.).  
2) Rysujemy warstwy wg `docs/Rendering_Spec_Godot.md`.  
3) Produkcja osad = baza z osady × modyfikatory z najbliższej komórki `climate_cells`.

Licencje:
- **Ikony**: CC0 1.0 (patrz `LICENSE-ICONS.txt`) — możesz użyć bez atrybucji.  
- **Dokumenty/schemat**: MIT (patrz `LICENSE-DOCS.txt`).


## Map Generation
- [PHASE-03 — Map (Region-First)](docs/phases/PHASE-03_Map.md)
