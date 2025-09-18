# PHASE-03 — Map (Hex, rzeki/drogi w kaflach)

Mapa generowana jest szybko i deterministycznie na **hexach** (6 sąsiadów). **Rzeki i drogi są cechą heksa (kafla)** – wybieramy wariant kafla na podstawie masek kierunkowych. **Granice królestw** pozostają na **krawędziach** hexów. Brak heightmap – używamy regionów i lekkiej wysokości 0..1.

## Sekwencja
1. Terrain (regiony na hexach)
2. Rivers (w kaflach na podstawie masek kierunków)
3. Biomes
4. Kingdom borders (po krawędziach)
5. Cities & villages
6. Roads (w kaflach na podstawie masek kierunków)
7. Forts

## Parametry (domyślne)
- `seed`, `map_radius`, `kingdom_count = 3`
- `sea_pct`, `mountains_pct`, `lakes_pct`
- `rivers_cap`, `road_aggressiveness`
- `fort_global_cap`, `fort_spacing`

---

## 1) Terrain (regiony)
- **Morze/ląd**: prosty kształt wybrzeża, pola poza nim = Sea.
- **Ziarna regionów**: Mountains, Hills, Plains, Valley, Lake (reguły: doliny obok gór/wzgórz; jeziora w obniżeniach).
- **Rozrost regionów**: BFS/Voronoi po hexach; deterministycznie z `seed`.
- **Lekkie `elev`**: Sea=0.0, Lake=0.1, Valley=0.2, Plains=0.35, Hills=0.6, Mountains=0.9 (+drobny jitter).

**Walidacja**: brak jezior na „grzbietach”, doliny stykają się z górami/wzgórzami, brak jednopunktowych morz na lądzie.

---

## 2) Rivers (w kaflach)
**Cel:** rzeki jako ciąg heksów z kierunkami wejścia/wyjścia → dobór wariantów kafla (prosta/łuk/T/krzyż/źródło/ujście).

- **Źródła**: hexy górskie (lokalne maksima `elev` w Mountains).
- **Trasa**: schodzimy „po heksach” w dół `elev` do morza/jeziora; preferencja Valley.
- **Maski kierunkowe** (6-bit): dla każdego heksa ustaw kierunki, z których woda wchodzi/wychodzi.
- **Dobór kafla**: na podstawie maski (2 naprzeciwko → prosta; 2 sąsiednie → łuk; 3 → T; 4 → krzyż; 1 → źródło/ujście).
- **Szerokość/klasa**: z akumulacji przepływu (np. Strahler) → `river_class` (1..3). Duże rzeki = korytarz 2–3 heksów szerokości (delta).
- **Koryto**: heksy na trasie mogą zmienić typ na `Valley`.
- **Jeziora**: jeżeli zamknięte, wykop wąski outlet do niższego sąsiada.

**Walidacja**: każda rzeka kończy się w morzu/jeziorze; brak „martwych” ślepych odnóg (poza źródłami).

---

## 3) Biomes
- Temperatura (N–S) + wysokość + wilgoć (bliskość rzek/jezior/morza). Wynik = biome enum (np. desert, grassland, forest, alpine, swamp).

---

## 4) Kingdom borders (po krawędziach)
- **Stolice**: wybór w dużych patchach osadnych (Plains/Valley) blisko wody.
- **Ekspansja**: flood-fill z kosztami (region/biome, kara za przekraczanie rzek – ale nie absolutna).
- **Snapping**: preferuj rzeki i góry jako granice. Granice żyją **na krawędziach** między hexami.
- **Drogi**: **nie rozcinamy** – drogi są kaflowe i zawsze ciągłe, dostają tylko tag `traversed_kingdoms`.

---

## 5) Cities & villages
- **Miasta**: Plains/Valley, blisko rzek/jezior/morza; porty na wybrzeżu.
- **Wsie**: gęściej przy drogach i rzekach; min. odstępy.
- Każde królestwo powinno mieć ≥1 miasto (w razie czego re-pick seed).

---

## 6) Roads (w kaflach)
- **Backbone**: MST między miastami + skróty wg `road_aggressiveness`.
- **Trasa**: A* po heksach (koszt wg regionów; rzeki droższe, chyba że most).
- **Maski kierunkowe**: ustaw `road_mask` w heksach trasy → dobór kafla drogi (prosta/łuk/T/krzyż).
- **Mosty**: jeżeli heks ma i `river_mask` ≠ 0, i `road_mask` ≠ 0 → `bridge=true` (wariant mostowy).

---

## 7) Forts
- **Kandydaty**: mosty, przełęcze górskie, granice przy drogach/chokepointach.
- **Limity**: per-kingdom ~ floor(miasta/4), min. 1; globalny `fort_spacing`.
- **Anti face-off**: unikaj par fortów vis‑à‑vis przy krótkim odcinku granicy.

---

## Walidacja końcowa
- Rzeki mają zlewiska i/lub ujścia; jeziora mają odpływy (chyba że endoreiczne).
- Drogi spójne, każde miasto podpięte do sieci.
- Granice tworzą dokładnie `kingdom_count` obszarów.
- Miasta/forty na lądzie (nie na Sea), sensowny teren.

---

## Warstwy danych
- `hex/regions`, `hex/elev` (0..1)
- `hex/rivers` (maski + klasa), `hex/roads` (maski + klasa), `hex/bridges` (bool)
- `edges/borders`
- `points/cities`, `points/villages`, `points/forts`
- `biomes/polygons` (opcjonalnie)

---

## UI
Seed, Map Radius, Kingdom Count=3, Sea%, Mountains%, Lakes%, Road Aggressiveness, Fort Cap/Spacing.
**Eksport:** patrz `docs/MapBundle_Schema.json` i `docs/MapBundle_Format.md`.
