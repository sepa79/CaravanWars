# PHASE-03 — Map (Hex-based)

Mapa generowana jest szybko i deterministycznie na **hexach** (6 sąsiadów). Rzeki, drogi, granice i mosty biegną po **krawędziach** hexów. Brak heightmap – używamy prostych regionów i lekkiej wysokości 0..1.

## Sekwencja
1. Terrain (regiony na hexach)
2. Rivers (po krawędziach)
3. Biomes
4. Kingdom borders (po krawędziach)
5. Cities & villages
6. Roads (po krawędziach)
7. Forts

## Parametry
- seed, map_radius, kingdom_count=3
- sea_pct, mountains_pct, lakes_pct
- rivers_cap, road_aggressiveness
- fort_global_cap, fort_spacing

## 1) Terrain
- Morze/ląd z prostego kształtu wybrzeża.
- Ziarna regionów: Mountains, Hills, Plains, Valley, Lake (reguły: doliny obok gór/wzgórz; jeziora w obniżeniach).
- Rozrost regionów: BFS/Voronoi po hexach.
- Lekkie `elev`: Sea=0.0, Lake=0.1, Valley=0.2, Plains=0.35, Hills=0.6, Mountains=0.9 (+mały jitter).

## 2) Rivers
- Źródła w górach (lokalne maksima).
- Spływ w dół po `elev`, rzeka żyje na **krawędziach**; łączenie dopływów.
- Wzdłuż koryta – zmiana pól na Valley; jeziora mają outlet.

## 3) Biomes
- Temperatura (N–S) + wysokość + wilgoć od wody → klasyfikacja biomów.

## 4) Kingdom borders
- Flood-fill od stolic z kosztami; preferuj rzeki i góry jako granice.
- Granice biegną **po krawędziach**. Dróg nie rozcinamy.

## 5) Cities & villages
- Miasta na Plains/Valley przy wodzie; porty nad morzem/jeziorem.
- Wsie gęściej przy drogach/rzekach; min. odstępy; każde królestwo ≥1 miasto.

## 6) Roads
- Drogi na **krawędziach**; graf MST miast → trasy z kosztami (teren, mosty).
- Ciągłość przez granice (tag `traversed_kingdoms`).

## 7) Forts
- Kandydaty: mosty, przełęcze, granica blisko drogi.
- Limity per królestwo (~floor(miasta/4), min 1), globalny `fort_spacing`; unikaj vis-à-vis.

## Walidacja
- Rzeki mają zlewiska; jeziora mają odpływy.
- Miasta/forty na lądzie; drogi spójne; granice = kingdom_count regionów.

## Warstwy
- hex/regions, hex/elev (0..1)
- edges/rivers, edges/roads, edges/borders, edges/bridges
- points/cities, points/villages, points/forts
- biomes/polygons (opcjonalnie)

## UI
Seed, Map Radius, Kingdom Count=3, Sea%, Mountains%, Lakes%, Road Aggressiveness, Fort Cap/Spacing.
**Eksport:** patrz `docs/MapBundle_Schema.json` i `docs/MapBundle_Format.md`.
