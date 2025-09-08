Map Data Model

Elementy:
- Node: id, typ (city, village, fort, crossing, bridge), pos2d, attrs.  
- Edge: id, typ (trade_route, river), polyline, endpoints (node ids), attrs.  
- Region: id, granica logiczna (lista node'ów lub bbox), narrator.  
- Meta: seed, version, generated_at, rules.

Inwarianty:
- Stabilne ID w trakcie sesji.  
- Graf dróg spójny między miastami głównymi.  
- Rzeki przecinają drogi tylko w węzłach `bridge` lub `ford`.
