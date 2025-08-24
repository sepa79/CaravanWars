# Caravan Wars — Changelog

## 0.3.2-alpha (current)
- See below.

## 0.3.1-alpha
- Player is mobile with **interpolated** movement between cities (click map to travel).
- Trade only in current city; disabled while traveling.
- Start unit: **Hand Cart** (speed 1.0, capacity 10, upkeep food 1/tick placeholder).
- Cargo system: 1 item = 1 slot; capacity enforced.
- Status bar shows Location/Route progress, Cargo used/total, Speed, Gold, Tick.
- Window 1920×1080; English commands: `help`, `info`, `price <loc>`, `move <loc>`.
- Random travel events disabled.

## 0.3.0-alpha
- Big-map layout, multi-player framework, AI/Net hooks, Trade & Caravan panels.

## 0.2.0-alpha / 0.1.0
- Earlier MVP milestones.

## 0.3.2-alpha
- Added high-res **world map background** under the map panel (TextureRect, KEEP_ASPECT_CENTERED).
- Implemented coordinate transform (image pixels → panel) so markers and clicks align after resize.
- Introduced new locations with routes matching road layout on the bitmap:
  Port Niebieskiej Wieży, Twierdza Czerwona, Twierdza Środkowa, Świątynia Południowa,
  Źródło Leśne, Młyn Zachodni, Młyn Wschodni, Wioska Leśna, Wioska Zachodnia, Góry Zachodnie.
- Left legacy aliases (Colony/Mine/Port) for compatibility.
- Kept **vector markers visible** for debugging (to be hidden in final).
- Minor GDScript fixes (sorting, click mapping).
