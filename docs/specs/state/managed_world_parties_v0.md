# Managed World Parties v0

## Purpose

`Managed World Parties v0` defines physical party entities in the authoritative simulation. A party is a real world entity such as a caravan, bandit band, patrol, retinue, or merchant company.

Each significant party has a `manager_actor_id`. The manager is the NPC or player-character role responsible for direct execution decisions. The party itself is not an anonymous AI blob.

Some parties also have `authorized_issuer_actor_ids`. These are superior or sponsoring actors that may issue high-level orders through the same command interface without becoming the party's direct manager.

## Layers

Physical simulation state:

- party exists,
- party has composition,
- party has physical cargo,
- party has a current node or active travel state,
- party has a manager actor id,
- party may have authorized issuer actor ids,
- party may have an active timed task,
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
  "authorized_issuer_actor_ids": [],
  "current_node_id": "opole",
  "travel_state": "idle"
}
```

The full party shape also includes composition, knowledge, active travel state, active travel intent/path fields, and party order state.
Current travel states are `idle`, `traveling`, and `interrupted`. Interrupted travel preserves origin, destination, distance, progress, and route plan, but the party is not considered physically present at the last graph node for local actions.
It also includes party task state for current party-lock actions and actor task state for individual actor actions.

`PartyTaskState` is a v0 party-lock approximation. `ActorTaskState` is now present as durable state so future Darklands-like actions can use one task per actor, with party-level tasks only when the whole group is committed or cannot act without the executor.

The full party shape also includes `cargo`, a dictionary of carried goods keyed by `goods_id`. Capacity is derived from composition through `Party Cargo v0`.

Orders are assigned through `AssignPartyOrderCommand` by the party's `manager_actor_id` or an actor listed in `authorized_issuer_actor_ids`; manager logic must not mutate party state directly.

## Initial parties

New game currently creates:

- `player_party`, managed by `player_caravan_leader`,
- `bandit_party_01`, managed by `bandit_chief_boruta`,
- `merchant_party_01`, managed by `merchant_miroslaw`.
- `wroclaw_supply_party_01`, managed by `quartermaster_wroclaw`, with `mayor_wroclaw` authorized to issue supply intent.

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

Manager actors and authorized issuer actors direct parties through commands such as `AssignPartyOrderCommand`. Deterministic manager code or future LLM-assisted decisions should produce commands, not direct state edits.

The city supply party model keeps hierarchy explicit:

- the mayor is the city brain and can issue high-level supply intent,
- the quartermaster or supply chief manages the physical supply party,
- both actors should use WorldMemory for what they know,
- observation and memory transfer must pass through WorldSim/WorldMemory rather than direct global state reads.

Long-term authority should be modeled as a generic chain of actors, not as one fixed city org chart. The number of layers depends on settlement scale and local institution:

- in a small village, the headman may also be quartermaster, negotiator, and caravan leader,
- in a larger village, the headman may have a dedicated supply helper,
- in a city such as Wroclaw, authority can have several levels: mayor, quartermaster, guard commander, party leaders, clerks, messengers, and contracted outsiders,
- above cities, rulers can command several mayors or offices through their own chain.

Most actors should be able to have one direct superior, with exceptions handled explicitly by role/office rather than hidden fallback.

Authority does not imply instant communication. A superior can only issue direct orders when communication is physically plausible. In v0, mayor-issued `procure_goods` requires the supply party at the target city node; future remote orders need messenger/courier delivery or another explicit communication path.

## Test coverage

Covered by `game/tests/ManagedWorldPartiesTest.gd`:

- new game contains multiple managed parties,
- Wroclaw supply party has a direct quartermaster manager and mayor authorized issuer,
- distant parties are hidden from client snapshot,
- same-node parties are visible,
- non-player parties use the same movement command as the player.
