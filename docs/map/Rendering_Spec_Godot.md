
# Spec Rysowania Mapy w Godot 4 (Wektor)

## Warstwy (od spodu)
1) Tło (ColorRect / pattern niskiej alfa)
2) Komórki climate/biome (Polygon2D z delikatnym tintem; toggle w UI)
3) Rzeki (Curve2D → draw_polyline, 1–3 px zależnie od zoomu)
4) Drogi:
   - **Roman**: linia ciągła, grubsza; jasny rdzeń + ciemny obrys.
   - **Road**: średnia, lekki jitter.
   - **Path**: cienka, przerywana.
5) Crossingi (bridge/ford) — **ikony** na węzłach.
6) Fortece — ikony (fort/fort‑pair).
7) Osady — ikony (city, city‑capital, fort).
8) Granice — linia przerywana shaderem (dash w screen space).
9) Etykiety — nazwy królestw/miast/rzek; MSDF font.

## Ikony
- Lokalizacja: `assets/icons/mono` (jednokolor) i `assets/icons/color` (kolor). 
- Import: jako Texture2D (SVG) lub raster (64–128 px) do atlasu.
- Instancje: MultiMeshInstance2D dla setek znaczników.

## LOD
- Daleko: granice, Roman, miasta, nazwy królestw.
- Średnio: drogi Road, rzeki, fortece, crossingi, nazwy miast.
- Blisko: Path, etykiety rzek, patterny biomów.

## Wydajność
- Batch per klasa drogi (łącz polilinie w chunkach).
- Cache statycznych warstw do ViewportTexture przy zmianie zoomu.
- Unikaj SVG z dużą liczbą węzłów (nasze są proste, 24×24 grid).

## Mapowanie ikon
- city → `cw-icon-city(-color).svg`
- city-capital → `cw-icon-city-capital(-color).svg`
- bridge → `cw-icon-bridge(-color).svg`
- ford → `cw-icon-ford(-color).svg`
- fort → `cw-icon-fort(-color).svg`
- fort-pair → `cw-icon-fort-pair(-color).svg`
- border-gate → `cw-icon-border-gate(-color).svg`
- (opcjonalnie) harbor, watchtower, ruins
