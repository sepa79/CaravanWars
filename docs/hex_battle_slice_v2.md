# Hex Battle Slice v2

Hex Battle Slice v2 is a server-authoritative tactical event isolated from
regional travel. Singleplayer sends commands through the same battle boundary
that a remote client would use. The canonical ford-defense fixture places
Aulus and four autonomous retainers against five autonomous raiders.

## Command and selection boundary

The command boundary has two disjoint domain concepts. An
`IndividualBattleCommand` targets exactly one player-controlled actor and is
either Move or Attack. A `FormationCommand` targets a commanded BattleGroup and
uses the formation-order vocabulary below. Neither command shape can be
interpreted as the other.

Selecting Aulus labels the mode `INDIVIDUAL`, exposes only personal Move and
Attack, and draws only that actor's server-adjudicated legal targets. It never
shows a banner, slot, formation footprint, or formation order. Selecting
Retainers (and future sub-units) labels the mode `FORMATION`, exposes only
formation orders, and draws formation information. LMB selects a target and an
explicit confirm/cancel step is required before either command is submitted.

Enemy health, morale, orders, cohesion, assignments, and hidden actors remain
truth/debug data.

## Groups, stable slots, and preview

A group owns a stable id, commander, ordered member ids, banner/rally anchor,
formation, axial facing, cohesion, qualitative morale, current order, and
member-slot assignments. The player may command a group without becoming an
AI-controlled formation member, preserving independent personal action.

Loose, line, and close shield line slots are deterministic functions of anchor,
facing, formation, and the group's authored member-id order. A member keeps the
same slot index for the life of the formation; destination proximity never
reassigns identities.

Formation hover preview exposes the complete destination ghost footprint,
every member-to-slot mapping, and every anchor step in the movement corridor.
Validity belongs to the whole placement:

- green: all members can occupy their translated slots;
- amber: the complete placement is possible on difficult terrain;
- red: at least one member slot is unavailable.

Red placement cannot be confirmed. Amber execution emits an explicit
`formation_degraded` event. A dynamically red step stops with
`formation_blocked` and an `impossible` order outcome instead of inventing a
fallback or scattering members.

## Formation orders and audible delivery

The vocabulary is Follow me, Rally, Advance, Hold position, Change facing,
Close formation, Loose formation, Attack target group, Ordered withdrawal, and
Act at discretion. Targeted orders require prepare, hover preview, click target,
and explicit confirm/cancel.

The lifecycle is recorded for diagnostics, but direct audible voice delivery is
resolved within one battle tick:

    issued -> propagating -> received -> interpreted -> executing

The group can begin physical execution in the same tick in which the order is
heard. During propagation at least one living member must be within the
issuer's physical voice range; otherwise the order becomes `unheard`. Broken
groups may `refuse`. Other terminal outcomes are `impossible` and `completed`.

## Coherent simultaneous movement

Formation Advance translates the banner one hex per battle tick while
preserving formation type, facing, relative geometry, cohesion, and stable
member identity. All living actors choose from the tick-start state. Resolution
selects one claimant per target, permits orderly following into vacated cells,
rejects overlaps, duplicate claims, swaps, and cycles, and applies accepted
positions atomically. No fallback move is silently invented after a lost
reservation. Corpses and disabled actors remain blocking occupants.

Unordered allies cohere/hold and react only to adjacent danger. Ordered allies
seek their stable slots. Raiders use the same group model with advance doctrine
rather than independent homing.

## Exact regression fixture

In a fresh battle, Retainers Advance translates the banner from `(-2,0)` to
`(-1,0)`. Wulf, Runa, Oswin, and Bero retain ids `retainer_1`…`retainer_4` and
translate respectively to `(-1,-1)`, `(-1,0)`, `(-1,1)`, and `(-1,2)` in the
first audible/executing tick. The hover preview proves the same footprint and
mapping before click. A separate Aulus move regression proves the complete
Retainers formation state is unchanged.

Visual regression references:

- [FORMATION hover preview](screenshots/hex-battle-formation-preview.png)
- [INDIVIDUAL legal-target preview](screenshots/hex-battle-individual-preview.png)

## Save and replay

Snapshot version 2 stores seed, tick, order sequence, map, actor physical state,
and group/order/formation state. Loading rebuilds deterministic assignments and
continues deterministically. It has no regional travel dependency.
