# Viewport-Locked Game UI v1

Status: active.

The browser game shell occupies exactly the current dynamic viewport. `html`,
`body`, and the shell have bounded height, `min-height: 0`, and hidden page
overflow. The top bar and view tabs are fixed-height rows; the map receives the
remaining space through `minmax(0, 1fr)`. Canvas backing dimensions follow its
actual bounded client rectangle after resize.

The map is the desktop primary surface with one contextual panel. Small
viewports show either the map or one full-stage context view. Caravan,
contract, journal, commands, AI, and explicitly labelled truth diagnostics are
mutually exclusive views. Journal and diagnostic history use bounded pages;
no gameplay panel uses a hidden scrolling region. Encounter decisions use the
native modal dialog boundary, focus the first legal affordance, trap keyboard
focus, and become a full-screen decision view on small screens.

The UI owns no gameplay truth. Reads come from filtered API projections and
all actions retain the canonical `WorldCommandEnvelope`. `/api/health`
identifies the active API version and Expedition route. The development command
uses a watching server so server-route changes restart the process; automated
tests use the non-watching `start:truth-map` command for clean lifecycle.

Conformance covers 1920×1080, 1440×900, 1366×768, 1280×720 and 390×844. Every
view and encounter must keep document and body scroll dimensions within the
viewport, keep visible controls inside its bounds, avoid panel overflow, retain
a positive bounded map size, and survive resize without reload.
