PHASE‑01 — Start Menu + Language Toggle

Cel:
- Pokazać Start Menu z pozycjami: Single Player, Multiplayer (Host/Join), Settings, Language (EN/PL), Quit.  
- Przełącznik języka działa w runtime i zmienia wszystkie widoczne etykiety.

Layout (opis słowny, bez klas/nazw UI):
- Tytuł gry po środku u góry.  
- Lista przycisków w kolumnie: Single Player; Multiplayer (otwiera podmenu z Host/Join); Settings; Language (przełącznik EN/PL); Quit.  
- W prawym dolnym rogu wersja i typ buildu.  
- Dla pozycji jeszcze niegotowych wyświetlamy panel informacji „Jeszcze niedostępne”.

Teksty:
- Wszystkie etykiety z `docs/i18n/Strings_Catalog_P1.md`.  
- Brak „tymczasowych” hard‑coded tekstów — nawet informacja o niedostępności jest kluczem.

Przepływy:
- Klik „Language” — natychmiastowe przełączenie EN↔PL (bez restartu).  
- „Multiplayer” → podmenu z przyciskami „Host” i „Join” (w tej fazie tylko panel „Jeszcze niedostępne”).  
- „Quit” — kończy aplikację.  
- „Settings” — panel placeholder (też „Jeszcze niedostępne”).

Dostępność i sterowanie:
- Strzałki w górę/dół i Enter aktywują wybór; Escape wraca/wychodzi z podmenu.  
- Focus zawsze widoczny.  
- Przyciski mają czytelne etykiety w aktywnym języku.

Testy ręczne (zaakceptuj wszystko w PR):
- Po uruchomieniu widzę tytuł i wszystkie pozycje menu w domyślnym języku.  
- Zmiana języka na PL aktualizuje **wszystkie** etykiety; przełączenie na EN przywraca EN.  
- Wejście w Multiplayer pokazuje Host/Join i panel „Jeszcze niedostępne”.  
- „Quit” zamyka aplikację.  
- Nie ma żadnego tekstu bez klucza (brak placeholderów `[key]`).

Definition of Done:
- Start Menu kompletne opisowo; i18n działa w runtime (wymaganie projektowe zapisane).  
- `CHANGELOG.md` z wpisem o ukończonej fazie.
