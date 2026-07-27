# Move Party Command

## Purpose and boundary

`MovePartyCommand` sets or replaces the road-navigation order of one physical
Party. It is submitted by player and AI controllers through the canonical
`WorldCommandEnvelope`; it never moves a Party synchronously.

```json
{
  "party_id": "player_party",
  "from_node_id": "wroclaw",
  "to_node_id": "opole"
}
```

`to_node_id` may be any reachable node in the Party's fresh, private
Navigation Knowledge Graph. `from_node_id` is an optimistic physical-context
guard: while idle it must be the current node; while on a road it must be one
of that road's endpoints. A command may replace the target mid-edge. Off-road
orders remain separate spatial commands.

## Accepted transition

An accepted command atomically:

1. validates the target against current owner-scoped navigation knowledge;
2. increments the Party movement generation;
3. stores `{ targetNodeId, generation }` as the current order;
4. schedules one `PartyMovementTickEvent` for the authored cadence.

It does not change edge, progress, position, knowledge, supplies, fatigue, or
arrival state. Replaced generations invalidate their queued ticks; stale ticks
complete harmlessly without mutation or successors.

## Tick semantics

The default authored cadence is one in-world hour in
`data/simulation/party_travel.json`. A valid tick reads current Party state,
order, composition, conditions, terrain, road/track class, seasonal weather,
time-of-day visibility and fresh private
road knowledge. It moves only the physical distance possible during that tick
and schedules exactly one successor when movement can continue.

At a node the next edge is chosen deterministically from current knowledge;
no multi-edge itinerary is stored. A tick may cross nodes and spends leftover
tick time on the newly selected edge. Arrival is a tick outcome, not a
guaranteed arrival intent. Road/track class affects speed and authored geometry
is followed. Coordinate/off-road travel never becomes an implicit road
shortcut.

For a mid-edge target replacement, the next valid tick compares the known
cost through both endpoints. Reversing flips edge orientation and progress but
preserves the exact interpolated physical coordinate. Stable route and node ID
tie-breaks apply.

## Interleaving and pause

All movement, Facility, consumption, encounter and other intents share the
same WorldClock due-time/scheduling-sequence order. Advancing one day performs
only clock advancement; it is equivalent to 24 hourly advances. Encounters or
damage between ticks may alter composition, delay, clear, pause or invalidate
movement. An awaiting-decision Party neither moves nor self-schedules. A legal
resolution resumes one tick chain if an order and capable Party remain.

Waypoints, landmarks and signposts are observed only across the physical
segment traversed by a valid tick. Issuing or changing an order reveals no
knowledge.

## Persistence and bounds

JSON saves retain canonical edge/progress or idle coordinate, current order,
generation, tick ordinal, pending event ID, clock queue, observations, supplies
and fatigue. Save/load and reset preserve deterministic continuation. There is
at most one valid successor per moving Party; invalidated pending events are
bounded by explicit order changes. Completed clock history grows linearly and
is retained for replay/audit in v1.

## Rejections

Missing Party/node, mismatched physical context, off-road busy state, unknown
route or unreachable private target are explicit atomic failures. There is no
fallback to truth, teleport, automatic itinerary, callback or client mutation.
