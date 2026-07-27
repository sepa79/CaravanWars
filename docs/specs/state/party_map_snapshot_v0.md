# Party Map Snapshot v0

## Purpose

`Party Map Snapshot v0` is the actor-filtered debug map boundary for one
observer party. Authoritative continuous region data remains physical truth,
but the snapshot contains only facts in that party's WorldMemory-derived
Navigation Knowledge Graph.

## Owner / consumers

- Owner: `packages/world-sim`.
- Consumer: the development Party Map in `apps/truth-map`.
- Non-consumers: simulation mutation, route validation, and durable
  WorldMemory belief storage.

## V0 filtering

For the requested `observerPartyId`, the snapshot includes:

- only that party's own physical snapshot;
- nodes and edges present in its private navigation projection, plus physical
  current or active road-travel endpoints;
- only route waypoints and landmark marks observed through the authoritative
  observation layer;
- uncertain circles and landmark relations with confidence, freshness and
  provenance entry ID, rendered as explicitly approximate marks;
- no authoritative terrain-area geometry: an observation may remember a terrain
  area id without revealing its authoritative full shape.

Hidden truth coordinates are never serialized merely because an object exists.
An exact coordinate appears only after the observer owns sufficiently precise
knowledge. This remains a development layout adapter, not a separate save.

An unknown observer party fails explicitly. It must never fall back to a truth
snapshot or an empty anonymous view.

## Security invariant

Filtering happens in `packages/world-sim` before serialization. A browser must
not receive the full graph and hide unknown facts locally.

## Compatibility notes

This snapshot is a projection, not durable belief state. WorldMemory is the
durable owner; TRUTH/DEBUG is a separate explicitly labelled endpoint and must
never be a fallback for Party Map.
