RULES_ALWAYS_READ — twarde zasady

1) Technologie i styl
- Godot 4.x, **GDScript (typed)**. To nie Python — żadnych idiomów Pythona w komentarzach ani nazwach.
- Pliki scen/zasobów edytuj w Godot. Nie modyfikuj ręcznie `.tscn`/`.tres`.
- Wcięcia: 2 spacje. UTF‑8. LF. Nowa linia na końcu każdego pliku.

2) Nazewnictwo (Godot‑friendly)
- Katalogi: `lower_snake_case` (np. `net`, `map`, `systems`, `autoload`, `ui`).
- Sceny i skrypty: `PascalCase.tscn` / `PascalCase.gd`; klasy w PascalCase.
- Zmienne/funkcje w GDScript: `lower_snake_case`.
- Autoloady (nazwy singletonów): `App`, `I18N`, `Net`, `World`, później `Debug`, `Ai`.

3) I18N (obowiązkowe)
- **Zero** hard‑codowanych tekstów. Wszystko przez klucze. Klucze stabilne, kropkowane: `menu.start_single`, `ui.status.latency`.
- Pliki katalogów językowych: `game/i18n/en.*`, `game/i18n/pl.*`. Język bazowy: `en`. Runtime switch w menu.
- Pluralizacja: opiszemy w `docs/i18n/Localization_Guide.md` (PL ma bardziej złożone reguły).

4) Proces repo
- SemVer + Keep a Changelog. Każda zmiana aktualizuje `CHANGELOG.md`.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Każdy PR: checklisty akceptacyjne, link do issue, brak zmian „obok tematu”.
- Żadnych sekretów, promptów i danych binarnych bez uzasadnienia.

5) Zakres faz
- Dopóki faza nie przewiduje implementacji, **nie tworzymy kodu**. Najpierw dokument, potem skeleton, potem kod.
