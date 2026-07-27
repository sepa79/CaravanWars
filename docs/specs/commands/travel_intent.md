# Travel Intent

This document names the higher-level concept, not a second active command
boundary. In the TypeScript engine the canonical `move_party` envelope is the
travel intent: it stores a replaceable target and generation, then schedules a
`PartyMovementTickEvent`. Clients and AI must not submit a pre-resolved path.

At every reached graph node the next edge is resolved from the Party's current
private Navigation Knowledge Graph. No planned-node array, automatic itinerary,
or guaranteed `ArrivalEvent` is canonical state. Mid-edge target changes keep
the physical position and are adjudicated on the next movement tick.

Off-road `spatial_travel` and `search_area` remain distinct explicit intents
because they follow continuous terrain rather than authored road geometry.
They share WorldClock and physical Party truth but do not silently convert
between navigation modes.
