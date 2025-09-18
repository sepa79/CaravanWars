Agents
======

 - Always read and follow `RULES_ALWAYS_READ.md` for repository-wide requirements.
 - Before committing, run `godot --headless --path game --check <modified .gd files>` for every GDScript file you change.
 - After static checks, execute the runtime validation via `tools/check.sh game` (or `tools/check.bat both` on Windows) to exercise the singleplayer startup flow.
