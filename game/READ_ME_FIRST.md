GAME — single Godot project (jedna binarka)

Po co jeden projekt?
- Jedno źródło zasobów, jeden eksport binarki.  
- Single Player: host+client in‑process. Multiplayer: Host/Join.  
- Debug UI i shell Narratora jako role w tym samym projekcie.

Planowane katalogi (na razie puste):
- autoload/ — planowane singletons: App, I18N, Net, World, później Debug, Ai
- scenes/ — Main.tscn, StartMenu.tscn (PHASE‑01), później Game.tscn, DebugUi.tscn
- ui/ — panele, dialogi; **tylko klucze i18n** w tekstach
- net/ — logika połączeń i trybów (host/client) — w późniejszych fazach
- map/ — generacja i model mapy (spec w PHASE‑03)
- systems/ — reguły gry (PHASE‑08)
- i18n/ — katalogi językowe (EN/PL)

Konwencje Godot
- Folders: lower_snake_case. Scenes/Scripts: PascalCase.
- Nie dodajemy nic do autoload, dopóki dana faza tego nie wymaga.
