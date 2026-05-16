# Managed World Parties v0

## Purpose

`Managed World Parties v0` defines physical party entities in the authoritative simulation. A party is a real world entity such as a caravan, bandit band, patrol, retinue, or merchant company.

Each significant party has a `manager_actor_id`. The manager is the NPC or player-character role responsible for decisions. The party itself is not an anonymous AI blob.

## Layers

Physical simulation state:

- party exists,
- party has composition,
- party has physical cargo,
- party has a current node or active travel state,
- party has a manager actor id,
- party can receive the same commands as every other party.

Runtime visibility:

- client snapshots expose only physically visible parties,
- v0 visibility means another idle party at the same graph node,
- distant parties are not included in the client snapshot.

WorldMemory:

- stores who heard, saw, inferred, or remembers something about a party,
- does not make the party exist,
- does not replace physical party state.

## Party shape

`PartyState.to_dictionary()` includes:

```json
{
  "party_id": "merchant_party_01",
  "party_type": "merchant_caravan",
  "manager_actor_id": "merchant_miroslaw",
  "current_node_id": "opole",
  "travel_state": "idle"
}
```

The full party shape also includes composition, knowledge, active travel state, active travel intent/path fields, and party order state.

The full party shape also includes `cargo`, a dictionary of carried goods keyed by `goods_id`. Capacity is derived from composition through `Party Cargo v0`.

Orders are assigned by the party's `manager_actor_id` through `AssignPartyOrderCommand`; manager logic must not mutate party state directly.

## Initial parties

New game currently creates:

- `player_party`, managed by `player_caravan_leader`,
- `bandit_party_01`, managed by `bandit_chief_boruta`,
- `merchant_party_01`, managed by `merchant_miroslaw`.

These are seed simulation actors for tests and early slices, not final content.

## Client snapshot

`SimulationServer.get_client_snapshot(party_id)` includes:

```json
{
  "visible_parties": [
    {
      "party_id": "merchant_party_01",
      "party_type": "merchant_caravan",
      "manager_actor_id": "merchant_miroslaw",
      "current_node_id": "opole",
      "travel_state": "idle"
    }
  ]
}
```

The snapshot must not include all world parties. Full world state remains available only through server/debug snapshots.

## Commands

All parties use the same command interface. A bandit band or merchant caravan moves through the same `MovePartyCommand` / travel intent model as the player party.

Manager actors direct parties through commands such as `AssignPartyOrderCommand`. Deterministic manager code or future LLM-assisted decisions should produce commands, not direct state edits.

## Test coverage

Covered by `game/tests/ManagedWorldPartiesTest.gd`:

- new game contains multiple managed parties,
- distant parties are hidden from client snapshot,
- same-node parties are visible,
- non-player parties use the same movement command as the player.
