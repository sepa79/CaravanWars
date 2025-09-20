RULES_ALWAYS_READ — twarde zasady

1) Technologie i styl
- Godot 4.x, **GDScript (typed)**. To nie Python — żadnych idiomów Pythona w komentarzach ani nazwach.
- Wszystko MUSI być typowane statycznie — deklaruj typy dla zmiennych, parametrów i wartości zwracanych.
- Operator `?:` jest zabroniony — używaj `wartosc_if` if `warunek` else `wartosc_else`.
- Pliki scen/zasobów edytuj w Godot. Nie modyfikuj ręcznie `.tscn`/`.tres`.
- Wcięcia: 4 spacje. UTF‑8. LF. Nowa linia na końcu każdego pliku.

2) Nazewnictwo (Godot‑friendly)
- Katalogi: `lower_snake_case` (np. `net`, `map`, `systems`, `autoload`, `ui`).
- Sceny i skrypty: `PascalCase.tscn` / `PascalCase.gd`; klasy w PascalCase.
- Zmienne/funkcje w GDScript: `lower_snake_case`.
- Nie używaj nazw zmiennych kolidujących z metodami wbudowanymi Godota (shadowing). Unikaj m.in.:
  - `show`, `hide`
  - `ready`, `process`, `physics_process`
  - `input`, `unhandled_input`
  - `enter_tree`, `exit_tree`
  - `duplicate`, `free`, `queue_free`
  - `update`, `draw`, `play`, `stop`
  - `scale`, `seed`, `params`
- Gdy odkryjesz nową kolizję nazwy z API Godota, natychmiast dopisz ją do powyższej listy i stosuj nowe nazewnictwo.
- Nie twórz `const` ani aliasów skryptów o nazwach identycznych jak zarejestrowane `class_name` (np. `AssetCatalog`, `LayerInstance`, `MapData`, `Tile`). Jeśli znajdziesz nową kolizję, dopisz ją do tej listy zakazanych aliasów.
- Autoloady (nazwy singletonów): `App`, `I18N`, `Net`, `World`, później `Debug`, `Ai`.

3) I18N (obowiązkowe)
- **Zero** hard‑codowanych tekstów. Wszystko przez klucze. Klucze stabilne, kropkowane: `menu.start_single`, `ui.status.latency`.
- Pliki katalogów językowych: `game/i18n/en.*`, `game/i18n/pl.*`. Język bazowy: `en`. Runtime switch w menu.
- Pluralizacja: opiszemy w `docs/i18n/Localization_Guide.md` (PL ma bardziej złożone reguły).

4) Proces repo
- SemVer + Keep a Changelog. Każda duża zmiana aktualizuje `CHANGELOG.md`.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Każdy PR: checklisty akceptacyjne, link do issue, brak zmian „obok tematu”.
- Dla każdego zmodyfikowanego pliku GDScript uruchom `godot --headless --check`.
- Żadnych sekretów, promptów i danych binarnych bez uzasadnienia.
- Żadnych danych binarnych, nigdy - Codex PR nie obsluguje takich plikow.

5) Zakres faz
- Dopóki faza nie przewiduje implementacji, **nie tworzymy kodu**. Najpierw dokument, potem skeleton, potem kod.

6) Kompatybilność danych
- Nigdy nie zgaduj — korzystaj wyłącznie z wartości zdefiniowanych w aktualnym kodzie lub konfiguracji.
- Nie utrzymujemy kompatybilności wstecznej; jedynym źródłem prawdy jest bieżąca wersja projektu.
