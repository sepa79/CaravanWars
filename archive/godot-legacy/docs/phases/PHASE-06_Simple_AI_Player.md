PHASE‑06 — Simple AI Player (logs + minimal movement)

Cel:
- Określić prostą politykę decyzji AI i strukturę logów.

Polityka:
- Wybierz cel: najbliższe miasto liczone liczbą krawędzi (BFS) albo „random z listy miast”.  
- Oblicz trasę po grafie krawędzi; idź węzeł po węźle.  
- Przy blokadzie krawędzi (EVENT) przelicz BFS i zapisz powód zmiany.

Logi (pola):
- time, actor_id, decision, from_node, to_node, chosen_path (lista node_id), estimated_cost, reason.  
- Poziomy: info/warn/error.

Testy ręczne:
- Brak ścieżki → log warn i zatrzymanie.  
- Zmiana topologii (zamknięty most) → log decyzji i nowa trasa.

DoD:
- Opisy wystarczają do implementacji bez zgadywania.
