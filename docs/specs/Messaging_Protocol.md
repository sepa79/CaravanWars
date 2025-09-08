Messaging Protocol (opis)

Pola wspólne: correlation_id, sender_counter, sent_at, received_at.

Typy:
- HELLO, AUTH, AUTH_OK/FAIL, ROLE_CLAIM/ROLE_SET  
- REGION_SUBSCRIBE/UNSUBSCRIBE  
- SNAPSHOT, DIFF, EVENT, COMMAND  
- PING/PONG, ERROR

Reguły:
- Komendy poza zakresem roli/regionu → ERROR.  
- Wybrane DIFF wymagają ACK; brak ACK → retransmisja lub SNAPSHOT naprawczy.  
- Log zdarzeń ma pokazywać typ, źródło, cel, wynik.
