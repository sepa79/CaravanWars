# Actor Task State v0

## Purpose

`Actor Task State v0` is the target contract for Darklands-like city actions that can be done by individual people inside a party or institution.

The current implementation only has `PartyTaskState`. This document defines the next ownership model so future tasks do not overgrow the party-lock approximation.

## Owner / consumers

- Owner: authoritative simulation.
- Consumers: player party companions, city officials, quartermasters, merchants, future UI/voice intent layer, WorldMemory integration.

## Core rule

One actor can run one active task at a time.

A party can run several actor tasks in parallel when it has several available actors. A party-level task locks the whole group only when the task requires collective commitment.

## Shape

Future actor task state should include:

```json
{
  "actor_id": "player_companion_01",
  "task_type": "ask_local_information",
  "status": "active",
  "party_id": "player_party",
  "location_id": "wroclaw_city",
  "query_type": "goods_source",
  "goods_id": "food",
  "requires_party_lock": false,
  "remaining_days": 0.25,
  "total_days": 0.25,
  "started_day": 3.0,
  "issuer_actor_id": "player_caravan_leader"
}
```

## Party-level vs actor-level

Actor-level examples:

- asking city offices for information,
- visiting market stalls,
- arranging lodging,
- hiring workers or guards,
- carrying a message inside the same settlement,
- negotiating a small purchase.

Party-level examples:

- travel,
- combat,
- camp movement,
- major loading/unloading,
- wagon repair that immobilizes the group,
- collective rest.

## Busy rules

- An actor with an active actor task cannot start another actor task.
- A party with an active party-lock task cannot start travel or another party-lock task.
- A party-level emergency may interrupt actor tasks only through an explicit interruption model.
- Actor tasks should record whether they can be resumed after interruption.

## Memory model

Actor tasks can emit WorldMemory events for:

- the actor,
- the actor's party,
- the issuing superior,
- the location or institution involved.

The event metadata is the durable source of truth. Text is presentation/debug output.

## Current implementation note

`ActorTaskState` now exists as durable save/load state on `PartyState.actor_tasks`.

The current `AskLocalInformationCommand` still uses `PartyTaskState`; that remains acceptable for supply-party local inquiry because the party waits on its required executor. The next implementation step is to move player-facing and city-internal tasks to `ActorTaskState` before city UX grows.
