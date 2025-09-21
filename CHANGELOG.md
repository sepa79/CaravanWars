Changelog

Unreleased
- Expanded the map debugger layout so the 3D preview fills the window while controls float in a compact overlay.
- Ensured the debug map viewport's internal render surface resizes with the window so the 3D preview truly fills the screen.
- Added orbit-style mouse controls to the debug map viewer so artists can pan, rotate, tilt, and zoom the preview.
- Added a map debugger entry to the main menu that opens a dedicated screen for the deterministic debug board showcase.
- Fixed the debug map viewport hit testing so orbit camera controls respond inside the resized debugger layout.
- Set the default window size to 1920x1080 and allowed resizing to match common desktop workflows.

0.2.2 — 2025-09-20
- Restarted the hex map generator work with a stubbed pipeline triggered when singleplayer or host setup begins, producing a typed `MapData` dataset immediately.
- Asset catalog entries now resolve to concrete `res://` scene files so Phase 1 draw stacks carry loadable resources into the game scene.

0.2.0 — 2025-09-19
- Delivered the second proof of concept focusing on the map setup UI and preview experience.

0.1.82 — 2025-09-15
- Captured the early proof of concept that established the initial hex map generator and terrain pipeline.
