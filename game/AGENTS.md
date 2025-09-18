Agents
======
 - Follow rules in `../RULES_ALWAYS_READ.md`.
 - For each modified `.gd` file under `game/`, run `godot --headless --path game --check <file>` before committing.
 - After static checks, run `tools/check.sh game` (or `tools/check.bat both` on Windows) to perform the runtime singleplayer smoke test.
