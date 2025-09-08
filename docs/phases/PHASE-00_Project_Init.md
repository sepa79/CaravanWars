PHASE‑00 — Project Init (single project + i18n)

Cel:
- Utworzyć jeden projekt Godot w `game/` i fundament i18n (EN/PL). Bez kodu.

Kroki (konkretne):
1) Utwórz katalog `game/` jako projekt Godot. Ustal nazwę sceny głównej „Main.tscn” (placeholder).  
2) Utwórz podkatalogi (puste): `autoload`, `scenes`, `ui`, `net`, `map`, `systems`, `i18n`.  
3) Spisz w `game/READ_ME_FIRST.md` plan autoloadów: App (nawigacja scen), I18N (język, loader katalogów), Net (tryby), World (stan).  
4) W `docs/i18n/Strings_Catalog_P1.md` potwierdź klucze Phase 1 (menu.*) i uzupełnij brakujące etykiety.  
5) W `docs/i18n/Localization_Guide.md` doprecyzuj zasady pluralizacji PL i fallback EN.  
6) Dodaj do `CHANGELOG.md` wpis „0.1.0 — init docs (single binary, i18n)”.

Artefakty:
- Struktura folderów w `game/` jest opisana i przygotowana.  
- Katalog kluczy P1 istnieje i jest kompletny.

Definition of Done (test ręczny):
- Projekt otwiera się w Godot bez błędów (pusta scena Main).  
- Każda etykieta planowanego Start Menu ma klucz w katalogu.
