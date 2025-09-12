PHASE‑03 — Map (vector; seeded; validations)

Cel:
- Opisać deterministyczny pipeline generacji wektorowej mapy wraz z walidacjami i modelem danych.

Plan i status:

| Obszar | Status | Następne kroki |
| --- | --- | --- |
| Edycja dróg | ✅ Dodawanie/usuwanie dróg; wybór węzłów/krawędzi z podświetleniem; przesuwanie miast ograniczone do granic mapy; czyszczenie usuwa tylko osierocone skrzyżowania | — |
| Walidacja i czyszczenie | ✅ Przycisk „Validate Map” uruchamia `MapGenValidator` oraz `RoadNetwork.cleanup`, odświeża podgląd i snapshot | — |
| Przejścia przez rzeki | ✅ Walidator automatycznie wstawia węzły `bridge` lub `ford` w miejscach przecięcia dróg z rzekami | — |
| Wsie i forty na drogach | ⏳ Brak | • Podczas generacji rozkładać wsie i forty na krawędziach (forty przy mostach i wąskich gardłach)<br>• Narzędzia edycji („Add Village”, „Add Fort”, przesuwanie/usuwanie) |
| Typy dróg | ⏳ Brak | • Obsługa klas dróg (`path`, `dirt`, `roman`) w modelu danych<br>• UI do wyboru typu podczas rysowania lub zmiany istniejących dróg |
| Finalizacja mapy | ⏳ Planowane | • Zastąpić walidację po każdej edycji akcją „Finalize Map” walidującą i czyszczącą mapę tylko raz oraz wysyłającą całość do serwera |
| Snapshot i diff | ⏳ Częściowo | • Snapshot zawiera wsie/forty i typy dróg<br>• Strukturalne zdarzenia diff (`add_node`, `remove_edge`, itp.) |

Map-setup flow:
- Podgląd mapy pojawia się przed stanami READY i GAME.
- Zmiana parametrów (seed, rozmiar itp.) natychmiast aktualizuje podgląd.
- **Start** zatwierdza mapę i przechodzi do gry; **Back** wraca do MENU.

Pipeline szczegółowy:
1) Rozmieszczenie miast: rozstaw punkty zgodnie z „blue‑noise” (np. Poisson‑like) z minimalną odległością między miastami.  
2) Połączenia główne: oblicz połączenia kandydujące (np. triangulacja/Delaunay), zredukuj do MST dla spójności, następnie dodaj k‑najbliższych sąsiadów dla alternatyw (k=1..2).  
3) Wsie i forty: dodaj na krawędziach w odstępach; forty umieszczaj na krytycznych wąskich gardłach (mosty, skrzyżowania).  
4) Rzeki: wygeneruj polilinie źródło→ujście; wygładzaj krzywe; każde przecięcie z drogą konwertuj do węzła `bridge` lub `ford` według reguł.
5) Skrzyżowania: w każdym przecięciu krawędzi dróg dodaj węzeł `crossroad` i rozdziel krawędzie.
6) Regiony: podziel mapę na regiony (np. przez Voronoi po miastach głównych); regiony przypisz do narratorów.  
7) Walidacje: spójność grafu dróg, brak krawędzi „wiszących”, rzeki nie tną dróg bez węzła mostu/brodu, stabilne ID.

Implementacja walidacji: `game/mapgen/MapValidator.gd`.
Manualne testy: `docs/checks/Map_Generation_Checklist.md` oraz `docs/checks/Map_Setup_Checklist.md`.

Model danych — patrz `docs/specs/Map_Data_Model.md`.

Snapshot i diff:
- Snapshot zawiera: meta (seed, wersja), listy node/edge/region.  
- Diff typy: add_node, update_node, remove_node; analogicznie dla edge/region; meta_update.

Testy ręczne:
- Taki sam seed → identyczne rozmieszczenie i identyfikatory.  
- Zmiana seeda → inne rozmieszczenie, inwarianty dalej spełnione.

Definition of Done:
- Pipeline i walidacje kompletne; gotowe do późniejszej implementacji.
