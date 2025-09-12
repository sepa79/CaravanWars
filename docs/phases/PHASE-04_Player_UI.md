PHASE‑04 — Player UI (map view + side panel + status + log)

Cel:
- Zaprojektować UI gracza w szczegółach opisowych.

For map behaviour refer to `/docs/map` — this phase covers only the player interface.

Elementy UI (opis):
- Mapa na całym ekranie.  
- Panel boczny: przełączniki warstw (nodes/edges/regions), sekcja szczegółów zaznaczonego elementu (nazwa, typ, atrybuty).  
- Pasek statusu: rola, region, seed, opóźnienie, stan połączenia (i18n klucze z `common.*`, `net.*`).  
- Log zdarzeń: lista ostatnich EVENT/DIFF/ERROR z filtrem po typie.

Interakcje:
- Pan/zoom; kliknięcie wybiera węzeł/krawędź; tooltip pokazuje nazwę, typ, podstawowe atrybuty.  
- Filtry panelu aktualizują widoczność warstw w czasie rzeczywistym.

Stany:
- Empty: brak połączenia. Error: rozłączenie (użyj `net.disconnected` + przycisk `common.retry`).

Definition of Done:
- Specyfikacja oparta na i18n; kompletna lista elementów i ich zachowań.
