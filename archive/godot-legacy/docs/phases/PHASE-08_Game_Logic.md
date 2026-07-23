PHASE‑08 — Game Logic (first rules)

Cel:
- Pierwszy pakiet reguł serwerowych.

Reguły minimalne:
- Koszt ruchu po krawędzi = długość polilinii * współczynnik drogi (stała na start).  
- Blokady krawędzi: mają źródło, czas trwania, skutek (brak przejazdu lub kara czasowa).  
- Cel: dostawa A→B w limicie czasu; przekroczenie = porażka.

Priorytety rozstrzygania:
- Blokada > ruch. W razie konfliktu ruch jest anulowany i logowany jako EVENT.  
- W przypadku sprzecznych diffów — ostatni DIFF z największym licznikiem wygrywa.

Testy ręczne:
- Symulacja dostawy na trasie bez blokad (sukces).  
- Zablokowanie mostu w trakcie (wymuszona zmiana trasy lub porażka).

DoD:
- Dokument kompletny i spójny z wcześniejszymi fazami.
