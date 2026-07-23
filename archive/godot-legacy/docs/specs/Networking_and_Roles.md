Networking & Roles

Model:
- Host (autoritatywny) rozsyła SNAPSHOT/DIFF; klienci odsyłają COMMAND.  
- Role: player, narrator, observer, admin (claim podczas dołączenia).  
- Narrator (Phase‑07) podlega throttlingowi i audytowi.

Handshake:
- HELLO (wersja, możliwości) → AUTH (gość lub token MVP) → ROLE_CLAIM → REGION_SUBSCRIBE (jeśli narrator) → SNAPSHOT.  
- PING/PONG utrzymuje sesję; brak PONG → reconnect lub fail.

Uprawnienia (skrót):
- Player — tylko swoje komendy.  
- Narrator — propozycje zdarzeń w przypisanych regionach.  
- Observer — tylko odczyt.  
- Admin — pełne narzędzia (poza MVP).
