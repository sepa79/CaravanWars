PHASE‑07 — Narrators (shell)

Cel:
- Zdefiniować rolę narratora jako klient w tej samej binarce: rejestracja, regiony, subskrypcje, ograniczenia.

Komendy narratora (ramy):
- Propozycja zdarzenia w regionie (opis, przewidywany efekt, czas trwania).  
- Prośba o modyfikację atrybutu elementu (np. tymczasowe zamknięcie krawędzi).  
- Zapytanie o stan regionu.

Ograniczenia i bezpieczeństwo:
- Throttling: max X komend/min/region (wartość X ustalona w implementacji; sugeruj 6/min).  
- Audyt: każda komenda ma correlation_id i wynik akceptacji/odrzucenia.

DoD:
- Zdefiniowane limity, zakresy i logowanie działań.
