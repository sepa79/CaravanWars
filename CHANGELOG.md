# Caravan Wars — Changelog

## 0.3.7-alpha (current)
- World tab simplification: removed Player/Location selectors and the Player Details panel; added Loc/Dest/ETA columns directly to the Players table (read-only). Markets matrix and legend retained.
- Console removed: dropped Commander autoload, console UI and handlers; travel logs routed via Server broadcast. Trade tab unaffected (uses Orders API).
- Parser/type fixes: normalized indentation and replaced variant-inference `:=` where needed; reworked `DB.can_transact()` to deterministic if/elif.

## 0.3.6-alpha
- MVP: deterministic trade pricing and unified Orders API (`order_move`, `order_buy`, `order_sell`).
- Added economy API in `autoload/DB.gd`: `price_of`, `stock_of`, `can_transact`.
- Prices now computed as base + location modifier (no stock/randomness). `Location.update_prices` updated accordingly.
- Single transaction entrypoint for UI/AI/console; existing console commands now map to `order_*`.
- Server loop emits `Sim.player_arrived(player_id, location_id)` on arrival.
- World tab: added selectors for Player/Location, player details, selected market table, and Buy/Sell/Move actions.
- Kept MayorNarrator restock logic; UI reflects updated stock.

## 0.3.5-alpha
- Trading: locations now accept selling any goods (not only those currently in stock). `Location.list_goods()` returns all defined goods, so the Trade panel can always sell; buying remains limited by stock and gold.
- World tab redesign: two tables — Players summary (name, gold, total cargo) and Markets matrix (locations as rows, goods IDs as columns with qty/price), plus a legend mapping IDs to names.
- Live refresh: World tab updates on every server snapshot via `WorldViewModel.notify_data_changed()`, with a lightweight periodic check as a safety net.
- Data normalization: fixed mixed stock keys (int vs string) in market updates (MayorNarrator) and normalized incoming snapshot data on the client. This ensures UI always reflects current stocks/prices.
- GDScript cleanup: replaced unsafe `String(...)` casts with `str(...)` where needed; minor indentation fixes and robustness improvements.

## 0.3.4-alpha
- MVP Pack #2 (rev): authoritative server for movement and trading; UI/console/AI only enqueue commands; prices sourced exclusively from location methods; server log replicated to clients.
- Unified Orders API for UI/AI/console.
- Centralized city info in `Location` objects with translation keys, stock, and pricing.
- Updated database and world logic to use the new location model.
- Fixed trade state indentation in `Game.gd`.

## 0.3.3-alpha
- Added translations for user interface strings.
- Restored world map background image.

## 0.3.2-alpha
- Added high-res **world map background** under the map panel (TextureRect, KEEP_ASPECT_CENTERED).
- Implemented coordinate transform (image pixels → panel) so markers and clicks align after resize.
- Introduced new locations with routes matching road layout on the bitmap:
  Harbor, Central Keep, Southern Shrine, Forest Spring, Mills, Forest Haven, Mine.
- Removed legacy location aliases.
- Kept **vector markers visible** for debugging (to be hidden in final).
- Minor GDScript fixes (sorting, click mapping).

## 0.3.1-alpha
- Player is mobile with **interpolated** movement between cities (click map to travel).
- Trade only in current city; disabled while traveling.
- Start unit: **Hand Cart** (speed 1.0, capacity 10, upkeep food 1/tick placeholder).
- Cargo system: 1 item = 1 slot; capacity enforced.
- Status bar shows Location/Route progress, Cargo used/total, Speed, Gold, Tick.
- Window 1920×1080; English commands: `help`, `info`, `price <loc>`, `move <loc>`.
- Random travel events disabled.
- Added hooks for multiplayer and refactored UI.

## 0.3.0-alpha
- Big-map layout, multi-player framework, AI/Net hooks, Trade & Caravan panels.

## 0.2.0-alpha / 0.1.0
- Earlier MVP milestones.
