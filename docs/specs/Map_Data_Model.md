Map Data Model

Elementy:
- MapViewNode: id, typ (city, village, fort, crossroad, bridge, ford), pos2d, attrs.
- MapViewEdge: id, typ (trade_route, river), polyline, endpoints (node ids), attrs.  
- MapViewRegion: id, granica logiczna (lista node'ów lub bbox), narrator.  
- Meta: seed, version, generated_at, rules.

Inwarianty:
- Stabilne ID w trakcie sesji.  
- Graf dróg spójny między miastami głównymi.  
- Brak krawędzi wiszących; każda krawędź ma dwa węzły końcowe.
- Rzeki przecinają drogi tylko w węzłach `bridge` lub `ford`.
