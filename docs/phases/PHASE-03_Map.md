PHASE‑03 — Map (vector; seeded; validations)

Cel:
- Opisać deterministyczny pipeline generacji wektorowej mapy wraz z walidacjami i modelem danych.

Map-setup flow:
- Podgląd mapy pojawia się przed stanami READY i GAME.
- Zmiana parametrów (seed, rozmiar itp.) natychmiast aktualizuje podgląd.
- **Start** zatwierdza mapę i przechodzi do gry; **Back** wraca do MENU.

Pipeline szczegółowy:
1) Rozmieszczenie miast: rozstaw punkty zgodnie z „blue‑noise” (np. Poisson‑like) z minimalną odległością między miastami.  
2) Połączenia główne: oblicz połączenia kandydujące (np. triangulacja/Delaunay), zredukuj do MST dla spójności, następnie dodaj k‑najbliższych sąsiadów dla alternatyw (k=1..2).  
3) Wsie i forty: dodaj na krawędziach w odstępach; forty umieszczaj na krytycznych wąskich gardłach (mosty, skrzyżowania).  
4) Rzeki: wygeneruj polilinie źródło→ujście; wygładzaj krzywe; każde przecięcie z drogą konwertuj do węzła `bridge` lub `ford` według reguł.  
5) Skrzyżowania: w każdym przecięciu krawędzi dróg dodaj węzeł `crossing` i rozdziel krawędzie.  
6) Regiony: podziel mapę na regiony (np. przez Voronoi po miastach głównych); regiony przypisz do narratorów.  
7) Walidacje: spójność grafu dróg, brak krawędzi „wiszących”, rzeki nie tną dróg bez węzła mostu/brodu, stabilne ID.

Implementacja walidacji: `game/map/MapValidator.gd`.
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
