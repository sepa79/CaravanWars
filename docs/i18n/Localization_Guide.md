Localization Guide — EN & PL

Cel:
- Cały UI bazuje na kluczach. EN jako fallback. Runtime switching w Start Menu.

Zasady kluczy:
- Nazwy kropkowane, stabilne, lower_snake_case w segmentach: `menu.start_single`, `ui.status.latency`.
- Przestrzenie nazw: menu.*, ui.*, net.*, errors.*, map.*, debug.*, roles.*, common.*
- Nie używaj kluczy opisujących wygląd („big_button”). Klucze opisują **znaczenie**.

Pluralizacja i gramatyka (PL/EN):
- W PL rozważamy co najmniej formy 1, kilka (2–4), wiele (5+).  
- Komunikaty liczebnikowe projektuj tak, aby dało się je obrać w osobne klucze zamiast łączyć reguły na starcie.

Format liczb i dat:
- Daty w UI wyłącznie opisowe lub ISO, nie lokalizujemy jeszcze nazw miesięcy.  
- Liczby z separatorem tysięcy wg EN, a w PL spacja tysięczna — na razie unikamy w MVP.

Braki w katalogu:
- Gdy brakuje klucza, UI ma pokazać czytelny placeholder `[key]` — szybko wychwytujemy błędy.

Przegląd i testy:
- Każdy PR z UI musi dodać klucze i ich tłumaczenia w EN i PL.  
- Test ręczny: przełącz język w menu i potwierdź, że wszystkie etykiety się zmieniają.
