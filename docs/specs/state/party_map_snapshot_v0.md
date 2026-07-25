# Party Map Snapshot v0

## Purpose

`Party Map Snapshot v0` is the actor-filtered debug map boundary for one
observer party. The authoritative region graph remains physical truth, but the
snapshot contains only graph facts known by that party.

## Owner / consumers

- Owner: `packages/world-sim`.
- Consumer: the development Party Map in `apps/truth-map`.
- Non-consumers: simulation mutation, route validation, and durable
  WorldMemory belief storage.

## V0 filtering

For the requested `observerPartyId`, the snapshot includes:

- only that party's own physical snapshot;
- nodes that are endpoints of its known routes, plus its current or active
  travel endpoints;
- only routes in `knownRouteIds`;
- only route waypoints and landmark marks observed through the authoritative
  observation layer;
- no terrain-area geometry in v0: a route observation may remember a terrain
  area id without revealing its authoritative full shape.

True coordinates of included marks are allowed only because this is a
development layout adapter. Their presence does not make the Party Map a save
or player parchment contract.

An unknown observer party fails explicitly. It must never fall back to a truth
snapshot or an empty anonymous view.

## Security invariant

Filtering happens in `packages/world-sim` before serialization. A browser must
not receive the full graph and hide unknown facts locally.

## Compatibility notes

This v0 snapshot is runtime visibility and map-debug state, not durable
WorldMemory. Observation-driven marks will extend this same boundary; they
must not create a second physical graph.
