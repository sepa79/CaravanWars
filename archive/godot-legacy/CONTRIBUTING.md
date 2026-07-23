CONTRIBUTING — workflow

Before you start
- Always read and comply with `RULES_ALWAYS_READ.md`. It documents the mandatory conventions and requirements for every contribution.

Flow:
1. Create an issue titled `PHASE-XX: <description>` with the intended scope.
2. Branch from `develop` using `feature/phase-xx-<short-description>`.
3. Work through the checklist defined in the phase document.
4. Open a PR to `develop` that includes the completed checklist and a `CHANGELOG.md` entry.
5. Secure review from at least one maintainer and squash-merge after approval.

Definition of ready for review:
- The changes stay within a single phase.
- Skip code when the phase only allows documentation/specification work.
- All "Artifacts" and "Definition of Done" items from the phase document are delivered.

Communication:
- Keep PR comments short and focused.
- Capture design discussions in `docs/` and link them from the PR description.
- Run-time validation:
- Execute static checks on each modified GDScript via `godot --headless --path game --check <file>`.
- After static validation, launch the automated singleplayer smoke test using `tools/check.sh game` (or `tools/check.bat both` on Windows) to catch runtime regressions before review.
