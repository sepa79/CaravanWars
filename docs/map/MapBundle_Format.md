# MapBundle (Hex; rzeki/drogi w kaflach)

`*.cwmap` to JSON z sekcjami: `meta`, `hexes`, `edges`, `points`, `labels`.

- **meta**: wersja, seed, promień mapy, liczba królestw, parametry generatora.
- **hexes**: lista hexów (q,r) z typem regionu i lekką wysokością 0..1 oraz cechami **rzek/drog** w postaci **masek kierunkowych**:
  - `river_mask` (0..63) – bity kierunków rzeki w heksie; `river_class` (1..3), `is_mouth` (ujście).
  - `road_mask` (0..63) – bity kierunków drogi; `road_class` (track/road/highway); `bridge` – most jeśli heks ma i rzekę, i drogę.
- **edges**: **tylko granice** na krawędziach (rzeki i drogi nie są tutaj).
- **points**: miasta, wsie, forty, porty.
- **labels**: opcjonalne etykiety do renderingu.

**Wizualizacja:** wariant kafla (prosta/łuk/T/krzyż/źródło/ujście) wybierany na podstawie maski kierunkowej.
