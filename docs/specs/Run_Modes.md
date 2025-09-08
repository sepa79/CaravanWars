Run Modes — jedna binarka

Tryby:
1) Single Player — uruchom host lokalnie i auto‑join jako klient (w tej samej binarce).  
2) Multiplayer — Host — uruchom host, pokaż dane sesji do dołączenia.  
3) Multiplayer — Join — połącz z hostem po adresie/porcie lub kodzie sesji.  
4) Dedykowany (później) — tryb server‑only uruchamiany flagą w CLI.

Stan maszyny stanów (bez kodu):
- MENU → CONNECTING → READY → GAME → (opcjonalnie) PAUSED → MENU.  
- CONNECTING ma podtypy: starting_host, joining_host, retrying, failed.

Timeouty i błędy:
- Default timeout 10 s na handshake; 3 próby.  
- Błędy wyświetlane przez klucze `errors.*`, z przyciskiem „Retry”.

Uwagi Single Player:
- Host działa in‑process, ale logicznie jest oddzielnym peerem.  
- Port lokalny może być losowy; brak ekspozycji na sieć zewnętrzną.
