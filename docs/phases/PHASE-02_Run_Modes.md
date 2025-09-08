PHASE‑02 — Run Modes (Single host+join; Multi Host/Join)

Cel:
- Zdefiniować szczegółowo zachowanie aplikacji dla trybów Single i Multiplayer w ramach jednej binarki. Bez kodu.

Maszyna stanów (tablica):
- MENU — wejście: uruchomienie aplikacji; wyjście: wybór Single/Host/Join.  
- CONNECTING.starting_host — tworzenie hosta (lokalnie lub sieciowo).  
- CONNECTING.joining_host — łączenie do hosta.  
- CONNECTING.retrying — ponawianie prób po błędzie.  
- READY — po udanym połączeniu: załaduj scenę Game.  
- GAME — rozgrywka; z tego stanu można przejść do PAUSED lub z powrotem do MENU.  
- FAILED — panel błędu z opcjami Retry/Back.

Parametry techniczne (opisowo):
- Timeout na handshake: 10 s; max 3 próby.  
- W Single Player port lokalny nie jest eksponowany; w Multi Host port może być konfigurowalny w Settings (w późniejszej fazie).  
- Komunikaty błędów muszą używać kluczy `errors.*` i zawierać przycisk „Retry”.

Checklist testów ręcznych:
- Single Player: wybór powoduje „starting_host” → „ready” → wejście do Game.  
- Multiplayer Host: wybór powoduje „starting_host”; pokazuje stan hostowania; Join wyświetla formularz adresu/kodu (placeholder w tej fazie).  
- Multiplayer Join: wejście do formularza; próba z nieprawidłowym adresem pokazuje `errors.invalid_address`.

Definition of Done:
- Dokumentacja kompletna; przypadki błędów i retry opisane; i18n klucze uwzględnione.
