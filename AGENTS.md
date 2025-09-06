# AGENTS Instructions

## GDScript Guidelines
- Use GDScript 4 with static typing whenever possible.
- Name GDScript files using PascalCase (e.g., `SimpleTraderBrain.gd`).
- Name variables and functions using snake_case.
- Indent with 4 spaces.
- Order script sections: extends -> signals -> constants -> variables -> functions.
- Use `@onready` for node references that depend on the scene tree.

## Server Authority
- The server is the single source of truth for all game state.
- Client code must not make authoritative decisions; it should only display state or send requests.
- All state updates and validations must go through the server.
- Avoid duplicating server logic on the client; rely on data returned from the server instead.

## Prepare Merge Procedure
When a user asks to "prepare merge":
1. Run `git fetch origin` and merge the latest `origin/main` into the current branch.
2. Update the `VERSION` file.
3. Add an entry to `CHANGELOG.md` summarizing changes.
4. Update any relevant documentation such as `README.md`.
5. Commit with a message that references the version.

## Testing
- For any change to GDScript or project logic, run `godot --headless --path . --check` and ensure it passes.
- Documentation-only changes do not require tests.
