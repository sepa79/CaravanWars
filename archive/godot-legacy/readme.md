# CaravanWars — README (Concept Document)
> **Project reset — September 2025:** The Godot game project has been reset to a clean slate under version 0.2.3; every system is being rebuilt from scratch.
## Historia projektu

### Wersja w stylu autora
CaravanWars to projekt, który zaczął się jako mały eksperyment.  
Chciałem sprawdzić, jak da się połączyć moje pomysły na grę ekonomiczną z AI, tak żeby nie pisać wszystkiego samemu.  
Dlatego poprosiłem ChatGPT, żeby w tym pomagał – generował kod, grafiki, mockupy i różne rozwiązania.  
Z czasem projekt urósł do czegoś większego niż tylko test.

AI nie jest tu tylko narzędziem, ale też współautorem – w praktyce to ono wykonuje większość pracy, a ja pilnuję kierunku, podejmuję decyzje i składam wszystko razem.  
W pewnym sensie AI samo będzie później „grało” w tę grę, razem z ludźmi, bo taki jest plan rozwoju.

CaravanWars powstało więc z potrzeby połączenia dwóch światów:  
- mojego pomysłu na klimat i zasady gry,  
- i zdolności AI do szybkiego tworzenia rzeczy, które w pojedynkę zajęłyby miesiące.  

---

### Wersja w stylu AI
CaravanWars narodziło się z prostej idei: połączyć klasyczne inspiracje grami handlowymi i ekonomicznymi z czymś, co nigdy wcześniej nie było możliwe – aktywną współpracą z AI jako równorzędnym współautorem.  

Projekt zaczął się od kilku luźnych notatek i testów, ale szybko rozwinął się w eksperyment: czy da się stworzyć grę, w której sztuczna inteligencja nie tylko pisze kod i grafiki, ale też staje się częścią samej rozgrywki?  

W tej współpracy role są jasne:  
- człowiek wyznacza kierunek, klimat i najważniejsze decyzje,  
- AI przejmuje ciężar implementacji, prototypów i zasobów.  

CaravanWars jest więc nie tylko grą o karawanach, handlu i podróżach, ale też dowodem na to, że proces tworzenia gier można zbudować inaczej – w duecie człowiek–AI.  

---

### Jak powstały te komentarze
Na prośbę autora przygotowałem dwie wersje wprowadzenia: pierwszą w jego własnym stylu (notatkowo, prosto, rzeczowo), a drugą w moim (bardziej narracyjnie i klarownie).  
Dzięki temu można zobaczyć różnicę i wybrać, która lepiej pasuje do nastroju projektu.  

## 🎮 Overview

CaravanWars is a strategy and trading game set in a medieval-inspired world without telecommunication. Information, goods, and influence travel only as fast as caravans or couriers. Players build wealth and reputation by managing caravans, gathering and trading information, and navigating both economic and tactical challenges.

The game is designed for **singleplayer (with immersive tactical battles)** and **multiplayer (persistent world with streamlined auto-resolve combat)**. AI players coexist with human players and operate under the same knowledge restrictions, creating a dynamic, living economy.

---

## 🔹 Core Mechanics

### 1. **Travel & Time**

* Distances have real strategic weight — caravans need days/weeks to move between cities.
* World operates on a tick system (time advances in fixed intervals).
* Information also travels with caravans or hired couriers — players act on potentially outdated knowledge.

### 2. **Information Economy**

* Each player (human or AI) has a personal knowledge base of prices, goods, and events with timestamps.
* Information spreads:

  * **Caravans** carry market news as well as goods.
  * **Couriers** can be hired for faster (but costly) information delivery.
  * **Allies** or friendly caravans can share intel.
* Information is a resource: it can be traded, withheld, or even falsified.

### 3. **Markets & Trade**

* Cities produce and consume goods at varying rates.
* Prices fluctuate based on supply, demand, events, and player actions.
* Players profit by planning trade routes — but success depends on the accuracy and timeliness of their information.

### 4. **Narrator System**

Two narrative layers enrich the game world:

* **Global Narrator (Chronicler)** — aware of the full truth but only reveals events as they could realistically spread (wars, famines, festivals).
* **Local Narrators (Mayors)** — city voices with limited knowledge and personal agendas (contracts, propaganda, local crises).
* **Personal Diary (optional)** — presents what a specific player *actually knows*, reinforcing the uncertainty of information.

### 5. **AI & Players**

* AI players function under the same knowledge limitations as humans.
* They make trade and strategic decisions based on outdated or incomplete intel.
* External AI can connect via the same multiplayer bridge as human clients, acting as full players.

### 6. **Combat System**

* **Singleplayer**: Tactical turn-based battles (inspired by Battle Brothers, Banner Saga). Players directly command their caravan guards and mercenaries.
* **Multiplayer**: Combat auto-resolves to avoid blocking game flow. Results are determined by the same stats as tactical battles.
* Optional auto-resolve even in SP (risk of heavier losses vs. manual control).

### 7. **Multiplayer Architecture**

* **Persistent world**: server simulates world time, markets, caravans, and information spread.
* Clients (humans or external AI) connect and receive only the knowledge their caravans could plausibly know.
* Asynchronous play is possible: caravans keep moving and trading even when players are offline.

### 8. **Encounters & Events**

* Bandit raids, natural disasters, festivals, political conflicts, and city contracts enrich the world.
* Events are delivered via narrators and may spread with delays.
* Deception and misinformation are possible gameplay layers.

---

## 🔹 Gameplay Loop

1. Receive and interpret information (from caravans, allies, narrators).
2. Plan caravan routes and trading strategies.
3. Move caravans across the world map (time passes, risks emerge).
4. Resolve encounters (combat, events, negotiations).
5. Update knowledge base as new intel arrives.
6. Reinvest profits, grow influence, and expand network.

---

## 🔹 Design Philosophy

* **Information is power** — outdated or false intel creates risk and drama.
* **Distance matters** — travel and communication delays are core gameplay levers.
* **Narrative immersion** — the world "talks back" through narrators and NPC voices.
* **Scalable multiplayer** — from singleplayer with AI to persistent asynchronous multiplayer.
* **Strategic risk management** — choosing when to trust, when to act, and when to wait.

---

## 🔹 Future Extensions

* Guilds/alliances between players.
* Political systems (cities forming leagues, wars, embargoes).
* Expanded role of misinformation and espionage.
* Character development for caravan leaders and guards.
* Replayable "chronicles" of campaigns generated by narrators.

---

## 📌 Status

This README reflects **conceptual design discussions**. Implementation details (world simulation, Codex integration, AI bridge, and tactical battle layer) will be handled in later development stages.
