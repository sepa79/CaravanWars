# PHASE-03 — Map (Region-First, Fast Generation)

> **Cel:** Szybka i prosta generacja mapy bez kosztownych region/elev model. Mapa dzielona na *tiles*; stosujemy reguły sąsiedztwa i typów regionów (Morze, Jezioro, Góry, Wzgórza, Równiny, Doliny). Z takiego szkicu wyprowadzamy lekkie pochodne dla rzek, biomów i logicznego routingu dróg.

## Sekwencja (egzekwowana)
1. Terrain (regiony)
2. Rivers
3. Biomes
4. Kingdom borders
5. Cities & villages
6. Roads
7. Forts

## Global parameters (defaults)
- `seed`: int (12345)
- `map_size`: tiles (256)
- `kingdom_count`: int (**3**, UI)
- `sea_pct`: 0.35
- `mountains_pct`: 0.10
- `lakes_pct`: 0.03
- `rivers_cap`: 8
- `fort_global_cap`: 24
- `fort_spacing`: 150 tiles
- `road_aggressiveness`: 0.3

---

## 1) Terrain (regiony)
**Wyjścia:** raster typów (Sea, Lake, Plains, Valley, Hills, Mountains), `sea_mask`, *lekkie* `elev` 0..1 (tylko do spływu i cieniowania).

**Algorytm:**
- **Coastline:** maska morza z prostych kształtów (blob/spline/polygon) deterministycznie z `seed`.
- **Ziarna regionów:** rozsiane po lądzie wg wag. Zasady:
  - Góry w pasmach (korytarze „belt”).
  - Doliny tylko obok gór/wzgórz.
  - Jeziora tylko w lokalnych obniżeniach; inaczej → równiny.
- **Wzrost regionów:** Voronoi+relax lub BFS multi-source na siatce.
- **Lekkie `elev`:**
  - Sea=0.0, Lake=0.1, Valley=0.2, Plains=0.35, Hills=0.6, Mountains=0.9
  - + niewielki jitter i korekta bliskości do gór/mórz.

**Walidacja:** brak jezior na grzbietach; brak pojedynczych pikseli morza na lądzie; doliny stykają się z górami/wzgórzami.

---

## 2) Rivers
**Wyjścia:** polylines rzek z atrybutem szerokości/przepływu.

**Algorytm:**
- Źródła: lokalne maksima w Górach.
- Trasa: A* po siatce na podstawie `elev` (tani koszt w dolinach, droższy pod górę), do morza lub jeziora.
- Łączenie dopływów; korytowanie: zamiana przejścia przez równiny/wzgórza na doliny wzdłuż kanału.

**Zasady:** rzeka musi zakończyć się w morzu lub jeziorze z odpływem (tworzymy wąski „outlet”, jeśli potrzebny).

---

## 3) Biomes
**Wyjścia:** poligony biomów; mapy temp/rain.

**Algorytm:** temp = gradient N–S – lapse_rate*elev; rain = noise + bonus blisko rzek/jezior – rain shadow za górami; klasyfikacja tabelą.

---

## 4) Kingdom borders
Multi-source flood-fill z kosztami terenu/biomu i karą za przekraczanie rzek. Doklejenie do linii rzek gdy różnice kosztów małe. **Nie** rozcinamy dróg.

---

## 5) Cities & villages
Poisson-disc, preferencje: równiny/doliny przy rzekach/jeziorach, porty nad morzem; min odstępy. Każde królestwo powinno mieć ≥1 miasto (re-pick seed jeśli nie).

---

## 6) Roads
Backbone = MST między miastami; trasowanie A* z kosztami typu terenu i mostami/fordami na wąskich przejściach. Drogi **ciągłe** przez granice (tylko tag „traversed_kingdoms”).

---

## 7) Forts
Kandydaty: mosty, wąskie przełęcze, granica blisko dróg, wzgórza. Limit per królestwo ~ `floor(cities/4)` z dolnym limitem 1; globalne odstępy `fort_spacing`; unikamy „face-off” fortów vis-à-vis.

---

## Walidacja i fixer
- Wszystkie rzeki mają zlewisko.
- Jeziora mają odpływ (chyba że dopuszczamy endoreiczne).
- Miasta/forty na lądzie i sensownym nachyleniu (pośrednio z typu regionu).
- Liczba królestw == `kingdom_count`.
- Spójność sieci dróg.

---

## Dane/warstwy
- `terrain/regions` (enum)
- `terrain/elev` (0..1 lightweight)
- `rivers/polylines`
- `biomes/polygons`
- `kingdoms/polygons`
- `settlements/points`
- `roads/polylines`
- `forts/points`

---

## UI
Seed, Map Size, Kingdom Count (**3**), Sea%, Mountains%, Lakes%, Road Aggressiveness, Fort Cap/Spacing. Podgląd etapu (on/off) + opcja re-run pojedynczego etapu do debugowania.

---

## Testy
- Smoke 512 tiles, seed=42 — czasy OK, warstwy powstają.
- High Mountains — rzeki startują w górach, doliny obok.
- Lake Outlets — każdy zbiornik ma ścieżkę do morza/rzeki.
- Forty — limity i odstępy.
- Granice vs drogi — drogi nie rozcinane.

---

**Uzasadnienie:** Region-first jest szybkie, deterministyczne, i daje wiarygodny układ (góry→doliny→rzeki) bez kosztownych region/elev model i erozji.
