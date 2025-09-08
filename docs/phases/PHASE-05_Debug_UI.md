PHASE‑05 — Debug UI (server‑side view)

Cel:
- Widok inspekcyjny hosta dostępny w tej samej binarce (tryb tylko dla roli admin/debug).

Zakres:
- Lista peerów: id, rola, stan, opóźnienie, subskrypcje regionów.  
- Szczegóły peera: ostatnie COMMAND, walidacje, ostatni ERROR, liczniki send/recv.  
- Timeline snapshot/diff: możliwość pauzy i przeglądania.  
- Filtry: po roli, regionie, typie wiadomości.

Testy ręczne:
- Dodanie nowego peera pojawia się na liście wraz z subskrypcjami.  
- Pauza zatrzymuje timeline i pozwala przejrzeć historię.

DoD:
- Dokument kompletny, spójny ze specem protokołu.
